// lib/features/forecast/presentation/providers/forecast_provider.dart

import 'package:flutter/material.dart';
import 'package:rivr/core/error/failures.dart';
import 'package:rivr/features/forecast/domain/entities/forecast.dart';
import 'package:rivr/features/forecast/domain/entities/forecast_types.dart';
import 'package:rivr/features/forecast/domain/entities/return_period.dart';
import 'package:rivr/features/forecast/domain/usecases/get_forecast.dart';
import 'package:rivr/features/forecast/domain/usecases/get_return_periods.dart';
import 'package:rivr/core/services/stream_name_service.dart';
import 'package:rivr/core/di/service_locator.dart';

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

  ForecastProvider({
    required GetForecast getForecast,
    required GetShortRangeForecast getShortRangeForecast,
    required GetMediumRangeForecast getMediumRangeForecast,
    required GetLongRangeForecast getLongRangeForecast,
    required GetAllForecasts getAllForecasts,
    required GetLatestFlow getLatestFlow,
    required GetReturnPeriods getReturnPeriods,
    StreamNameService? streamNameService,
  }) : _getForecast = getForecast,
       _getShortRangeForecast = getShortRangeForecast,
       _getMediumRangeForecast = getMediumRangeForecast,
       _getLongRangeForecast = getLongRangeForecast,
       _getAllForecasts = getAllForecasts,
       _getLatestFlow = getLatestFlow,
       _getReturnPeriods = getReturnPeriods,
       _streamNameService = streamNameService ?? sl<StreamNameService>();

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

  // Cache for station names to reduce service calls
  final Map<String, String> _stationNameCache = {};

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

        // Prefetch the station name if we don't have it
        if (!_stationNameCache.containsKey(reachId)) {
          getStationName(reachId);
        }

        return true;
      },
    );
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

  // Process forecasts into daily data for calendar view
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

        dailyFlowValues[date]!.add(forecast.flow);
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
}
