// lib/features/forecast/domain/entities/return_period.dart

import 'package:rivr/core/models/flow_unit.dart';
import 'package:rivr/core/services/flow_units_service.dart';

class ReturnPeriod {
  static const List<int> standardYears = [2, 5, 10, 25, 50, 100];

  final String reachId;
  final Map<int, double> flowValues;
  final DateTime retrievedAt;

  // Add unit property to indicate what unit the stored values are in
  final FlowUnit unit;

  ReturnPeriod({
    required this.reachId,
    required this.flowValues,
    DateTime? retrievedAt,
    this.unit = FlowUnit.cfs, // Default to CFS for backward compatibility
  }) : retrievedAt = retrievedAt ?? DateTime.now();

  double? getFlowForYear(int year) {
    return flowValues[year];
  }

  bool isStale() {
    // Return periods rarely change, so we consider them stale after 30 days
    final now = DateTime.now();
    return now.difference(retrievedAt).inDays > 30;
  }

  // Modified to handle unit conversion
  String getFlowCategory(
    double flow, {
    FlowUnit fromUnit =
        FlowUnit.cfs, // Add parameter to specify unit of provided flow
  }) {
    // Convert flow to the same unit as stored in this ReturnPeriod object if needed
    double comparableFlow = flow;
    if (fromUnit != unit) {
      // Simple conversion - in a real implementation, you'd use the FlowUnitsService
      comparableFlow =
          fromUnit == FlowUnit.cfs
              ? flow *
                  FlowUnit
                      .cfsToFcmsFactor // Convert CFS to CMS
              : flow * FlowUnit.cmsToFcsFactor; // Convert CMS to CFS
    }

    // Now compare with the stored threshold values which are already in the correct unit
    if (comparableFlow < (flowValues[2] ?? double.infinity)) {
      return 'Low';
    } else if (comparableFlow < (flowValues[5] ?? double.infinity)) {
      return 'Normal';
    } else if (comparableFlow < (flowValues[10] ?? double.infinity)) {
      return 'Moderate';
    } else if (comparableFlow < (flowValues[25] ?? double.infinity)) {
      return 'Elevated';
    } else if (comparableFlow < (flowValues[50] ?? double.infinity)) {
      return 'High';
    } else if (comparableFlow < (flowValues[100] ?? double.infinity)) {
      return 'Very High';
    } else {
      return 'Extreme';
    }
  }

  int? getReturnPeriod(double flow, {FlowUnit fromUnit = FlowUnit.cfs}) {
    // Convert flow to the same unit as stored in this ReturnPeriod object if needed
    double comparableFlow = flow;
    if (fromUnit != unit) {
      // Simple conversion - in a real implementation, you'd use the FlowUnitsService
      comparableFlow =
          fromUnit == FlowUnit.cfs
              ? flow *
                  FlowUnit
                      .cfsToFcmsFactor // Convert CFS to CMS
              : flow * FlowUnit.cmsToFcsFactor; // Convert CMS to CFS
    }

    // Find the closest return period year for this flow
    int? closestYear;
    double minDifference = double.infinity;

    for (final year in standardYears) {
      final returnFlow = flowValues[year];
      if (returnFlow == null) continue;

      final difference = (returnFlow - comparableFlow).abs();
      if (difference < minDifference) {
        minDifference = difference;
        closestYear = year;
      }
    }

    return closestYear;
  }

  // Convert all values to a different unit
  ReturnPeriod convertTo(FlowUnit targetUnit, FlowUnitsService service) {
    if (unit == targetUnit) return this; // No conversion needed

    // Create a new map with converted values
    final convertedValues = <int, double>{};

    for (final entry in flowValues.entries) {
      final convertedValue =
          unit == FlowUnit.cfs
              ? service.cfsToCms(entry.value)
              : service.cmsToCfs(entry.value);

      convertedValues[entry.key] = convertedValue;
    }

    // Return a new ReturnPeriod with converted values
    return ReturnPeriod(
      reachId: reachId,
      flowValues: convertedValues,
      retrievedAt: retrievedAt,
      unit: targetUnit,
    );
  }
}

class ReturnPeriodModel extends ReturnPeriod {
  ReturnPeriodModel({
    required super.reachId,
    required super.flowValues,
    super.retrievedAt,
    super.unit,
  });

  // Modified factory to handle unit conversion
  factory ReturnPeriodModel.fromJson(
    Map<String, dynamic> json,
    String reachId, {
    FlowUnit sourceUnit = FlowUnit.cms, // API data is in CMS
    FlowUnit targetUnit = FlowUnit.cfs, // Default target is CFS
    FlowUnitsService? flowUnitsService, // Service for conversion
  }) {
    final Map<int, double> flowValues = {};

    // Extract values from JSON (assumed to be in sourceUnit)
    for (final year in ReturnPeriod.standardYears) {
      final key = 'return_period_$year';
      if (json.containsKey(key) && json[key] != null) {
        final value = (json[key] as num).toDouble();

        // Convert to target unit if needed and if service is provided
        if (sourceUnit != targetUnit && flowUnitsService != null) {
          final convertedValue =
              sourceUnit == FlowUnit.cms
                  ? flowUnitsService.cmsToCfs(value)
                  : flowUnitsService.cfsToCms(value);

          flowValues[year] = convertedValue;
        } else {
          flowValues[year] = value;
        }
      }
    }

    return ReturnPeriodModel(
      reachId: reachId,
      flowValues: flowValues,
      retrievedAt: DateTime.now(),
      unit: targetUnit, // Store what unit the values are in
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      'reach_id': reachId,
      'timestamp': retrievedAt.millisecondsSinceEpoch,
      'unit': unit.toString(), // Save the unit information
    };

    for (final entry in flowValues.entries) {
      json['return_period_${entry.key}'] = entry.value;
    }

    return json;
  }
}
