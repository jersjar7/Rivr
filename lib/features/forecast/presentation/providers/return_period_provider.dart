// lib/features/forecast/presentation/providers/return_period_provider.dart

import 'package:flutter/material.dart';
import 'package:rivr/core/error/failures.dart';
import 'package:rivr/features/forecast/domain/entities/return_period.dart';
import 'package:rivr/features/forecast/domain/usecases/get_return_periods.dart';
import 'package:rivr/features/forecast/utils/flow_thresholds.dart';

class ReturnPeriodProvider extends ChangeNotifier {
  final GetReturnPeriods _getReturnPeriods;
  final GetFlowCategory _getFlowCategory;
  final CheckFlowExceedsThreshold _checkFlowExceedsThreshold;

  ReturnPeriodProvider({
    required GetReturnPeriods getReturnPeriods,
    required GetFlowCategory getFlowCategory,
    required CheckFlowExceedsThreshold checkFlowExceedsThreshold,
  }) : _getReturnPeriods = getReturnPeriods,
       _getFlowCategory = getFlowCategory,
       _checkFlowExceedsThreshold = checkFlowExceedsThreshold;

  final Map<String, ReturnPeriod> _cachedReturnPeriods = {};
  final Map<String, String> _errorMessages = {};
  bool _isLoading = false;

  // Getters
  bool get isLoading => _isLoading;
  String? getErrorFor(String reachId) => _errorMessages[reachId];
  bool hasErrorFor(String reachId) => _errorMessages.containsKey(reachId);
  bool hasReturnPeriodFor(String reachId) =>
      _cachedReturnPeriods.containsKey(reachId);

  // Get return period data for a reach
  Future<ReturnPeriod?> getReturnPeriod(
    String reachId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cachedReturnPeriods.containsKey(reachId)) {
      return _cachedReturnPeriods[reachId];
    }

    _isLoading = true;
    _errorMessages.remove(reachId);
    notifyListeners();

    final result = await _getReturnPeriods(reachId, forceRefresh: forceRefresh);

    return result.fold(
      (failure) {
        _errorMessages[reachId] = _mapFailureToMessage(failure);
        _isLoading = false;
        notifyListeners();
        return null;
      },
      (returnPeriod) {
        _cachedReturnPeriods[reachId] = returnPeriod;
        _isLoading = false;
        notifyListeners();
        return returnPeriod;
      },
    );
  }

  // Get flow category for a specific flow value
  Future<String?> getFlowCategory(String reachId, double flow) async {
    if (_cachedReturnPeriods.containsKey(reachId)) {
      return _cachedReturnPeriods[reachId]!.getFlowCategory(flow);
    }

    final result = await _getFlowCategory(reachId, flow);

    return result.fold((failure) {
      _errorMessages[reachId] = _mapFailureToMessage(failure);
      notifyListeners();
      return null;
    }, (category) => category);
  }

  // Check if flow exceeds a specific return period threshold
  Future<bool?> checkFlowExceedsThreshold(
    String reachId,
    double flow,
    int returnPeriodYear,
  ) async {
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
    if (_cachedReturnPeriods.containsKey(reachId)) {
      return FlowThresholds.getColorForFlow(
        flow,
        _cachedReturnPeriods[reachId]!,
      );
    }
    return Colors.grey; // Default color if no return period data available
  }

  // Get detailed description of flow condition
  String getFlowDescription(String reachId, double flow) {
    if (_cachedReturnPeriods.containsKey(reachId)) {
      return FlowThresholds.getFlowSummary(
        flow,
        _cachedReturnPeriods[reachId]!,
      );
    }
    return 'Flow information not available';
  }

  // Calculate the flow as a percentage relative to return period thresholds
  double getFlowPercentage(String reachId, double flow) {
    if (_cachedReturnPeriods.containsKey(reachId)) {
      return FlowThresholds.calculateFlowPercentage(
        flow,
        _cachedReturnPeriods[reachId]!,
      );
    }
    return 0.0; // Default percentage if no return period data available
  }

  // Check if the flow is at concerning levels
  bool isFlowConcerning(String reachId, double flow) {
    if (_cachedReturnPeriods.containsKey(reachId)) {
      return FlowThresholds.isFlowConcerning(
        flow,
        _cachedReturnPeriods[reachId]!,
      );
    }
    return false; // Default if no return period data available
  }

  // Clear cached data
  void clearCache() {
    _cachedReturnPeriods.clear();
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
