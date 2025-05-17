// lib/features/forecast/presentation/providers/forecast_provider.dart

import 'package:flutter/material.dart';
import 'package:rivr/core/error/failures.dart';
import 'package:rivr/core/formatters/flow_value_formatter.dart';
import 'package:rivr/core/models/flow_unit.dart';
import 'package:rivr/core/services/flow_units_service.dart';
import 'package:rivr/core/services/geocoding_service.dart';
import 'package:rivr/features/forecast/domain/entities/forecast.dart';
import 'package:rivr/features/forecast/domain/entities/forecast_types.dart';
import 'package:rivr/features/forecast/domain/entities/reach_location.dart';
import 'package:rivr/features/forecast/domain/entities/return_period.dart';
import 'package:rivr/features/forecast/domain/usecases/get_forecast.dart';
import 'package:rivr/features/forecast/domain/usecases/get_return_periods.dart';
import 'package:rivr/core/services/stream_name_service.dart';
import 'package:rivr/core/di/service_locator.dart';
import 'package:rivr/features/map/data/datasources/map_station_local_datasource.dart';
import 'package:rivr/common/data/local/database_helper.dart';

enum ForecastLoadingState { initial, loading, loaded, error }

class ForecastProvider extends ChangeNotifier {
  final GetForecast _getForecast;
  final GetShortRangeForecast _getShortRangeForecast;
  final GetMediumRangeForecast _getMediumRangeForecast;
  final GetLongRangeForecast _getLongRangeForecast;
  final GetAllForecasts _getAllForecasts;
  final GetLatestFlow _getLatestFlow;
  final GetReturnPeriods _getReturnPeriods;
  final StreamNameService _streamNameService;

  // Add map station data source for location data
  final MapStationLocalDataSource _mapStationDataSource;
  final DatabaseHelper _databaseHelper;

  // FlowUnitsService
  final FlowUnitsService _flowUnitsService;

  // FlowValueFormatter
  final FlowValueFormatter _flowFormatter;

  ForecastProvider({
    required GetForecast getForecast,
    required GetShortRangeForecast getShortRangeForecast,
    required GetMediumRangeForecast getMediumRangeForecast,
    required GetLongRangeForecast getLongRangeForecast,
    required GetAllForecasts getAllForecasts,
    required GetLatestFlow getLatestFlow,
    required GetReturnPeriods getReturnPeriods,
    StreamNameService? streamNameService,
    MapStationLocalDataSource? mapStationDataSource,
    DatabaseHelper? databaseHelper,
    required FlowUnitsService flowUnitsService, // Add this parameter
    required FlowValueFormatter flowFormatter, // Add this parameter
  }) : _getForecast = getForecast,
       _getShortRangeForecast = getShortRangeForecast,
       _getMediumRangeForecast = getMediumRangeForecast,
       _getLongRangeForecast = getLongRangeForecast,
       _getAllForecasts = getAllForecasts,
       _getLatestFlow = getLatestFlow,
       _getReturnPeriods = getReturnPeriods,
       _streamNameService = streamNameService ?? sl<StreamNameService>(),
       _mapStationDataSource =
           mapStationDataSource ?? sl<MapStationLocalDataSource>(),
       _databaseHelper = databaseHelper ?? DatabaseHelper(),
       _flowUnitsService = flowUnitsService,
       _flowFormatter = flowFormatter {
    // Listen for unit changes
    _flowUnitsService.addListener(_onUnitChanged);
  }

  // State variables
  final Map<String, ForecastLoadingState> _loadingStates = {};
  final Map<String, String> _errorMessages = {};
  final Map<String, Map<ForecastType, ForecastCollection>> _cachedForecasts =
      {};
  final Map<String, Forecast?> _latestFlows = {};
  final Map<String, ReturnPeriod?> _returnPeriods = {};
  final Map<String, DateTime> _lastFetchTimes = {};
  final Map<String, Map<DateTime, Map<String, double>>> _aggregatedDailyData =
      {};
  final Map<String, ReachLocation> _reachLocations = {};

