// lib/features/forecast/presentation/widgets/medium_range/forecast_data_processor.dart

import 'package:flutter/material.dart';
import 'package:rivr/core/models/flow_unit.dart';
import 'package:rivr/core/services/flow_units_service.dart';
import 'package:rivr/features/forecast/domain/entities/forecast.dart';
import 'package:rivr/features/forecast/domain/entities/return_period.dart';
import 'package:rivr/features/forecast/utils/flow_thresholds.dart';

/// Model class for aggregated daily forecast data
class DailyFlowForecast {
  final DateTime date;
  final double minFlow;
  final double maxFlow;
  final double avgFlow;
  final String flowCategory;
  final String dataSource; // "mean" or "member1", "member2", etc.
  final Map<DateTime, double> hourlyData; // Hourly data for this day
  final FlowUnit unit; // The unit of the flow values

  DailyFlowForecast({
    required this.date,
    required this.minFlow,
    required this.maxFlow,
    required this.avgFlow,
    required this.flowCategory,
    required this.dataSource,
    required this.hourlyData,
    this.unit = FlowUnit.cfs, // Default is CFS
  });

  /// Get color for this flow category
  Color get categoryColor => FlowThresholds.getColorForCategory(flowCategory);

  /// Convert this forecast to a different unit
  DailyFlowForecast convertToUnit(
    FlowUnit targetUnit,
    FlowUnitsService unitsService,
  ) {
    if (unit == targetUnit) return this; // No conversion needed

    // Apply conversion factor
    final conversionFactor =
        unit == FlowUnit.cfs
            ? FlowUnit.cfsToFcmsFactor
            : FlowUnit.cmsToFcsFactor;

    // Convert hourly data
    final Map<DateTime, double> convertedHourlyData = {};
    hourlyData.forEach((dateTime, flow) {
      convertedHourlyData[dateTime] = flow * conversionFactor;
    });

    return DailyFlowForecast(
      date: date,
      minFlow: minFlow * conversionFactor,
      maxFlow: maxFlow * conversionFactor,
      avgFlow: avgFlow * conversionFactor,
      flowCategory: flowCategory, // Category doesn't change
      dataSource: dataSource,
      hourlyData: convertedHourlyData,
      unit: targetUnit, // Update the unit
    );
  }
}

/// Utility class to process forecast data into daily aggregated format
class ForecastDataProcessor {
  /// Process medium range forecast data to get daily aggregated data with unit conversion
  static List<DailyFlowForecast> processMediumRangeForecast(
    ForecastCollection forecastCollection,
    ReturnPeriod? returnPeriod, {
    FlowUnit sourceUnit = FlowUnit.cfs, // Default source unit is CFS
    FlowUnit? targetUnit, // Optional target unit for conversion
    FlowUnitsService? flowUnitsService, // Required for unit conversion
  }) {
    // Group forecasts by day
    final Map<String, List<Forecast>> forecastsByDay = {};
    final Map<String, Map<DateTime, double>> hourlyDataByDay = {};
    final Map<String, String> dataSourceByDay = {};

    // Extract member info from first forecast if available
    String dataSource = "unknown";
    if (forecastCollection.forecasts.isNotEmpty) {
      final firstForecast = forecastCollection.forecasts.first;
      // Don't default to "mean" - use the actual source information
      dataSource = firstForecast.member ?? "unknown";
    }

    // Group forecasts by day
    for (final forecast in forecastCollection.forecasts) {
      // Format date as YYYY-MM-DD for grouping key
      final date = forecast.validDateTime.toLocal();
      final dateKey =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

      // Initialize lists if needed
      if (!forecastsByDay.containsKey(dateKey)) {
        forecastsByDay[dateKey] = [];
        hourlyDataByDay[dateKey] = {};
        dataSourceByDay[dateKey] = dataSource;
      }

      // Add to the appropriate day
      forecastsByDay[dateKey]!.add(forecast);
      hourlyDataByDay[dateKey]![date] = forecast.flow;
    }

    // Create daily forecasts from grouped data
    final List<DailyFlowForecast> dailyForecasts = [];

    for (final entry in forecastsByDay.entries) {
      final dateKey = entry.key;
      final forecasts = entry.value;
      final dateParts = dateKey.split('-');

      if (forecasts.isEmpty || dateParts.length != 3) continue;

      // Parse date from key
      final date = DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
      );

      // Calculate min, max, avg
      final flowValues = forecasts.map((f) => f.flow).toList();
      final minFlow =
          flowValues.isEmpty ? 0.0 : flowValues.reduce((a, b) => a < b ? a : b);
      final maxFlow =
          flowValues.isEmpty ? 0.0 : flowValues.reduce((a, b) => a > b ? a : b);
      final avgFlow =
          flowValues.isEmpty
              ? 0.0
              : (flowValues.reduce((a, b) => a + b) / flowValues.length);

      // Determine predominant flow category
      String flowCategory = 'Unknown';
      if (returnPeriod != null) {
        flowCategory = returnPeriod.getFlowCategory(
          avgFlow,
          fromUnit: sourceUnit,
        );
      }

      // Create the daily forecast with the source unit
      DailyFlowForecast forecast = DailyFlowForecast(
        date: date,
        minFlow: minFlow,
        maxFlow: maxFlow,
        avgFlow: avgFlow,
        flowCategory: flowCategory,
        dataSource: dataSourceByDay[dateKey] ?? dataSource,
        hourlyData: hourlyDataByDay[dateKey] ?? {},
        unit: sourceUnit, // Explicitly set the source unit
      );

      // Convert to the target unit if needed and if services are provided
      if (targetUnit != null &&
          targetUnit != sourceUnit &&
          flowUnitsService != null) {
        forecast = forecast.convertToUnit(targetUnit, flowUnitsService);
      }

      dailyForecasts.add(forecast);
    }

