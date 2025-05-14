// lib/features/forecast/presentation/widgets/hydrograph/hydrograph_factory.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:rivr/features/forecast/domain/entities/forecast.dart';
import 'package:rivr/features/forecast/domain/entities/forecast_types.dart';
import 'package:rivr/features/forecast/domain/entities/return_period.dart';
import 'package:rivr/features/forecast/presentation/widgets/expandable_hydrograph.dart';
import 'package:rivr/features/forecast/presentation/widgets/long_range_hydrograph.dart';
import 'package:rivr/features/forecast/presentation/widgets/medium_range_hydrograph.dart';
import 'package:rivr/features/forecast/presentation/widgets/short_range_hydrograph.dart';

/// Factory class to create appropriate hydrograph widgets based on forecast type
class HydrographFactory {
  /// Creates a hydrograph widget for the specified forecast type
  static Widget createHydrograph({
    required String reachId,
    required ForecastType forecastType,
    required List<Forecast> forecasts,
    ReturnPeriod? returnPeriod,
    Map<DateTime, Map<String, double>>? dailyStats,
    Map<String, Map<String, double>>? longRangeFlows,
  }) {
    switch (forecastType) {
      case ForecastType.shortRange:
        return ShortRangeHydrograph(
          reachId: reachId,
          forecasts: forecasts,
          returnPeriod: returnPeriod,
        );

      case ForecastType.mediumRange:
        return MediumRangeHydrograph(
          reachId: reachId,
          forecasts: forecasts,
          dailyStats: dailyStats,
          returnPeriod: returnPeriod,
        );

      case ForecastType.longRange:
        return LongRangeHydrograph(
          reachId: reachId,
          forecasts: forecasts,
          longRangeFlows: longRangeFlows,
          returnPeriod: returnPeriod,
        );
    }
  }

  /// Creates an expandable hydrograph widget that shows a preview and expands to full view
  static Widget createExpandableHydrograph({
    required String reachId,
    required ForecastType forecastType,
    required List<Forecast> forecasts,
    ReturnPeriod? returnPeriod,
    Map<DateTime, Map<String, double>>? dailyStats,
    Map<String, Map<String, double>>? longRangeFlows,
    double previewHeight = 180,
  }) {
    return ExpandableHydrograph(
      reachId: reachId,
      forecastType: forecastType,
      forecasts: forecasts,
      returnPeriod: returnPeriod,
      dailyStats: dailyStats,
      longRangeFlows: longRangeFlows,
      previewHeight: previewHeight,
    );
  }

  /// Creates a hydrograph widget from a forecast collection
  static Widget createFromForecastCollection({
    required String reachId,
    required ForecastCollection collection,
    ReturnPeriod? returnPeriod,
    Map<DateTime, Map<String, double>>? dailyStats,
    Map<String, Map<String, double>>? longRangeFlows,
    bool expandable = false,
  }) {
    if (expandable) {
      return createExpandableHydrograph(
        reachId: reachId,
        forecastType: collection.forecastType,
        forecasts: collection.forecasts,
        returnPeriod: returnPeriod,
        dailyStats: dailyStats,
        longRangeFlows: longRangeFlows,
      );
    } else {
      return createHydrograph(
        reachId: reachId,
        forecastType: collection.forecastType,
        forecasts: collection.forecasts,
        returnPeriod: returnPeriod,
        dailyStats: dailyStats,
        longRangeFlows: longRangeFlows,
      );
    }
  }

  /// Shows a hydrograph in a modal dialog
  static Future<void> showHydrographDialog({
    required BuildContext context,
    required String reachId,
    required ForecastType forecastType,
    required List<Forecast> forecasts,
    ReturnPeriod? returnPeriod,
    Map<DateTime, Map<String, double>>? dailyStats,
    Map<String, Map<String, double>>? longRangeFlows,
  }) {
    // Use theme-aware route to ensure transitions respect the current theme
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => createHydrograph(
              reachId: reachId,
              forecastType: forecastType,
              forecasts: forecasts,
              returnPeriod: returnPeriod,
              dailyStats: dailyStats,
              longRangeFlows: longRangeFlows,
            ),
      ),
    );
  }

  /// Creates a small preview hydrograph for embedding in cards or thumbnails
  static Widget createPreviewChart({
    required BuildContext context,
    required List<Forecast> forecasts,
    required ForecastType forecastType,
    double height = 120,
    double width = 200,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Sort forecasts by time
    final sortedForecasts = List<Forecast>.from(forecasts)
      ..sort((a, b) => a.validDateTime.compareTo(b.validDateTime));

    if (sortedForecasts.isEmpty) {
      return SizedBox(
        height: height,
        width: width,
        child: Center(
          child: Text(
            'No data available',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    // Use first time as reference point
    final baseTime = sortedForecasts.first.validDateTime;

    // Create simplified spots based on forecast type
    final spots = <FlSpot>[];
    for (var forecast in sortedForecasts) {
      double x;
      switch (forecastType) {
        case ForecastType.shortRange:
          x = forecast.validDateTime.difference(baseTime).inHours.toDouble();
          break;
        case ForecastType.mediumRange:
          x = forecast.validDateTime.difference(baseTime).inHours / 24;
          break;
        case ForecastType.longRange:
          x = forecast.validDateTime.difference(baseTime).inDays / 7;
          break;
      }
      spots.add(FlSpot(x, forecast.flow));
    }

    // Get min/max flow for y-axis scaling
    final minFlow = sortedForecasts
        .map((f) => f.flow)
        .reduce((a, b) => a < b ? a : b);
    final maxFlow = sortedForecasts
        .map((f) => f.flow)
        .reduce((a, b) => a > b ? a : b);

    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.all(8),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              barWidth: 2,
              isStrokeCapRound: true,
              gradient: LinearGradient(
                colors: [colorScheme.primary, colorScheme.secondary],
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.3),
                    colorScheme.secondary.withValues(alpha: 0.1),
                  ],
                ),
              ),
              dotData: FlDotData(show: false),
            ),
          ],
          minY: minFlow * 0.9,
          maxY: maxFlow * 1.1,
        ),
      ),
    );
  }
}