  // Cache for station names to reduce service calls
  final Map<String, String> _stationNameCache = {};

  @override
  void dispose() {
    _flowUnitsService.removeListener(_onUnitChanged);
    super.dispose();
  }

  // Handler for when flow unit changes
  void _onUnitChanged() {
    // Just notify listeners so UI components can update
    // The actual conversion happens when the values are used
    notifyListeners();
  }

  // Get the current flow unit
  FlowUnit get currentFlowUnit => _flowUnitsService.preferredUnit;

  // Get the flow formatter for consistent formatting
  FlowValueFormatter get flowFormatter => _flowFormatter;

  // Mthod to format flow values
  String formatFlow(double flow, {FlowUnit? fromUnit}) {
    if (fromUnit != null && fromUnit != _flowUnitsService.preferredUnit) {
      // Convert before formatting
      final convertedFlow = _flowUnitsService.convertToPreferredUnit(
        flow,
        fromUnit,
      );
      return _flowFormatter.format(convertedFlow);
    }

    return _flowFormatter.format(flow);
  }

  // New helper method to convert flow values if needed
  double convertFlowIfNeeded(double flow, FlowUnit fromUnit) {
    if (fromUnit == _flowUnitsService.preferredUnit) {
      return flow; // No conversion needed
    }

    return _flowUnitsService.convertToPreferredUnit(flow, fromUnit);
  }

  // Get the unit string for display
  String get unitString => _flowUnitsService.unitLabel;

  // Get the short unit name
  String get unitShortName => _flowUnitsService.unitShortName;

  // Getters
  bool isLoading(String reachId) =>
      _loadingStates[reachId] == ForecastLoadingState.loading;

  bool isLoadingAny() =>
      _loadingStates.values.contains(ForecastLoadingState.loading);

  ForecastLoadingState getLoadingState(String reachId) =>
      _loadingStates[reachId] ?? ForecastLoadingState.initial;

  String? getErrorFor(String reachId) => _errorMessages[reachId];

  DateTime? getLastFetchTime(String reachId) => _lastFetchTimes[reachId];

  bool needsRefresh(String reachId) {
    if (!_lastFetchTimes.containsKey(reachId)) return true;

    final lastFetch = _lastFetchTimes[reachId]!;
    final now = DateTime.now();
    final difference = now.difference(lastFetch);

    // Consider data stale after 2 hours
    return difference.inHours >= 2;
  }

  // Get a specific forecast type for a reach
  ForecastCollection? getForecastCollection(
    String reachId,
    ForecastType forecastType,
  ) {
    if (_cachedForecasts.containsKey(reachId) &&
        _cachedForecasts[reachId]!.containsKey(forecastType)) {
      return _cachedForecasts[reachId]![forecastType];
    }
    return null;
  }

  // Check if we have forecasts for a reach
  bool hasForecastsFor(String reachId) {
    return _cachedForecasts.containsKey(reachId) &&
        _cachedForecasts[reachId]!.isNotEmpty;
  }

  // Get the latest flow for a reach
  Forecast? getLatestFlowFor(String reachId) {
    return _latestFlows[reachId];
  }

  // Get return period for a reach
  ReturnPeriod? getReturnPeriodFor(String reachId) {
    return _returnPeriods[reachId];
  }

  // Get aggregated daily data for calendar view
  Map<DateTime, Map<String, double>>? getDailyDataFor(String reachId) {
    return _aggregatedDailyData[reachId];
  }

