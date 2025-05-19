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
  ForecastProvider _forecastProvider;

  // FlowUnitsService
  final FlowUnitsService _flowUnitsService;

  // FlowValueFormatter
  final FlowValueFormatter _flowFormatter;

  ReturnPeriodProvider({
    required GetReturnPeriods getReturnPeriods,
    required GetFlowCategory getFlowCategory,
    required CheckFlowExceedsThreshold checkFlowExceedsThreshold,
    required ForecastProvider forecastProvider,
    required FlowUnitsService flowUnitsService,
    required FlowValueFormatter flowFormatter,
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

  // Get cached return period, ensuring it's in the current preferred unit
  ReturnPeriod? getCachedReturnPeriod(String reachId) {
    if (!_cachedReturnPeriods.containsKey(reachId)) return null;

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

  // Get return period data for a reach, ensuring it's in the correct unit
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
      return getCachedReturnPeriod(reachId);
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
        // Ensure returnPeriod is in the preferred unit
        final returnPeriodInPreferredUnit = _ensureCorrectUnit(returnPeriod);

        _cachedReturnPeriods[reachId] = returnPeriodInPreferredUnit;
        _lastFetchTimes[reachId] = DateTime.now();
        _loadingStates[reachId] = ReturnPeriodLoadingState.loaded;
        _updateFlowThresholds(reachId, returnPeriodInPreferredUnit);
        notifyListeners();
        return returnPeriodInPreferredUnit;
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

  // Get flow category for a specific flow value with unit handling
  Future<String?> getFlowCategory(
    String reachId,
    double flow, {
    FlowUnit fromUnit = FlowUnit.cfs, // For client-side conversion
  }) async {
    // Try from cached return period first
    if (_cachedReturnPeriods.containsKey(reachId)) {
      return _cachedReturnPeriods[reachId]!.getFlowCategory(
        flow,
        fromUnit: fromUnit,
      );
    }

    // Try from forecast provider
    final forecastReturnPeriod = _forecastProvider.getReturnPeriodFor(reachId);
    if (forecastReturnPeriod != null) {
      return forecastReturnPeriod.getFlowCategory(flow, fromUnit: fromUnit);
    }

    // Convert the flow to the preferred unit before calling the use case
    double convertedFlow = _flowUnitsService.convertToPreferredUnit(
      flow,
      fromUnit,
    );

    // Fetch from repository if needed
    final result = await _getFlowCategory(reachId, convertedFlow);

    return result.fold((failure) {
      _errorMessages[reachId] = _mapFailureToMessage(failure);
      notifyListeners();
      return null;
    }, (category) => category);
  }

  // Get flow thresholds for a reach in the current unit
  Map<String, double> getFlowThresholds(String reachId) {
    return _flowThresholds[reachId] ?? {};
  }

  // Get formatted flow thresholds with proper unit labels
  Map<String, String> getFormattedFlowThresholds(String reachId) {
    final thresholds = getFlowThresholds(reachId);
    final Map<String, String> formattedThresholds = {};

    thresholds.forEach((key, value) {
      formattedThresholds[key] = _flowFormatter.format(value);
    });

    return formattedThresholds;
  }

  // Check if flow exceeds a specific return period threshold with unit handling
  Future<bool?> checkFlowExceedsThreshold(
    String reachId,
    double flow,
    int returnPeriodYear, {
    FlowUnit fromUnit = FlowUnit.cfs, // For client-side conversion
  }) async {
    // Try from cached return period first
    if (_cachedReturnPeriods.containsKey(reachId)) {
      // Convert flow to match the unit of the cached return period if needed
      double comparableFlow = _flowUnitsService.convertToPreferredUnit(
        flow,
        fromUnit,
      );

      final threshold = _cachedReturnPeriods[reachId]!.getFlowForYear(
        returnPeriodYear,
      );
      if (threshold != null) {
        return comparableFlow >= threshold;
      }
    }

    // Try from forecast provider
    final forecastReturnPeriod = _forecastProvider.getReturnPeriodFor(reachId);
    if (forecastReturnPeriod != null) {
      // Convert flow to match the unit of the forecast return period if needed
      double comparableFlow = _flowUnitsService.convertToPreferredUnit(
        flow,
        fromUnit,
      );

      final threshold = forecastReturnPeriod.getFlowForYear(returnPeriodYear);
      if (threshold != null) {
        return comparableFlow >= threshold;
      }
    }

    // Convert the flow to the preferred unit before calling the use case
    double convertedFlow = _flowUnitsService.convertToPreferredUnit(
      flow,
      fromUnit,
    );

    // Call the use case
    final result = await _checkFlowExceedsThreshold(
      reachId,
      convertedFlow,
      returnPeriodYear,
    );

    return result.fold((failure) {
      _errorMessages[reachId] = _mapFailureToMessage(failure);
      notifyListeners();
      return null;
    }, (exceeds) => exceeds);
  }

  // Get color for flow based on return period thresholds with unit handling
  Color getColorForFlow(
    String reachId,
    double flow, {
    FlowUnit fromUnit = FlowUnit.cfs, // Add parameter for flow unit
  }) {
    // Try from cached return period first
    if (_cachedReturnPeriods.containsKey(reachId)) {
      // Convert flow if needed
      double comparableFlow = _flowUnitsService.convertToPreferredUnit(
        flow,
        fromUnit,
      );

      return FlowThresholds.getColorForFlow(
        comparableFlow,
        _cachedReturnPeriods[reachId]!,
      );
    }

    // Try from forecast provider
    final forecastReturnPeriod = _forecastProvider.getReturnPeriodFor(reachId);
    if (forecastReturnPeriod != null) {
      // Convert flow if needed
      double comparableFlow = _flowUnitsService.convertToPreferredUnit(
        flow,
        fromUnit,
      );

      return FlowThresholds.getColorForFlow(
        comparableFlow,
        forecastReturnPeriod,
      );
    }

    return Colors.grey; // Default color if no return period data available
  }

  // Get detailed description of flow condition with unit handling
  String getFlowDescription(
    String reachId,
    double flow, {
    FlowUnit fromUnit = FlowUnit.cfs, // Add parameter for flow unit
  }) {
    // Try from cached return period first
    if (_cachedReturnPeriods.containsKey(reachId)) {
      // Convert flow if needed
      double comparableFlow = _flowUnitsService.convertToPreferredUnit(
        flow,
        fromUnit,
      );

      return FlowThresholds.getFlowSummary(
        comparableFlow,
        _cachedReturnPeriods[reachId]!,
      );
    }

    // Try from forecast provider
    final forecastReturnPeriod = _forecastProvider.getReturnPeriodFor(reachId);
    if (forecastReturnPeriod != null) {
      // Convert flow if needed
      double comparableFlow = _flowUnitsService.convertToPreferredUnit(
        flow,
        fromUnit,
      );

      return FlowThresholds.getFlowSummary(
        comparableFlow,
        forecastReturnPeriod,
      );
    }

    return 'Flow information not available';
  }

  // Calculate the flow as a percentage relative to return period thresholds with unit handling
  double getFlowPercentage(
    String reachId,
    double flow, {
    FlowUnit fromUnit = FlowUnit.cfs, // Add parameter for flow unit
  }) {
    // Try from cached return period first
    if (_cachedReturnPeriods.containsKey(reachId)) {
      // Convert flow if needed
      double comparableFlow = _flowUnitsService.convertToPreferredUnit(
        flow,
        fromUnit,
      );

      return FlowThresholds.calculateFlowPercentage(
        comparableFlow,
        _cachedReturnPeriods[reachId]!,
      );
    }

    // Try from forecast provider
    final forecastReturnPeriod = _forecastProvider.getReturnPeriodFor(reachId);
    if (forecastReturnPeriod != null) {
      // Convert flow if needed
      double comparableFlow = _flowUnitsService.convertToPreferredUnit(
        flow,
        fromUnit,
      );

      return FlowThresholds.calculateFlowPercentage(
        comparableFlow,
        forecastReturnPeriod,
      );
    }

    return 0.0; // Default percentage if no return period data available
  }

  // Check if the flow is at concerning levels with unit handling
  bool isFlowConcerning(
    String reachId,
    double flow, {
    FlowUnit fromUnit = FlowUnit.cfs, // Add parameter for flow unit
  }) {
    // Try from cached return period first
    if (_cachedReturnPeriods.containsKey(reachId)) {
      // Convert flow if needed
      double comparableFlow = _flowUnitsService.convertToPreferredUnit(
        flow,
        fromUnit,
      );

      return FlowThresholds.isFlowConcerning(
        comparableFlow,
        _cachedReturnPeriods[reachId]!,
      );
    }

    // Try from forecast provider
    final forecastReturnPeriod = _forecastProvider.getReturnPeriodFor(reachId);
    if (forecastReturnPeriod != null) {
      // Convert flow if needed
      double comparableFlow = _flowUnitsService.convertToPreferredUnit(
        flow,
        fromUnit,
      );

      return FlowThresholds.isFlowConcerning(
        comparableFlow,
        forecastReturnPeriod,
      );
    }

    return false; // Default if no return period data available
  }

  // Get threshold for a specific return period year with proper unit handling
  double? getThresholdForYear(String reachId, int year, {FlowUnit? toUnit}) {
    final returnPeriod = getCachedReturnPeriod(reachId);
    if (returnPeriod == null) {
      // Try from forecast provider
      final forecastReturnPeriod = _forecastProvider.getReturnPeriodFor(
        reachId,
      );
      if (forecastReturnPeriod == null) return null;

      final value = forecastReturnPeriod.getFlowForYear(year);
      if (value == null) return null;

      // Convert if needed
      if (toUnit != null && toUnit != forecastReturnPeriod.unit) {
        return forecastReturnPeriod.unit == FlowUnit.cfs
            ? _flowUnitsService.cfsToCms(value)
            : _flowUnitsService.cmsToCfs(value);
      }

      return value;
    }

    final value = returnPeriod.getFlowForYear(year);
    if (value == null) return null;

    // Convert if needed
    if (toUnit != null && toUnit != returnPeriod.unit) {
      return returnPeriod.unit == FlowUnit.cfs
          ? _flowUnitsService.cfsToCms(value)
          : _flowUnitsService.cmsToCfs(value);
    }

    return value;
  }

  // Get formatted threshold for a specific return period year
  String getFormattedThresholdForYear(String reachId, int year) {
    final threshold = getThresholdForYear(reachId, year);
    if (threshold == null) return 'N/A';

    return _flowFormatter.format(threshold);
  }

  // Sync with forecast provider's return period data
  void syncWithForecastProvider(String reachId) {
    final forecastReturnPeriod = _forecastProvider.getReturnPeriodFor(reachId);
    if (forecastReturnPeriod != null) {
      // Ensure return period is in the preferred unit
      ReturnPeriod returnPeriodInCorrectUnit = _ensureCorrectUnit(
        forecastReturnPeriod,
      );

      _cachedReturnPeriods[reachId] = returnPeriodInCorrectUnit;
      _lastFetchTimes[reachId] = DateTime.now();
      _loadingStates[reachId] = ReturnPeriodLoadingState.loaded;
      _updateFlowThresholds(reachId, returnPeriodInCorrectUnit);
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
    _forecastProvider = forecastProvider;
    // Sync any cached data
    for (final reachId in _cachedReturnPeriods.keys) {
      syncWithForecastProvider(reachId);
    }
  }

  // Get all available return periods for the current unit
  Map<String, ReturnPeriod> getAllReturnPeriods() {
    final convertedReturnPeriods = <String, ReturnPeriod>{};

    _cachedReturnPeriods.forEach((reachId, returnPeriod) {
      convertedReturnPeriods[reachId] = _ensureCorrectUnit(returnPeriod);
    });

    return convertedReturnPeriods;
  }
}
