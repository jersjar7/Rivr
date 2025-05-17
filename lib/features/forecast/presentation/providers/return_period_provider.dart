// lib/features/forecast/presentation/providers/return_period_provider.dart

import 'package:flutter/material.dart';
import 'package:rivr/core/error/failures.dart';
import 'package:rivr/core/formatters/flow_value_formatter.dart';
import 'package:rivr/core/models/flow_unit.dart';
import 'package:rivr/core/services/flow_units_service.dart';
import 'package:rivr/features/forecast/domain/entities/return_period.dart';
import 'package:rivr/features/forecast/domain/usecases/get_return_periods.dart';
import 'package:rivr/features/forecast/presentation/providers/forecast_provider.dart';
import 'package:rivr/features/forecast/utils/flow_thresholds.dart';

enum ReturnPeriodLoadingState { initial, loading, loaded, error }

class ReturnPeriodProvider extends ChangeNotifier {
  final GetReturnPeriods _getReturnPeriods;
  final GetFlowCategory _getFlowCategory;
  final CheckFlowExceedsThreshold _checkFlowExceedsThreshold;
  final ForecastProvider _forecastProvider;

  // FlowUnitsService
  final FlowUnitsService _flowUnitsService;

  // FlowValueFormatter
  final FlowValueFormatter _flowFormatter;

  ReturnPeriodProvider({
    required GetReturnPeriods getReturnPeriods,
    required GetFlowCategory getFlowCategory,
    required CheckFlowExceedsThreshold checkFlowExceedsThreshold,
    required ForecastProvider forecastProvider,
    required FlowUnitsService flowUnitsService, // Add this parameter
    required FlowValueFormatter flowFormatter, // Add this parameter
  }) : _getReturnPeriods = getReturnPeriods,
       _getFlowCategory = getFlowCategory,
       _checkFlowExceedsThreshold = checkFlowExceedsThreshold,
       _forecastProvider = forecastProvider,
       _flowUnitsService = flowUnitsService,
       _flowFormatter = flowFormatter {
    // Listen for unit changes and update data as needed
    _flowUnitsService.addListener(_onUnitChanged);
  }

  final Map<String, ReturnPeriod> _cachedReturnPeriods = {};
  final Map<String, String> _errorMessages = {};
  final Map<String, ReturnPeriodLoadingState> _loadingStates = {};
  final Map<String, DateTime> _lastFetchTimes = {};

  // Map of reachId -> flow thresholds for quick access
  final Map<String, Map<String, double>> _flowThresholds = {};

  @override
  void dispose() {
    _flowUnitsService.removeListener(_onUnitChanged);
    super.dispose();
  }

  // Handler for when the flow unit changes
  void _onUnitChanged() {
    // Refresh all cached return periods to reflect the new unit
    _refreshAllCachedReturnPeriods();

    // Notify listeners so UI components can update
    notifyListeners();
  }

  // Get the current flow unit
  FlowUnit get currentFlowUnit => _flowUnitsService.preferredUnit;

  // Get the flow formatter for consistent formatting
  FlowValueFormatter get flowFormatter => _flowFormatter;

  // Refresh all cached return periods when the unit changes
  void _refreshAllCachedReturnPeriods() {
    // For each cached return period, refresh it with the new unit
    for (final reachId in _cachedReturnPeriods.keys.toList()) {
      refreshReturnPeriod(reachId);
    }
  }

  // Getters
  bool isLoading(String reachId) =>
      _loadingStates[reachId] == ReturnPeriodLoadingState.loading;

  ReturnPeriodLoadingState getLoadingState(String reachId) =>
      _loadingStates[reachId] ?? ReturnPeriodLoadingState.initial;

  String? getErrorFor(String reachId) => _errorMessages[reachId];

  bool hasReturnPeriodFor(String reachId) =>
      _cachedReturnPeriods.containsKey(reachId);

  DateTime? getLastFetchTime(String reachId) => _lastFetchTimes[reachId];

  bool needsRefresh(String reachId) {
    if (!_lastFetchTimes.containsKey(reachId)) return true;

    final lastFetch = _lastFetchTimes[reachId]!;
    final now = DateTime.now();
    final difference = now.difference(lastFetch);

    // Consider return period data stale after 7 days
    return difference.inDays >= 7;
  }

  ReturnPeriod? getCachedReturnPeriod(String reachId) {
    return _cachedReturnPeriods[reachId];
  }