  // Get location for a reach/river
  Future<ReachLocation?> getReachLocationFor(String reachId) async {
    // Get existing location data (coordinates)
    ReachLocation? location = _reachLocations[reachId];

    // If no location data available, return null
    if (location == null) return null;

    // If we have coordinates but no city/state, attempt geocoding
    if (location.city == null || location.state == null) {
      try {
        print("ForecastProvider: Geocoding location for reach $reachId");
        final geocodingService = sl<GeocodingService>();
        final locationInfo = await geocodingService.getLocationInfo(
          location.lat,
          location.lon,
        );

        if (locationInfo != null) {
          print(
            "ForecastProvider: Geocoding successful for reach $reachId: ${locationInfo.formattedLocation}",
          );

          // Create updated location with city/state
          location = ReachLocation(
            lat: location.lat,
            lon: location.lon,
            elevation: location.elevation,
            city: locationInfo.city,
            state: locationInfo.state,
          );

          // Update stored location
          _reachLocations[reachId] = location;
          notifyListeners();
        } else {
          print("ForecastProvider: Geocoding returned null for reach $reachId");
        }
      } catch (e) {
        print(
          'ForecastProvider: Error geocoding location for reach $reachId: $e',
        );
      }
    }

    return location;
  }

  // Set location for a reach/river
  void setReachLocation(
    String reachId,
    double lat,
    double lon, {
    double? elevation,
  }) {
    _reachLocations[reachId] = ReachLocation(
      lat: lat,
      lon: lon,
      elevation: elevation,
    );
    notifyListeners();
  }

  // Get the station name from StreamNameService
  Future<String> getStationName(String reachId) async {
    // Check cache first
    if (_stationNameCache.containsKey(reachId)) {
      return _stationNameCache[reachId]!;
    }

    try {
      // Get name from StreamNameService
      final name = await _streamNameService.getDisplayName(reachId);
      // Cache the result
      _stationNameCache[reachId] = name;
      return name;
    } catch (e) {
      print("Error getting station name for $reachId: $e");
      // Return a fallback name if service fails
      return "Stream $reachId";
    }
  }

  // Get the station name synchronously (from cache or fallback)
  String getStationNameSync(String reachId) {
    if (_stationNameCache.containsKey(reachId)) {
      return _stationNameCache[reachId]!;
    }

    // Start an async fetch for next time but return a fallback for now
    getStationName(reachId).then((name) {
      // This will update the cache for future calls
      if (name != "Stream $reachId") {
        notifyListeners(); // Only notify if we got a real name
      }
    });

    return "Stream $reachId";
  }

  // Update a station name - useful if the user changes it elsewhere
  Future<void> updateStationName(String reachId, String newName) async {
    if (newName.isEmpty) return;

    try {
      // Update in StreamNameService
      await _streamNameService.updateDisplayName(reachId, newName);

      // Update our cache
      _stationNameCache[reachId] = newName;
      notifyListeners();
    } catch (e) {
      print("Error updating station name for $reachId: $e");
    }
  }

  // Load all forecast types for a reach
  Future<bool> loadAllForecasts(
    String reachId, {
    bool forceRefresh = false,
  }) async {
    if (isLoading(reachId) && !forceRefresh) return false;

    _loadingStates[reachId] = ForecastLoadingState.loading;
    _errorMessages.remove(reachId);
    notifyListeners();

    final result = await _getAllForecasts(reachId, forceRefresh: forceRefresh);

    return result.fold(
      (failure) {
        _errorMessages[reachId] = _mapFailureToMessage(failure);
        _loadingStates[reachId] = ForecastLoadingState.error;
        notifyListeners();
        return false;
      },
      (forecasts) {
        if (!_cachedForecasts.containsKey(reachId)) {
          _cachedForecasts[reachId] = {};
        }

        _cachedForecasts[reachId]!.addAll(forecasts);
        _lastFetchTimes[reachId] = DateTime.now();
        _loadingStates[reachId] = ForecastLoadingState.loaded;
        notifyListeners();

        // Also load the latest flow and return periods
        _loadLatestFlow(reachId);
        _loadReturnPeriod(reachId);
        _processDailyData(reachId);

        // Try to extract location information - now uses real data!
        _tryExtractLocationInfo(reachId);

        // Prefetch the station name if we don't have it
        if (!_stationNameCache.containsKey(reachId)) {
          getStationName(reachId);
        }

        return true;
      },
    );
  }

