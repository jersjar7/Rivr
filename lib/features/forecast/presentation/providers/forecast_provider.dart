// lib/features/forecast/presentation/providers/forecast_provider.dart

import 'package:flutter/material.dart';
import 'package:rivr/core/error/failures.dart';
import 'package:rivr/features/forecast/domain/entities/forecast.dart';
import 'package:rivr/features/forecast/domain/entities/forecast_types.dart';
import 'package:rivr/features/forecast/domain/usecases/get_forecast.dart';

class ForecastProvider extends ChangeNotifier {
  final GetForecast _getForecast;
  final GetAllForecasts _getAllForecasts;
  final GetLatestFlow _getLatestFlow;

  ForecastProvider({
    required GetForecast getForecast,
    required GetShortRangeForecast getShortRangeForecast,
    required GetMediumRangeForecast getMediumRangeForecast,
    required GetLongRangeForecast getLongRangeForecast,
    required GetAllForecasts getAllForecasts,
    required GetLatestFlow getLatestFlow,
  }) : _getForecast = getForecast,
       _getAllForecasts = getAllForecasts,
       _getLatestFlow = getLatestFlow;

  // State variables
  bool _isLoading = false;
  final Map<String, String> _errorMessages = {};
  final Map<String, Map<ForecastType, ForecastCollection>> _cachedForecasts =
      {};
  final Map<String, Forecast?> _latestFlows = {};

  // Getters
  bool get isLoading => _isLoading;
  String? getErrorFor(String reachId) => _errorMessages[reachId];
  bool hasErrorFor(String reachId) => _errorMessages.containsKey(reachId);

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

  // Load all forecast types for a reach
  Future<bool> loadAllForecasts(
    String reachId, {
    bool forceRefresh = false,
  }) async {
    _isLoading = true;
    _errorMessages.remove(reachId);
    notifyListeners();

    final result = await _getAllForecasts(reachId, forceRefresh: forceRefresh);

    return result.fold(
      (failure) {
        _errorMessages[reachId] = _mapFailureToMessage(failure);
        _isLoading = false;
        notifyListeners();
        return false;
      },
      (forecasts) {
        if (!_cachedForecasts.containsKey(reachId)) {
          _cachedForecasts[reachId] = {};
        }

        _cachedForecasts[reachId]!.addAll(forecasts);
        _isLoading = false;
        notifyListeners();

        // Also load the latest flow
        _loadLatestFlow(reachId);

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
        _cachedForecasts[reachId]!.containsKey(forecastType)) {
      return _cachedForecasts[reachId]![forecastType];
    }

    _isLoading = true;
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
        _isLoading = false;
        notifyListeners();
        return null;
      },
      (forecastCollection) {
        if (!_cachedForecasts.containsKey(reachId)) {
          _cachedForecasts[reachId] = {};
        }

        _cachedForecasts[reachId]![forecastType] = forecastCollection;
        _isLoading = false;
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
    return loadForecast(
      reachId,
      ForecastType.shortRange,
      forceRefresh: forceRefresh,
    );
  }

  // Load medium range forecast
  Future<ForecastCollection?> loadMediumRangeForecast(
    String reachId, {
    bool forceRefresh = false,
  }) async {
    return loadForecast(
      reachId,
      ForecastType.mediumRange,
      forceRefresh: forceRefresh,
    );
  }

  // Load long range forecast
  Future<ForecastCollection?> loadLongRangeForecast(
    String reachId, {
    bool forceRefresh = false,
  }) async {
    return loadForecast(
      reachId,
      ForecastType.longRange,
      forceRefresh: forceRefresh,
    );
  }

  // Load latest flow
  Future<void> _loadLatestFlow(String reachId) async {
    final result = await _getLatestFlow(reachId);

    result.fold(
      (failure) {
        // We just ignore failures for latest flow, as it's not critical
        print('Error loading latest flow: ${failure.message}');
      },
      (latestFlow) {
        _latestFlows[reachId] = latestFlow;
        notifyListeners();
      },
    );
  }

  // Refresh all data for a reach
  Future<bool> refreshAllData(String reachId) async {
    return loadAllForecasts(reachId, forceRefresh: true);
  }

  // Clear cached data for a specific reach
  void clearCacheFor(String reachId) {
    _cachedForecasts.remove(reachId);
    _latestFlows.remove(reachId);
    _errorMessages.remove(reachId);
    notifyListeners();
  }

  // Clear all cached data
  void clearAllCache() {
    _cachedForecasts.clear();
    _latestFlows.clear();
    _errorMessages.clear();
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
