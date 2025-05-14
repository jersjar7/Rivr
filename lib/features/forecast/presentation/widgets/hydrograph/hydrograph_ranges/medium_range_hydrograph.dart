// lib/features/forecast/presentation/widgets/medium_range_hydrograph.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rivr/features/forecast/domain/entities/forecast.dart';
import 'package:rivr/features/forecast/presentation/widgets/hydrograph/base_hydrograph.dart';

class MediumRangeHydrograph extends BaseHydrograph {
  final List<Forecast> forecasts;
  final Map<DateTime, Map<String, double>>? dailyStats;

  const MediumRangeHydrograph({
    super.key,
    required super.reachId,
    required this.forecasts,
    this.dailyStats,
    super.returnPeriod,
  }) : super(title: 'Daily Forecast (10-Day)');

  @override
  MediumRangeHydrographState createState() => MediumRangeHydrographState();
}

class MediumRangeHydrographState
    extends BaseHydrographState<MediumRangeHydrograph> {
  // Cache for normalized timestamps (in days)
  late final Map<DateTime, double> _normalizedTimeMap = {};
  late final DateTime _baseTime;

  @override
  void initState() {
    super.initState();
    // Sort forecasts by time
    final sortedForecasts = List<Forecast>.from(widget.forecasts)
      ..sort((a, b) => a.validDateTime.compareTo(b.validDateTime));

    // Use the first valid time as the base time for x-axis normalization
    _baseTime =
        sortedForecasts.isNotEmpty
            ? sortedForecasts.first.validDateTime
            : DateTime.now();

    // Pre-calculate normalized times (in days) for better performance
    for (var forecast in sortedForecasts) {
      final days = forecast.validDateTime.difference(_baseTime).inHours / 24;
      _normalizedTimeMap[forecast.validDateTime] = days;
    }
  }

  @override
  List<FlSpot> generateSpots() {
    final List<FlSpot> spots = [];

    // First add regular forecast spots
    for (var forecast in widget.forecasts) {
      // Get normalized days from base time
      final xValue = _normalizedTimeMap[forecast.validDateTime] ?? 0.0;
      spots.add(FlSpot(xValue, forecast.flow));
    }

    // Add spots from dailyStats if available
    if (widget.dailyStats != null && widget.dailyStats!.isNotEmpty) {
      for (var entry in widget.dailyStats!.entries) {
        final date = entry.key;
        final stats = entry.value;

        // Use 'mean' or 'avg' flow value if available
        final flow = stats['mean'] ?? stats['avg'] ?? stats['flow'];

        if (flow != null) {
          final days = date.difference(_baseTime).inHours / 24;
          spots.add(FlSpot(days, flow));
        }
      }
    }

    // Sort spots by x-value
    spots.sort((a, b) => a.x.compareTo(b.x));

    return spots;
  }

  // Find forecast at specific normalized time (x-value)
  Forecast? _getForecastAtX(double x) {
    // Find closest forecast to the given x value
    Forecast? closest;
    double minDifference = double.infinity;

    for (var forecast in widget.forecasts) {
      final normalizedTime = _normalizedTimeMap[forecast.validDateTime] ?? 0.0;
      final difference = (normalizedTime - x).abs();

      if (difference < minDifference) {
        minDifference = difference;
        closest = forecast;
      }
    }

    return closest;
  }

  @override
  double getMinY() {
    // Start from zero for a clearer representation
    return 0.0;
  }

  @override
  double getMaxY() {
    if (widget.forecasts.isEmpty) return 100.0;

    // Find max flow and add 20% for padding
    double maxFlow = widget.forecasts
        .map((f) => f.flow)
        .reduce((a, b) => a > b ? a : b);

    // Also consider return period thresholds if available
    if (widget.returnPeriod != null) {
      for (final year in [2, 5, 10, 25, 50, 100]) {
        final threshold = widget.returnPeriod!.getFlowForYear(year);
        if (threshold != null && threshold > maxFlow) {
          maxFlow = threshold;
        }
      }
    }

    return maxFlow * 1.2;
  }

  @override
  double getMinX() {
    return 0.0;
  }

  @override
  double getMaxX() {
    if (widget.forecasts.isEmpty) return 10.0; // Default 10 days

    // Get maximum normalized time
    double maxX = widget.forecasts
        .map((f) => _normalizedTimeMap[f.validDateTime] ?? 0.0)
        .reduce((a, b) => a > b ? a : b);

    return maxX;
  }

  @override
  String getTooltipDateText(LineBarSpot spot) {
    final forecast = _getForecastAtX(spot.x);
    if (forecast != null) {
      return DateFormat('EEE, MMM d').format(forecast.validDateTime);
    }

    // Fallback if forecast not found
    final time = _baseTime.add(Duration(hours: (spot.x * 24).toInt()));
    return DateFormat('EEE, MMM d').format(time);
  }

  @override
  AxisTitles buildBottomTitles() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 40,
        interval: 1, // Show every day
        getTitlesWidget: (value, meta) {
          // Convert back to datetime
          final datetime = _baseTime.add(Duration(hours: (value * 24).toInt()));

          // Format based on day
          String dayText;
          if (value == 0) {
            dayText = 'Today';
          } else if (value == 1) {
            dayText = 'Tmrw';
          } else {
            // Show day of week and date
            dayText = DateFormat('E\nM/d').format(datetime);
          }

          return Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              dayText,
              style: TextStyle(
                fontSize: 12,
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          );
        },
      ),
    );
  }

  @override
  LineTouchData buildTouchData([bool isDark = false]) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LineTouchData(
      enabled: true,
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor:
            (spot) =>
                isDark
                    ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.8)
                    : Colors.blueGrey.withValues(alpha: 0.8),
        tooltipRoundedRadius: 8,
        getTooltipItems: (List<LineBarSpot> lineBarsSpot) {
          return lineBarsSpot.map((spot) {
            final forecast = _getForecastAtX(spot.x);
            String timeInfo = getTooltipDateText(spot);

            // Add relative time (e.g. "2 days from now")
            if (forecast != null) {
              final now = DateTime.now();
              final difference = forecast.validDateTime.difference(now);

              if (difference.inDays > 0) {
                final days = difference.inDays;
                timeInfo += '\n${days}d from now';
              } else if (difference.inDays < 0) {
                final days = -difference.inDays;
                timeInfo += '\n${days}d ago';
              } else {
                // Less than a day difference
                final hours = difference.inHours;
                if (hours > 0) {
                  timeInfo += '\nLater today';
                } else if (hours < 0) {
                  timeInfo += '\nEarlier today';
                } else {
                  timeInfo += '\nNow';
                }
              }
            }

            return LineTooltipItem(
              '${flowFormatter.format(spot.y)} ft³/s',
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              children: [
                TextSpan(
                  text: '\n$timeInfo',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
              ],
            );
          }).toList();
        },
      ),
      getTouchedSpotIndicator: (barData, spotIndexes) {
        return spotIndexes.map((spotIndex) {
          return TouchedSpotIndicatorData(
            FlLine(color: Colors.white, strokeWidth: 2, dashArray: [3, 3]),
            FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 6,
                  color: colorScheme.primary,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
          );
        }).toList();
      },
    );
  }
}
