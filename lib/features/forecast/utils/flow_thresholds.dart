// lib/features/forecast/utils/flow_thresholds.dart

import 'package:flutter/material.dart';
import 'package:rivr/features/forecast/domain/entities/return_period.dart';

/// Utility class for handling flow thresholds and categories based on return periods
class FlowThresholds {
  /// Flow categories based on return periods
  static const Map<String, String> categories = {
    'Low': 'Flow is below normal levels.',
    'Normal': 'Flow is at normal levels.',
    'Moderate': 'Flow is above normal but not concerning.',
    'Elevated': 'Flow is high, use caution when approaching.',
    'High': 'Flow is very high, consider postponing activities.',
    'Very High': 'Flow is at dangerous levels, avoid river.',
    'Extreme': 'Flow is at life-threatening levels, stay away.',
  };

  /// Get color for flow category
  static Color getColorForCategory(String category) {
    switch (category) {
      case 'Low':
        return Colors.blue.shade200;
      case 'Normal':
        return Colors.green;
      case 'Moderate':
        return Colors.yellow;
      case 'Elevated':
        return Colors.orange;
      case 'High':
        return Colors.deepOrange;
      case 'Very High':
        return Colors.red;
      case 'Extreme':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  /// Get color directly from flow and return period
  static Color getColorForFlow(double flow, ReturnPeriod returnPeriod) {
    return getColorForCategory(returnPeriod.getFlowCategory(flow));
  }

  /// Get return period range description for a flow value
  static String getReturnPeriodDescription(
    double flow,
    ReturnPeriod returnPeriod,
  ) {
    final category = returnPeriod.getFlowCategory(flow);
    final description = categories[category] ?? 'Flow information unavailable';

    String returnPeriodText = '';
    int? period = returnPeriod.getReturnPeriod(flow);
    if (period != null) {
      returnPeriodText = ' (approaches $period-year flood level)';
    }

    return '$description$returnPeriodText';
  }

  /// Evaluate if the flow is at concerning levels
  static bool isFlowConcerning(double flow, ReturnPeriod returnPeriod) {
    final category = returnPeriod.getFlowCategory(flow);
    return category == 'Elevated' ||
        category == 'High' ||
        category == 'Very High' ||
        category == 'Extreme';
  }

  /// Map a flow value to a percentage within the return period scale (0-100%)
  static double calculateFlowPercentage(
    double flow,
    ReturnPeriod returnPeriod,
  ) {
    // Get the lowest and highest return period values
    final lowestThreshold = returnPeriod.getFlowForYear(2) ?? 0.0;
    final highestThreshold =
        returnPeriod.getFlowForYear(100) ?? (lowestThreshold * 10);

    if (flow <= lowestThreshold) {
      return 0.0;
    } else if (flow >= highestThreshold) {
      return 100.0;
    }

    // Calculate percentage between lowest and highest threshold
    return ((flow - lowestThreshold) / (highestThreshold - lowestThreshold)) *
        100.0;
  }

  /// Get a user-friendly response about current flow conditions
  static String getFlowSummary(double flow, ReturnPeriod returnPeriod) {
    final category = returnPeriod.getFlowCategory(flow);
    final description = categories[category] ?? 'Flow information unavailable';

    switch (category) {
      case 'Low':
        return 'The river is currently running low. $description';
      case 'Normal':
        return 'The river is flowing at normal levels. $description';
      case 'Moderate':
        return 'The river is flowing at moderate levels. $description';
      case 'Elevated':
        return 'The river is flowing higher than normal. $description';
      case 'High':
        return 'The river is flowing high. $description';
      case 'Very High':
        return 'Warning: The river is flowing very high. $description';
      case 'Extreme':
        return 'Danger: The river is at extreme levels. $description';
      default:
        return 'River flow information unavailable.';
    }
  }
}
