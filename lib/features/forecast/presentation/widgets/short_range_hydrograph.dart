// lib/features/forecast/presentation/widgets/short_range_hydrograph.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rivr/features/forecast/domain/entities/forecast.dart';
import 'package:rivr/features/forecast/domain/entities/return_period.dart';
import 'package:rivr/features/forecast/presentation/widgets/hydrograph/base_hydrograph.dart';

class ShortRangeHydrograph extends BaseHydrograph {
  final List<Forecast> forecasts;

  const ShortRangeHydrograph({
    super.key,
    required super.reachId,
    required this.forecasts,
    super.returnPeriod,
  }) : super(title: 'Hourly Forecast (3-Day)');

  @override
  ShortRangeHydrographState createState() => ShortRangeHydrographState();
}

class ShortRangeHydrographState
    extends BaseHydrographState<ShortRangeHydrograph> {
  // Cache for normalized timestamps
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

    // Pre-calculate normalized times for better performance
    for (var forecast in sortedForecasts) {
      final hours =
          forecast.validDateTime.difference(_baseTime).inHours.toDouble();
      _normalizedTimeMap[forecast.validDateTime] = hours;
    }
  }

  @override
  List<FlSpot> generateSpots() {
    final List<FlSpot> spots = [];

    for (var forecast in widget.forecasts) {
      // Get normalized hours from base time
      final xValue = _normalizedTimeMap[forecast.validDateTime] ?? 0.0;
      spots.add(FlSpot(xValue, forecast.flow));
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
    if (widget.forecasts.isEmpty) return 72.0; // Default 3 days

    // Get maximum normalized time
    double maxX = widget.forecasts
        .map((f) => _normalizedTimeMap[f.validDateTime] ?? 0.0)
        .reduce((a, b) => a > b ? a : b);

    return maxX;
  }

  @override
  String _getTooltipDateText(LineBarSpot spot) {
    final forecast = _getForecastAtX(spot.x);
    if (forecast != null) {
      return DateFormat('MMM d, h:mm a').format(forecast.validDateTime);
    }

    // Fallback if forecast not found
    final time = _baseTime.add(Duration(hours: spot.x.toInt()));
    return DateFormat('MMM d, h:mm a').format(time);
  }

  @override
  AxisTitles _buildBottomTitles() {
    return AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 40,
        interval: 6, // Show every 6 hours
        getTitlesWidget: (value, meta) {
          if (value % 6 != 0) return const SizedBox.shrink();

          // Convert back to datetime
          final datetime = _baseTime.add(Duration(hours: value.toInt()));

          // Format based on hour
          String timeText;
          if (value == 0) {
            timeText = 'Now';
          } else if (datetime.hour == 0) {
            // At midnight, show the date
            timeText = DateFormat('MMM d').format(datetime);
          } else {
            // Otherwise show the hour
            timeText = DateFormat('ha').format(datetime).toLowerCase();
          }

          return Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              timeText,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  LineTouchData _buildTouchData() {
    // Enhance the base touch data with custom tooltip
    final baseTouch = super._buildTouchData();

    return LineTouchData(
      enabled: baseTouch.enabled,
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (spot) => Colors.blueGrey.withOpacity(0.8),
        tooltipRoundedRadius: 8,
        getTooltipItems: (List<LineBarSpot> lineBarsSpot) {
          return lineBarsSpot.map((spot) {
            final forecast = _getForecastAtX(spot.x);
            String timeInfo = _getTooltipDateText(spot);

            // Add relative time (e.g. "2 hours from now")
            if (forecast != null) {
              final now = DateTime.now();
              final difference = forecast.validDateTime.difference(now);

              if (difference.inHours > 0) {
                final hours = difference.inHours;
                timeInfo += '\n${hours}h from now';
              } else if (difference.inHours < 0) {
                final hours = -difference.inHours;
                timeInfo += '\n${hours}h ago';
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
      getTouchedSpotIndicator: baseTouch.getTouchedSpotIndicator,
      touchCallback: baseTouch.touchCallback,
    );
  }
}
