// lib/features/forecast/utils/flow_thresholds.dart

import 'package:flutter/material.dart';
import 'package:rivr/core/models/flow_unit.dart';
import 'package:rivr/features/forecast/domain/entities/return_period.dart';

/// Utility class for handling flow thresholds and categories based on return periods
class FlowThresholds {
  /// Flow categories with specific safety and condition details
  static const Map<String, String> categories = {
    'Low': 'Shallow waters and potentially exposed obstacles.',
    'Normal': 'Ideal conditions for most river activities.',
    'Moderate': 'Slightly faster current with good visibility.',
    'Elevated': 'Strong current with potential for submerged hazards.',
    'High': 'Powerful water flow with difficult navigation conditions.',
    'Very High': 'Rapid currents with significant danger of capsizing.',
    'Extreme': 'Severe flooding with destructive potential.',
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
    final details = categories[category] ?? 'Flow information unavailable';

    switch (category) {
      case 'Low':
        return 'The river is running below normal levels. $details Suitable for experienced users who know how to navigate shallow sections.';
      case 'Normal':
        return 'The river is flowing at normal levels. $details Safe for most recreational activities with standard precautions.';
      case 'Moderate':
        return 'The river has moderate flow above normal levels. $details Most users should exercise general caution.';
      case 'Elevated':
        return 'The river is flowing at elevated levels. $details Recreational users should be experienced and prepared for challenging conditions.';
      case 'High':
        return 'The river is flowing at high levels. $details Not recommended for recreational use except by experts with proper equipment.';
      case 'Very High':
        return 'WARNING: The river is at very high levels. $details All recreational activities should be postponed. Stay away from riverbanks.';
      case 'Extreme':
        return 'DANGER: The river is at extreme flood levels. $details Evacuation may be necessary in flood-prone areas. Keep well away from the river.';
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
        return 'No safety concerns, but be aware of possibly restricted passage in some areas.';
      case 'Normal':
        return 'Safe conditions for most river activities with standard precautions.';
      case 'Moderate':
        return 'Use general caution, appropriate for intermediate skill levels.';
      case 'Elevated':
        return 'Exercise heightened caution. Suitable for experienced users only.';
      case 'High':
        return 'Consider postponing river activities. Expert skill level required.';
      case 'Very High':
        return 'Not recommended for any recreational use. Dangerous conditions exist.';
      case 'Extreme':
        return 'Life-threatening conditions. Emergency situation. Avoid all river access.';
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