  // UPDATED: Extract real location info from database instead of dummy data
  Future<void> _tryExtractLocationInfo(String reachId) async {
    // Skip if we already have location data for this reach
    if (_reachLocations.containsKey(reachId)) {
      return;
    }

    try {
      print("Attempting to find location data for reach ID: $reachId");

      // Method 1: Try direct lookup by station ID
      // This approach assumes the reachId might match a station ID in the database
      bool found = await _tryDirectLookup(reachId);
      if (found) return;

      // Method 2: Try to find stations with similar IDs or names
      found = await _trySimilarIdLookup(reachId);
      if (found) return;

      // Method 3: If nothing found, check if we have any stations and use nearest ones
      await _tryNearestStationsLookup(reachId);
    } catch (e) {
      print('Error extracting location data for reach $reachId: $e');
      // Fall back to a default location but don't set it in _reachLocations
      // so we can try again later if more data becomes available
    }
  }

  // Try to find station directly by ID
  Future<bool> _tryDirectLookup(String reachId) async {
    try {
      // Try to query the database directly first
      final db = await _databaseHelper.database;

      // First, check if Geolocations table exists
      final tableExists = await _databaseHelper.tableExists('Geolocations');
      if (!tableExists) {
        print("Geolocations table not found in database!");
        return false;
      }

      // Query for stations with matching ID
      // Try different formats of the ID - as is, as integer, with/without leading zeros
      final int? reachIdInt = int.tryParse(reachId);
      final List<String> idVariations = [
        reachId,
        if (reachIdInt != null) reachIdInt.toString(),
      ];

      for (final idVariation in idVariations) {
        final List<Map<String, dynamic>> results = await db.query(
          'Geolocations',
          where: 'stationId = ?',
          whereArgs: [idVariation],
          limit: 1,
        );

        if (results.isNotEmpty) {
          final data = results.first;
          final double? lat = _extractDouble(data['lat']);
          final double? lon = _extractDouble(data['lon']);

          if (lat != null && lon != null) {
            print("Found exact station match for $reachId: lat=$lat, lon=$lon");

            // Extract elevation if available
            double? elevation = _extractDouble(data['elevation']);

            // Store the location
            _reachLocations[reachId] = ReachLocation(
              lat: lat,
              lon: lon,
              elevation: elevation,
            );

            return true;
          }
        }
      }

      print("No exact station match found for $reachId");
      return false;
    } catch (e) {
      print("Error during direct station lookup: $e");
      return false;
    }
  }

  // Try to find stations with similar IDs
  Future<bool> _trySimilarIdLookup(String reachId) async {
    try {
      final db = await _databaseHelper.database;

      // Try to find stations with IDs that contain our reachId
      final List<Map<String, dynamic>> results = await db.query(
        'Geolocations',
        where: 'stationId LIKE ?',
        whereArgs: ['%$reachId%'],
        limit: 5,
      );

      if (results.isNotEmpty) {
        final data = results.first; // Take the first match
        final double? lat = _extractDouble(data['lat']);
        final double? lon = _extractDouble(data['lon']);

        if (lat != null && lon != null) {
          print("Found similar station ID for $reachId: lat=$lat, lon=$lon");

          // Extract elevation if available
          double? elevation = _extractDouble(data['elevation']);

          // Store the location
          _reachLocations[reachId] = ReachLocation(
            lat: lat,
            lon: lon,
            elevation: elevation,
          );

          return true;
        }
      }

      // Also try to search by name if we have a stream name
      final streamName = _stationNameCache[reachId];
      if (streamName != null && streamName != "Stream $reachId") {
        // Extract keywords from the name
        final keywords =
            streamName
                .split(' ')
                .where((word) => word.length > 3) // Only use meaningful words
                .toList();

        for (final keyword in keywords) {
          final List<Map<String, dynamic>> nameResults = await db.query(
            'Geolocations',
            where: 'name LIKE ?',
            whereArgs: ['%$keyword%'],
            limit: 5,
          );

          if (nameResults.isNotEmpty) {
            final data = nameResults.first;
            final double? lat = _extractDouble(data['lat']);
            final double? lon = _extractDouble(data['lon']);

            if (lat != null && lon != null) {
              print(
                "Found station by name keyword '$keyword' for $reachId: lat=$lat, lon=$lon",
              );

              // Extract elevation if available
              double? elevation = _extractDouble(data['elevation']);

              // Store the location
              _reachLocations[reachId] = ReachLocation(
                lat: lat,
                lon: lon,
                elevation: elevation,
              );

              return true;
            }
          }
        }
      }

      return false;
    } catch (e) {
      print("Error during similar station lookup: $e");
      return false;
    }
  }

