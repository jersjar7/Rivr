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

  // Enhanced getter that supports unit conversion
  double? getFlowForYear(int year, {FlowUnit? toUnit}) {
    final value = flowValues[year];
    if (value == null) return null;

    // If no target unit specified or units match, return the raw value
    if (toUnit == null || toUnit == unit) return value;

    // Otherwise, perform the appropriate conversion
    if (unit == FlowUnit.cms && toUnit == FlowUnit.cfs) {
      return value *
          FlowUnit.cmsToFcsFactor; // CMS to CFS (multiply by 35.3147)
    } else if (unit == FlowUnit.cfs && toUnit == FlowUnit.cms) {
      return value *
          FlowUnit.cfsToFcmsFactor; // CFS to CMS (multiply by 0.0283168)
    }

    return value; // Fallback (should never reach here)
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
    print(
      "ReturnPeriod.getFlowCategory: flow=$flow, fromUnit=$fromUnit, unit=$unit",
    );

    // Convert flow to the same unit as stored in this ReturnPeriod object if needed
    double comparableFlow = flow;
    if (fromUnit != unit) {
      // Convert the input flow to match the unit of the stored thresholds
      comparableFlow =
          fromUnit == FlowUnit.cfs && unit == FlowUnit.cms
              ? flow *
                  FlowUnit
                      .cfsToFcmsFactor // Convert CFS to CMS
              : flow * FlowUnit.cmsToFcsFactor; // Convert CMS to CFS
      print("Converted flow: $flow -> $comparableFlow");
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
      comparableFlow =
          fromUnit == FlowUnit.cfs && unit == FlowUnit.cms
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
          unit == FlowUnit.cms
              ? service.cmsToCfs(entry.value) // CMS to CFS
              : service.cfsToCms(entry.value); // CFS to CMS

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
                  ? flowUnitsService.cmsToCfs(value) // CMS to CFS
                  : flowUnitsService.cfsToCms(value); // CFS to CMS

          flowValues[year] = convertedValue;
        } else {
          // Store in original unit if no conversion needed or service missing
          flowValues[year] = value;

          // Note: If conversion is needed but service is missing, we'll store
          // in sourceUnit but declare the unit as targetUnit, which can cause issues
          // A warning log could be added here for debugging purposes
        }
      }
    }

    // If we needed conversion but couldn't do it, keep the original unit
    FlowUnit resultUnit = targetUnit;
    if (sourceUnit != targetUnit && flowUnitsService == null) {
      resultUnit =
          sourceUnit; // Important: use sourceUnit when conversion failed
      print(
        'Warning: ReturnPeriodModel created with values in $sourceUnit but marked as $targetUnit',
      );
    }

    return ReturnPeriodModel(
      reachId: reachId,
      flowValues: flowValues,
      retrievedAt: DateTime.now(),
      unit: resultUnit, // Use the actual unit of the stored values
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