  // Get return period data for a reach
  Future<ReturnPeriod?> getReturnPeriod(
    String reachId, {
    bool forceRefresh = false,
  }) async {
    // Check if forecast provider already has the return period data
    final forecastReturnPeriod = _forecastProvider.getReturnPeriodFor(reachId);
    if (forecastReturnPeriod != null && !forceRefresh) {
      // Ensure it's in the current preferred unit
      final returnPeriodInCorrectUnit = _ensureCorrectUnit(
        forecastReturnPeriod,
      );
      // Update our cache from forecast provider
      _cachedReturnPeriods[reachId] = returnPeriodInCorrectUnit;
      _updateFlowThresholds(reachId, returnPeriodInCorrectUnit);
      return returnPeriodInCorrectUnit;
    }

    // Return cached data if available and not forced to refresh
    if (!forceRefresh &&
        _cachedReturnPeriods.containsKey(reachId) &&
        !needsRefresh(reachId)) {
      // Ensure it's in the current preferred unit
      final cachedReturnPeriod = _cachedReturnPeriods[reachId]!;
      if (cachedReturnPeriod.unit != _flowUnitsService.preferredUnit) {
        final convertedReturnPeriod = cachedReturnPeriod.convertTo(
          _flowUnitsService.preferredUnit,
          _flowUnitsService,
        );
        _cachedReturnPeriods[reachId] = convertedReturnPeriod;
        _updateFlowThresholds(reachId, convertedReturnPeriod);
        return convertedReturnPeriod;
      }
      return cachedReturnPeriod;
    }

    _loadingStates[reachId] = ReturnPeriodLoadingState.loading;
    _errorMessages.remove(reachId);
    notifyListeners();

    final result = await _getReturnPeriods(reachId, forceRefresh: forceRefresh);

    return result.fold(
      (failure) {
        _errorMessages[reachId] = _mapFailureToMessage(failure);
        _loadingStates[reachId] = ReturnPeriodLoadingState.error;
        notifyListeners();
        return null;
      },
      (returnPeriod) {
        // returnPeriod should already be in the preferred unit from the repository
        _cachedReturnPeriods[reachId] = returnPeriod;
        _lastFetchTimes[reachId] = DateTime.now();
        _loadingStates[reachId] = ReturnPeriodLoadingState.loaded;
        _updateFlowThresholds(reachId, returnPeriod);
        notifyListeners();
        return returnPeriod;
      },
    );
  }

  // Helper to ensure a return period is in the correct unit
  ReturnPeriod _ensureCorrectUnit(ReturnPeriod returnPeriod) {
    if (returnPeriod.unit == _flowUnitsService.preferredUnit) {
      return returnPeriod;
    }

    return returnPeriod.convertTo(
      _flowUnitsService.preferredUnit,
      _flowUnitsService,
    );
  }

  // Update the flow thresholds map for quick access
  void _updateFlowThresholds(String reachId, ReturnPeriod returnPeriod) {
    // This method stays the same since ReturnPeriod now handles units internally
    final thresholds = <String, double>{};

    // Get thresholds for all standard years
    for (final year in ReturnPeriod.standardYears) {
      final flow = returnPeriod.getFlowForYear(year);
      if (flow != null) {
        thresholds['$year-year'] = flow;
      }
    }

    _flowThresholds[reachId] = thresholds;
  }

  // Get flow category for a specific flow value
  Future<String?> getFlowCategory(
    String reachId,
    double flow, {
    FlowUnit flowUnit =
        FlowUnit.cfs, // Add parameter to specify unit of provided flow
  }) async {
    // Try from cached return period first
    if (_cachedReturnPeriods.containsKey(reachId)) {
      return _cachedReturnPeriods[reachId]!.getFlowCategory(
        flow,
        fromUnit: flowUnit,
      );
    }

    // Try from forecast provider
    final forecastReturnPeriod = _forecastProvider.getReturnPeriodFor(reachId);
    if (forecastReturnPeriod != null) {
      return forecastReturnPeriod.getFlowCategory(flow, fromUnit: flowUnit);
    }

    // Fetch from repository if needed
    final result = await _getFlowCategory(reachId, flow, flowUnit: flowUnit);

    return result.fold((failure) {
      _errorMessages[reachId] = _mapFailureToMessage(failure);
      notifyListeners();
      return null;
    }, (category) => category);
  }

  // Get flow thresholds for a reach
  Map<String, double> getFlowThresholds(String reachId) {
    return _flowThresholds[reachId] ?? {};
  }