  // Try to use nearest stations as fallback
  Future<void> _tryNearestStationsLookup(String reachId) async {
    try {
      // Get sample stations
      final stations = await _mapStationDataSource.getSampleStations(limit: 10);

      if (stations.isEmpty) {
        print("No stations available in database for location lookup");
        return;
      }

      // Use the first station as a reasonable location (better than nothing)
      final firstStation = stations.first;
      print(
        "Using sample station for $reachId: lat=${firstStation.lat}, lon=${firstStation.lon}",
      );

      _reachLocations[reachId] = ReachLocation(
        lat: firstStation.lat,
        lon: firstStation.lon,
        elevation: firstStation.elevation,
      );
    } catch (e) {
      print("Error getting nearest stations: $e");
    }
  }

  // Helper method to safely extract double values from database results
  double? _extractDouble(dynamic value) {
    if (value == null) return null;

    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);

    return null;
  }

  // Load a specific forecast type
  Future<ForecastCollection?> loadForecast(
    String reachId,
    ForecastType forecastType, {
    bool forceRefresh = false,
  }) async {
    // Return cached forecast if available and not forced to refresh
    if (!forceRefresh &&
        _cachedForecasts.containsKey(reachId) &&
        _cachedForecasts[reachId]!.containsKey(forecastType) &&
        !needsRefresh(reachId)) {
      return _cachedForecasts[reachId]![forecastType];
    }

    _loadingStates[reachId] = ForecastLoadingState.loading;
    _errorMessages.remove(reachId);
    notifyListeners();

    final result = await _getForecast(
      reachId,
      forecastType,
      forceRefresh: forceRefresh,
    );

    return result.fold(
      (failure) {
        _errorMessages[reachId] = _mapFailureToMessage(failure);
        _loadingStates[reachId] = ForecastLoadingState.error;
        notifyListeners();
        return null;
      },
      (forecastCollection) {
        if (!_cachedForecasts.containsKey(reachId)) {
          _cachedForecasts[reachId] = {};
        }

        _cachedForecasts[reachId]![forecastType] = forecastCollection;
        _lastFetchTimes[reachId] = DateTime.now();
        _loadingStates[reachId] = ForecastLoadingState.loaded;
        _processDailyData(reachId);

        // Try to extract location info if we don't have it yet
        if (!_reachLocations.containsKey(reachId)) {
          _tryExtractLocationInfo(reachId);
        }

        // Prefetch the station name if we don't have it
        if (!_stationNameCache.containsKey(reachId)) {
          getStationName(reachId);
        }

        notifyListeners();
        return forecastCollection;
      },
    );
  }

  // Load short range forecast
  Future<ForecastCollection?> loadShortRangeForecast(
    String reachId, {
    bool forceRefresh = false,
  }) async {
    if (isLoading(reachId) && !forceRefresh) return null;

    _loadingStates[reachId] = ForecastLoadingState.loading;
    _errorMessages.remove(reachId);
    notifyListeners();

    final result = await _getShortRangeForecast(
      reachId,
      forceRefresh: forceRefresh,
    );

    return result.fold(
      (failure) {
        _errorMessages[reachId] = _mapFailureToMessage(failure);
        _loadingStates[reachId] = ForecastLoadingState.error;
        notifyListeners();
        return null;
      },
      (forecast) {
        if (!_cachedForecasts.containsKey(reachId)) {
          _cachedForecasts[reachId] = {};
        }

        _cachedForecasts[reachId]![ForecastType.shortRange] = forecast;
        _lastFetchTimes[reachId] = DateTime.now();
        _loadingStates[reachId] = ForecastLoadingState.loaded;
        _processDailyData(reachId);

        // Try to extract location info if we don't have it yet
        if (!_reachLocations.containsKey(reachId)) {
          _tryExtractLocationInfo(reachId);
        }

        notifyListeners();
        return forecast;
      },
    );
  }

  // Load medium range forecast
  Future<ForecastCollection?> loadMediumRangeForecast(
    String reachId, {
    bool forceRefresh = false,
  }) async {
    if (isLoading(reachId) && !forceRefresh) return null;

    _loadingStates[reachId] = ForecastLoadingState.loading;
    _errorMessages.remove(reachId);
    notifyListeners();

    final result = await _getMediumRangeForecast(
      reachId,
      forceRefresh: forceRefresh,
    );

    return result.fold(
      (failure) {
        _errorMessages[reachId] = _mapFailureToMessage(failure);
        _loadingStates[reachId] = ForecastLoadingState.error;
        notifyListeners();
        return null;
      },
      (forecast) {
        if (!_cachedForecasts.containsKey(reachId)) {
          _cachedForecasts[reachId] = {};
        }

        _cachedForecasts[reachId]![ForecastType.mediumRange] = forecast;
        _lastFetchTimes[reachId] = DateTime.now();
        _loadingStates[reachId] = ForecastLoadingState.loaded;
        _processDailyData(reachId);

        // Try to extract location info if we don't have it yet
        if (!_reachLocations.containsKey(reachId)) {
          _tryExtractLocationInfo(reachId);
        }

        notifyListeners();
        return forecast;
      },
    );
  }

  // Load long range forecast
  Future<ForecastCollection?> loadLongRangeForecast(
    String reachId, {
    bool forceRefresh = false,
  }) async {
    if (isLoading(reachId) && !forceRefresh) return null;

    _loadingStates[reachId] = ForecastLoadingState.loading;
    _errorMessages.remove(reachId);
    notifyListeners();

    final result = await _getLongRangeForecast(
      reachId,
      forceRefresh: forceRefresh,
    );

    return result.fold(
      (failure) {
        _errorMessages[reachId] = _mapFailureToMessage(failure);
        _loadingStates[reachId] = ForecastLoadingState.error;
        notifyListeners();
        return null;
      },
      (forecast) {
        if (!_cachedForecasts.containsKey(reachId)) {
          _cachedForecasts[reachId] = {};
        }

        _cachedForecasts[reachId]![ForecastType.longRange] = forecast;
        _lastFetchTimes[reachId] = DateTime.now();
        _loadingStates[reachId] = ForecastLoadingState.loaded;
        _processDailyData(reachId);

        // Try to extract location info if we don't have it yet
        if (!_reachLocations.containsKey(reachId)) {
          _tryExtractLocationInfo(reachId);
        }

        notifyListeners();
        return forecast;
      },
    );
  }

  // Load latest flow
  Future<void> _loadLatestFlow(String reachId) async {
    final result = await _getLatestFlow(reachId);

    result.fold(
      (failure) {
        // Just log error, don't update UI state
        print('Error loading latest flow: ${failure.message}');
      },
      (latestFlow) {
        _latestFlows[reachId] = latestFlow;
        notifyListeners();
      },
    );
  }

  // Load return period data
  Future<void> _loadReturnPeriod(String reachId) async {
    final result = await _getReturnPeriods(reachId);

    result.fold(
      (failure) {
        // Just log error, don't update UI state
        print('Error loading return period: ${failure.message}');
      },
      (returnPeriod) {
        _returnPeriods[reachId] = returnPeriod;
        notifyListeners();
      },
    );
  }

  // Process forecasts into daily data for calendar view - with unit handling
  void _processDailyData(String reachId) {
    if (!_cachedForecasts.containsKey(reachId)) return;

    final Map<DateTime, List<double>> dailyFlowValues = {};

    // Process all forecast types
    for (var entry in _cachedForecasts[reachId]!.entries) {
      final forecastCollection = entry.value;

      for (var forecast in forecastCollection.forecasts) {
        // Normalize to start of day
        final date = DateTime(
          forecast.validDateTime.year,
          forecast.validDateTime.month,
          forecast.validDateTime.day,
        );

        // Add to flow values for this day
        if (!dailyFlowValues.containsKey(date)) {
          dailyFlowValues[date] = [];
        }

        // Assume forecast flow values are in CFS (API standard)
        // and convert if needed
        double flowValue = forecast.flow;
        if (_flowUnitsService.preferredUnit == FlowUnit.cms) {
          flowValue = _flowUnitsService.cfsToCms(flowValue);
        }

        dailyFlowValues[date]!.add(flowValue);
      }
    }

    // Calculate stats for each day
    final Map<DateTime, Map<String, double>> dailyStats = {};

    dailyFlowValues.forEach((date, flowValues) {
      if (flowValues.isEmpty) return;

      // Sort values for percentile calculations
      flowValues.sort();

      // Calculate statistics
      final sum = flowValues.reduce((a, b) => a + b);
      final mean = sum / flowValues.length;
      final min = flowValues.first;
      final max = flowValues.last;

      // Calculate 25th and 75th percentiles
      final p25Index = ((flowValues.length - 1) * 0.25).round();
      final p75Index = ((flowValues.length - 1) * 0.75).round();
      final p25 = flowValues[p25Index];
      final p75 = flowValues[p75Index];

      dailyStats[date] = {
        'mean': mean,
        'min': min,
        'max': max,
        'p25': p25,
        'p75': p75,
      };
    });

    _aggregatedDailyData[reachId] = dailyStats;
  }

  // Refresh all data for a reach
  Future<bool> refreshAllData(String reachId) async {
    // Also refresh the station name
    if (_stationNameCache.containsKey(reachId)) {
      _stationNameCache.remove(reachId);
      getStationName(reachId);
    }

    // Clear location data so we try to fetch it again
    _reachLocations.remove(reachId);

    return loadAllForecasts(reachId, forceRefresh: true);
  }

  // Clear cached data for a specific reach
  void clearCacheFor(String reachId) {
    _cachedForecasts.remove(reachId);
    _latestFlows.remove(reachId);
    _errorMessages.remove(reachId);
    _loadingStates.remove(reachId);
    _lastFetchTimes.remove(reachId);
    _returnPeriods.remove(reachId);
    _aggregatedDailyData.remove(reachId);
    _stationNameCache.remove(reachId);
    _reachLocations.remove(reachId);
    notifyListeners();
  }

  // Clear all cached data
  void clearAllCache() {
    _cachedForecasts.clear();
    _latestFlows.clear();
    _errorMessages.clear();
    _loadingStates.clear();
    _lastFetchTimes.clear();
    _returnPeriods.clear();
    _aggregatedDailyData.clear();
    _stationNameCache.clear();
    _reachLocations.clear();
    notifyListeners();
  }

  // Map failure to user-friendly error message
  String _mapFailureToMessage(Failure failure) {
    if (failure is ServerFailure) {
      return failure.message;
    } else if (failure is NetworkFailure) {
      return 'Please check your internet connection';
    } else if (failure is CacheFailure) {
      return 'Data not available offline';
    }
    return 'An unexpected error occurred';
  }

  List<Forecast> getFilteredForecastsForDisplay(List<Forecast> forecasts) {
    final now = DateTime.now();

    // Filter forecasts to only include those in the future (based on local time)
    return forecasts.where((forecast) {
      final localTime = forecast.validDateTime.toLocal();
      return localTime.isAfter(now);
    }).toList();
  }
}
