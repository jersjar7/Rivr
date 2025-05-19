// lib/features/forecast/utils/flow_thresholds.dart

import 'package:flutter/material.dart';
import 'package:rivr/core/models/flow_unit.dart';
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

  /// Get color directly from flow and return period with unit conversion support
  static Color getColorForFlow(
    double flow,
    ReturnPeriod returnPeriod, {
    FlowUnit fromUnit = FlowUnit.cfs,
  }) {
    // Get category using the provided fromUnit
    final category = returnPeriod.getFlowCategory(flow, fromUnit: fromUnit);
    return getColorForCategory(category);
  }

  /// Get return period range description for a flow value with unit conversion support
  static String getReturnPeriodDescription(
    double flow,
    ReturnPeriod returnPeriod, {
    FlowUnit fromUnit = FlowUnit.cfs,
  }) {
    // Get category using the provided fromUnit
    final category = returnPeriod.getFlowCategory(flow, fromUnit: fromUnit);
    final description = categories[category] ?? 'Flow information unavailable';

    String returnPeriodText = '';
    int? period = returnPeriod.getReturnPeriod(flow, fromUnit: fromUnit);
    if (period != null) {
      returnPeriodText = ' (approaches $period-year flood level)';
    }

    return '$description$returnPeriodText';
  }

  /// Evaluate if the flow is at concerning levels with unit conversion support
  static bool isFlowConcerning(
    double flow,
    ReturnPeriod returnPeriod, {
    FlowUnit fromUnit = FlowUnit.cfs,
  }) {
    // Get category using the provided fromUnit
    final category = returnPeriod.getFlowCategory(flow, fromUnit: fromUnit);

    return category == 'Elevated' ||
        category == 'High' ||
        category == 'Very High' ||
        category == 'Extreme';
  }

  /// Map a flow value to a percentage within the return period scale (0-100%) with unit conversion support
  static double calculateFlowPercentage(
    double flow,
    ReturnPeriod returnPeriod, {
    FlowUnit fromUnit = FlowUnit.cfs,
  }) {
    // Convert the flow value if needed (done internally by ReturnPeriod)
    // Get the lowest and highest return period values
    final lowestThreshold = returnPeriod.getFlowForYear(2) ?? 0.0;
    final highestThreshold =
        returnPeriod.getFlowForYear(100) ?? (lowestThreshold * 10);

    // Convert the flow to the same unit as the thresholds if needed
    double comparableFlow = flow;
    if (fromUnit != returnPeriod.unit) {
      // This conversion is done implicitly by ReturnPeriod.getFlowCategory
      // but we need to handle it explicitly here for the percentage calculation
      // Use a simple conversion based on the conversion factors
      comparableFlow =
          fromUnit == FlowUnit.cfs
              ? flow *
                  FlowUnit
                      .cfsToFcmsFactor // Convert CFS to CMS
              : flow * FlowUnit.cmsToFcsFactor; // Convert CMS to CFS
    }

    if (comparableFlow <= lowestThreshold) {
      return 0.0;
    } else if (comparableFlow >= highestThreshold) {
      return 100.0;
    }

    // Calculate percentage between lowest and highest threshold
    return ((comparableFlow - lowestThreshold) /
            (highestThreshold - lowestThreshold)) *
        100.0;
  }

  /// Get a user-friendly response about current flow conditions with unit conversion support
  static String getFlowSummary(
    double flow,
    ReturnPeriod returnPeriod, {
    FlowUnit fromUnit = FlowUnit.cfs,
  }) {
    // Get category using the provided fromUnit
    final category = returnPeriod.getFlowCategory(flow, fromUnit: fromUnit);
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

  /// Get an icon for a flow category
  static IconData getIconForCategory(String category) {
    switch (category) {
      case 'Low':
        return Icons.waves_outlined;
      case 'Normal':
        return Icons.waves;
      case 'Moderate':
        return Icons.water;
      case 'Elevated':
        return Icons.arrow_upward;
      case 'High':
        return Icons.warning_outlined;
      case 'Very High':
        return Icons.warning;
      case 'Extreme':
        return Icons.dangerous;
      default:
        return Icons.waves;
    }
  }

  /// Convert a flow value from one unit to another
  static double convertFlow(double flow, FlowUnit fromUnit, FlowUnit toUnit) {
    if (fromUnit == toUnit) return flow;

    final factor =
        fromUnit == FlowUnit.cfs
            ? FlowUnit.cfsToFcmsFactor
            : FlowUnit.cmsToFcsFactor;

    return flow * factor;
  }

  /// Get warning level description based on the flow category
  static String getWarningLevelDescription(String category) {
    switch (category) {
      case 'Low':
        return 'No concerns at current flow level.';
      case 'Normal':
        return 'Safe conditions for most river activities.';
      case 'Moderate':
        return 'Use caution, especially for inexperienced paddlers.';
      case 'Elevated':
        return 'Elevated conditions - recreational paddlers should use caution.';
      case 'High':
        return 'High water alert - consider postponing river activities.';
      case 'Very High':
        return 'Dangerous conditions - not recommended for recreational use.';
      case 'Extreme':
        return 'Life-threatening conditions - stay away from the river.';
      default:
        return 'Warning level information not available.';
    }
  }

  /// Calculate flow range (min/max) compared to historical data
  static Map<String, double> calculateFlowRange(
    double currentFlow,
    double historicalAvg, {
    double rangeMultiplier = 1.5,
    FlowUnit currentFlowUnit = FlowUnit.cfs,
    FlowUnit historicalUnit = FlowUnit.cfs,
  }) {
    // Convert units if needed
    double comparableCurrentFlow = currentFlow;
    if (currentFlowUnit != historicalUnit) {
      comparableCurrentFlow = convertFlow(
        currentFlow,
        currentFlowUnit,
        historicalUnit,
      );
    }

    final double difference = (comparableCurrentFlow - historicalAvg).abs();
    final double minRange = historicalAvg - (difference * rangeMultiplier);
    final double maxRange = historicalAvg + (difference * rangeMultiplier);

    return {'min': minRange < 0 ? 0.0 : minRange, 'max': maxRange};
  }
}