  // Check if flow exceeds a specific return period threshold
  Future<bool?> checkFlowExceedsThreshold(
    String reachId,
    double flow,
    int returnPeriodYear,
  ) async {
    // Try from cached return period first
    if (_cachedReturnPeriods.containsKey(reachId)) {
      final threshold = _cachedReturnPeriods[reachId]!.getFlowForYear(
        returnPeriodYear,
      );
      if (threshold != null) {
        return flow >= threshold;
      }
    }

    // Try from forecast provider
    final forecastReturnPeriod = _forecastProvider.getReturnPeriodFor(reachId);
    if (forecastReturnPeriod != null) {
      final threshold = forecastReturnPeriod.getFlowForYear(returnPeriodYear);
      if (threshold != null) {
        return flow >= threshold;
      }
    }

    final result = await _checkFlowExceedsThreshold(
      reachId,
      flow,
      returnPeriodYear,
    );

    return result.fold((failure) {
      _errorMessages[reachId] = _mapFailureToMessage(failure);
      notifyListeners();
      return null;
    }, (exceeds) => exceeds);
  }

  // Get color for flow based on return period thresholds
  Color getColorForFlow(String reachId, double flow) {
    // Try from cached return period first
    if (_cachedReturnPeriods.containsKey(reachId)) {
      return FlowThresholds.getColorForFlow(
        flow,
        _cachedReturnPeriods[reachId]!,
      );
    }

    // Try from forecast provider
    final forecastReturnPeriod = _forecastProvider.getReturnPeriodFor(reachId);
    if (forecastReturnPeriod != null) {
      return FlowThresholds.getColorForFlow(flow, forecastReturnPeriod);
    }

    return Colors.grey; // Default color if no return period data available
  }

  // Get detailed description of flow condition
  String getFlowDescription(String reachId, double flow) {
    // Try from cached return period first
    if (_cachedReturnPeriods.containsKey(reachId)) {
      return FlowThresholds.getFlowSummary(
        flow,
        _cachedReturnPeriods[reachId]!,
      );
    }

    // Try from forecast provider
    final forecastReturnPeriod = _forecastProvider.getReturnPeriodFor(reachId);
    if (forecastReturnPeriod != null) {
      return FlowThresholds.getFlowSummary(flow, forecastReturnPeriod);
    }

    return 'Flow information not available';
  }

  // Calculate the flow as a percentage relative to return period thresholds
  double getFlowPercentage(String reachId, double flow) {
    // Try from cached return period first
    if (_cachedReturnPeriods.containsKey(reachId)) {
      return FlowThresholds.calculateFlowPercentage(
        flow,
        _cachedReturnPeriods[reachId]!,
      );
    }

    // Try from forecast provider
    final forecastReturnPeriod = _forecastProvider.getReturnPeriodFor(reachId);
    if (forecastReturnPeriod != null) {
      return FlowThresholds.calculateFlowPercentage(flow, forecastReturnPeriod);
    }

    return 0.0; // Default percentage if no return period data available
  }

  // Check if the flow is at concerning levels
  bool isFlowConcerning(String reachId, double flow) {
    // Try from cached return period first
    if (_cachedReturnPeriods.containsKey(reachId)) {
      return FlowThresholds.isFlowConcerning(
        flow,
        _cachedReturnPeriods[reachId]!,
      );
    }

    // Try from forecast provider
    final forecastReturnPeriod = _forecastProvider.getReturnPeriodFor(reachId);
    if (forecastReturnPeriod != null) {
      return FlowThresholds.isFlowConcerning(flow, forecastReturnPeriod);
    }

    return false; // Default if no return period data available
  }

  // Sync with forecast provider's return period data
  void syncWithForecastProvider(String reachId) {
    final forecastReturnPeriod = _forecastProvider.getReturnPeriodFor(reachId);
    if (forecastReturnPeriod != null) {
      _cachedReturnPeriods[reachId] = forecastReturnPeriod;
      _lastFetchTimes[reachId] = DateTime.now();
      _loadingStates[reachId] = ReturnPeriodLoadingState.loaded;
      _updateFlowThresholds(reachId, forecastReturnPeriod);
      notifyListeners();
    }
  }

  // Force refresh return period data
  Future<ReturnPeriod?> refreshReturnPeriod(String reachId) async {
    return getReturnPeriod(reachId, forceRefresh: true);
  }

  // Clear cached data
  void clearCache() {
    _cachedReturnPeriods.clear();
    _errorMessages.clear();
    _loadingStates.clear();
    _lastFetchTimes.clear();
    _flowThresholds.clear();
    notifyListeners();
  }

  // Clear cache for specific reach
  void clearCacheFor(String reachId) {
    _cachedReturnPeriods.remove(reachId);
    _errorMessages.remove(reachId);
    _loadingStates.remove(reachId);
    _lastFetchTimes.remove(reachId);
    _flowThresholds.remove(reachId);
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

  // Update the forecast provider reference
  void updateForecastProvider(ForecastProvider forecastProvider) {
    forecastProvider = forecastProvider;
    // Sync any cached data
    for (final reachId in _cachedReturnPeriods.keys) {
      syncWithForecastProvider(reachId);
    }
  }
}