    // Sort by date
    dailyForecasts.sort((a, b) => a.date.compareTo(b.date));

    return dailyForecasts;
  }

  /// Calculate the overall min and max flow values across all daily forecasts
  /// Used for normalizing the range bars. Ensures consistent unit handling.
  static Map<String, double> getFlowBounds(
    List<DailyFlowForecast> dailyForecasts, {
    FlowUnit? sourceUnit, // Optional source unit
    FlowUnit? targetUnit, // Optional target unit for conversion
    FlowUnitsService? flowUnitsService, // Required for unit conversion
  }) {
    if (dailyForecasts.isEmpty) {
      return {'min': 0, 'max': 100}; // Default fallback
    }

    // Determine the unit of the forecasts
    final currentUnit = dailyForecasts.first.unit;

    // Check if conversion is needed
    final needsConversion =
        targetUnit != null &&
        targetUnit != currentUnit &&
        flowUnitsService != null;

    // Initial values
    double minFlow = dailyForecasts.first.minFlow;
    double maxFlow = dailyForecasts.first.maxFlow;

    // Find min and max across all forecasts
    for (final forecast in dailyForecasts) {
      if (forecast.minFlow < minFlow) minFlow = forecast.minFlow;
      if (forecast.maxFlow > maxFlow) maxFlow = forecast.maxFlow;
    }

    // Apply conversion if needed
    if (needsConversion) {
      final conversionFactor =
          currentUnit == FlowUnit.cfs
              ? FlowUnit.cfsToFcmsFactor
              : FlowUnit.cmsToFcsFactor;

      minFlow = minFlow * conversionFactor;
      maxFlow = maxFlow * conversionFactor;
    }

    // Add a small buffer (5%) for visual clarity
    final range = maxFlow - minFlow;
    minFlow = minFlow - (range * 0.05);
    maxFlow = maxFlow + (range * 0.05);

    return {'min': minFlow, 'max': maxFlow};
  }

  /// Get a user-friendly representation of the day
  static String getDayLabel(DateTime date, bool isToday) {
    if (isToday) return 'Today';

    // Format weekday name
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[date.weekday - 1];
  }

  /// Convert a list of forecasts to a different unit
  static List<Forecast> convertForecasts(
    List<Forecast> forecasts,
    FlowUnit sourceUnit,
    FlowUnit targetUnit,
    FlowUnitsService flowUnitsService,
  ) {
    if (sourceUnit == targetUnit) return forecasts; // No conversion needed

    return forecasts.map((forecast) {
      // Create a new forecast with converted flow
      final convertedFlow = flowUnitsService.convertToPreferredUnit(
        forecast.flow,
        sourceUnit,
      );

      return Forecast(
        reachId: forecast.reachId,
        validTime: forecast.validTime,
        flow: convertedFlow,
        member: forecast.member,
        forecastType: forecast.forecastType,
      );
    }).toList();
  }

  /// Get the average flow value from a list of forecasts with unit handling
  static double getAverageFlow(
    List<Forecast> forecasts, {
    FlowUnit sourceUnit = FlowUnit.cfs,
    FlowUnit? targetUnit,
    FlowUnitsService? flowUnitsService,
  }) {
    if (forecasts.isEmpty) return 0.0;

    // Calculate average in the source unit
    final totalFlow = forecasts.fold<double>(
      0.0,
      (sum, forecast) => sum + forecast.flow,
    );
    final avgFlow = totalFlow / forecasts.length;

    // Convert if needed
    if (targetUnit != null &&
        targetUnit != sourceUnit &&
        flowUnitsService != null) {
      return flowUnitsService.convertToPreferredUnit(avgFlow, sourceUnit);
    }

    return avgFlow;
  }

  /// Calculate summary statistics for a list of flow values with unit handling
  static Map<String, double> calculateFlowStats(
    List<double> flowValues, {
    FlowUnit sourceUnit = FlowUnit.cfs,
    FlowUnit? targetUnit,
    FlowUnitsService? flowUnitsService,
  }) {
    if (flowValues.isEmpty) {
      return {
        'min': 0.0,
        'max': 0.0,
        'avg': 0.0,
        'median': 0.0,
        'p25': 0.0,
        'p75': 0.0,
      };
    }

    // Sort values for percentile calculations
    final sortedValues = List<double>.from(flowValues)..sort();

    // Calculate statistics
    final sum = sortedValues.reduce((a, b) => a + b);
    final min = sortedValues.first;
    final max = sortedValues.last;
    final avg = sum / sortedValues.length;

    // Median (50th percentile)
    final midIndex = sortedValues.length ~/ 2;
    final median =
        sortedValues.length.isOdd
            ? sortedValues[midIndex]
            : (sortedValues[midIndex - 1] + sortedValues[midIndex]) / 2;

    // 25th and 75th percentiles
    final p25Index = ((sortedValues.length - 1) * 0.25).round();
    final p75Index = ((sortedValues.length - 1) * 0.75).round();
    final p25 = sortedValues[p25Index];
    final p75 = sortedValues[p75Index];

    // Apply conversion if needed
    if (targetUnit != null &&
        targetUnit != sourceUnit &&
        flowUnitsService != null) {
      convert(double value) =>
          flowUnitsService.convertToPreferredUnit(value, sourceUnit);

      return {
        'min': convert(min),
        'max': convert(max),
        'avg': convert(avg),
        'median': convert(median),
        'p25': convert(p25),
        'p75': convert(p75),
      };
    }

    // Return statistics in the source unit
    return {
      'min': min,
      'max': max,
      'avg': avg,
      'median': median,
      'p25': p25,
      'p75': p75,
    };
  }

  /// Aggregate hourly flow data into daily statistics with unit handling
  static Map<DateTime, Map<String, double>> aggregateHourlyToDailyStats(
    List<Forecast> forecasts, {
    FlowUnit sourceUnit = FlowUnit.cfs,
    FlowUnit? targetUnit,
    FlowUnitsService? flowUnitsService,
  }) {
    final Map<DateTime, List<double>> dailyFlowValues = {};

    // Group flow values by day
    for (final forecast in forecasts) {
      // Normalize to start of day
      final date = DateTime(
        forecast.validDateTime.year,
        forecast.validDateTime.month,
        forecast.validDateTime.day,
      );

      // Add to list for this day
      dailyFlowValues.putIfAbsent(date, () => []).add(forecast.flow);
    }

    // Calculate statistics for each day
    final Map<DateTime, Map<String, double>> dailyStats = {};

    dailyFlowValues.forEach((date, values) {
      dailyStats[date] = calculateFlowStats(
        values,
        sourceUnit: sourceUnit,
        targetUnit: targetUnit,
        flowUnitsService: flowUnitsService,
      );
    });

    return dailyStats;
  }
}
