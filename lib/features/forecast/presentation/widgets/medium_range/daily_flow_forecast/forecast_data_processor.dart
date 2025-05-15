// lib/features/forecast/presentation/widgets/medium_range/forecast_data_processor.dart

import 'package:flutter/material.dart';
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

  DailyFlowForecast({
    required this.date,
    required this.minFlow,
    required this.maxFlow,
    required this.avgFlow,
    required this.flowCategory,
    required this.dataSource,
    required this.hourlyData,
  });

  /// Get color for this flow category
  Color get categoryColor => FlowThresholds.getColorForCategory(flowCategory);
}

/// Utility class to process forecast data into daily aggregated format
class ForecastDataProcessor {
  /// Process medium range forecast data to get daily aggregated data
  static List<DailyFlowForecast> processMediumRangeForecast(
    ForecastCollection forecastCollection,
    ReturnPeriod? returnPeriod,
  ) {
    // Group forecasts by day
    final Map<String, List<Forecast>> forecastsByDay = {};
    final Map<String, Map<DateTime, double>> hourlyDataByDay = {};
    final Map<String, String> dataSourceByDay = {};

    // Extract member info from first forecast if available
    String dataSource = "unknown";
    if (forecastCollection.forecasts.isNotEmpty) {
      final firstForecast = forecastCollection.forecasts.first;
      dataSource = firstForecast.member ?? "mean";
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
      final minFlow = flowValues.reduce((a, b) => a < b ? a : b);
      final maxFlow = flowValues.reduce((a, b) => a > b ? a : b);
      final avgFlow =
          flowValues.isEmpty
              ? 0.0
              : (flowValues.reduce((a, b) => a + b) / flowValues.length)
                  .toDouble();

      // Determine predominant flow category
      String flowCategory = 'Unknown';
      if (returnPeriod != null) {
        flowCategory = returnPeriod.getFlowCategory(avgFlow);
      }

      dailyForecasts.add(
        DailyFlowForecast(
          date: date,
          minFlow: minFlow,
          maxFlow: maxFlow,
          avgFlow: avgFlow,
          flowCategory: flowCategory,
          dataSource: dataSourceByDay[dateKey] ?? dataSource,
          hourlyData: hourlyDataByDay[dateKey] ?? {},
        ),
      );
    }

    // Sort by date
    dailyForecasts.sort((a, b) => a.date.compareTo(b.date));

    return dailyForecasts;
  }

  /// Calculate the overall min and max flow values across all daily forecasts
  /// Used for normalizing the range bars
  static Map<String, double> getFlowBounds(
    List<DailyFlowForecast> dailyForecasts,
  ) {
    if (dailyForecasts.isEmpty) {
      return {'min': 0, 'max': 100}; // Default fallback
    }

    double minFlow = dailyForecasts.first.minFlow;
    double maxFlow = dailyForecasts.first.maxFlow;

    for (final forecast in dailyForecasts) {
      if (forecast.minFlow < minFlow) minFlow = forecast.minFlow;
      if (forecast.maxFlow > maxFlow) maxFlow = forecast.maxFlow;
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

    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);

    if (date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day) {
      return 'Tomorrow';
    }

    // Format weekday name
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[date.weekday - 1];
  }
}
