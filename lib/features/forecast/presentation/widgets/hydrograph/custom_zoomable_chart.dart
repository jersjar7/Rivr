// lib/features/forecast/presentation/widgets/hydrograph/custom_zoomable_chart.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rivr/features/forecast/domain/entities/forecast.dart';
import 'package:rivr/features/forecast/domain/entities/forecast_types.dart';
import 'package:rivr/features/forecast/domain/entities/return_period.dart';

/// A custom zoomable chart component specifically for the expandable overlay view
class CustomZoomableChart extends StatefulWidget {
  final String reachId;
  final ForecastType forecastType;
  final List<Forecast> forecasts;
  final ReturnPeriod? returnPeriod;
  final Map<DateTime, Map<String, double>>? dailyStats;
  final Map<String, Map<String, double>>? longRangeFlows;

  const CustomZoomableChart({
    super.key,
    required this.reachId,
    required this.forecastType,
    required this.forecasts,
    this.returnPeriod,
    this.dailyStats,
    this.longRangeFlows,
  });

  @override
  State<CustomZoomableChart> createState() => _CustomZoomableChartState();
}

class _CustomZoomableChartState extends State<CustomZoomableChart> {
  // Variables for zoom/pan capabilities
  double _currentZoomLevel = 1.0;
  double _initialZoomLevel = 1.0;
  final double _minZoomLevel = 0.5; // Allow zooming out to see more data
  final double _maxZoomLevel = 5.0; // Allow zooming in up to 5x
  double _xOffset = 0.0; // Horizontal pan offset

  // Chart bounds
  double _baseMinX = 0.0;
  double _baseMaxX = 100.0;
  double _baseMinY = 0.0;
  double _baseMaxY = 100.0;

  // Data for chart
  late List<FlSpot> _spots;
  late final DateFormat dateFormatter = DateFormat('MMM d');
  late final DateFormat timeFormatter = DateFormat('h:mm a');
  late final NumberFormat flowFormatter = NumberFormat('#,##0.0');

  // Transformations based on zoom/pan
  double get _transformedMinX => _baseMinX + _xOffset;
  double get _transformedMaxX =>
      _baseMinX + (_baseMaxX - _baseMinX) / _currentZoomLevel + _xOffset;

  @override
  void initState() {
    super.initState();
    _initializeChartData();
  }

  void _initializeChartData() {
    // Generate spots based on forecast type
    _spots = _generateSpots();

    // Calculate min/max values
    _baseMinX = _getMinX();
    _baseMaxX = _getMaxX();
    _baseMinY = _getMinY();
    _baseMaxY = _getMaxY();
  }

  // Reset zoom to original values
  void _resetZoom() {
    setState(() {
      _currentZoomLevel = 1.0;
      _xOffset = 0.0;
    });
  }

  // Generate spots based on forecast type
  List<FlSpot> _generateSpots() {
    switch (widget.forecastType) {
      case ForecastType.shortRange:
        return _generateShortRangeSpots();
      case ForecastType.mediumRange:
        return _generateMediumRangeSpots();
      case ForecastType.longRange:
        return _generateLongRangeSpots();
    }
  }

  // Short range spots (hourly)
  List<FlSpot> _generateShortRangeSpots() {
    if (widget.forecasts.isEmpty) return [];

    // Sort forecasts by time
    final sortedForecasts = List<Forecast>.from(widget.forecasts)
      ..sort((a, b) => a.validDateTime.compareTo(b.validDateTime));

    // Use the first valid time as the base time for x-axis normalization
    final baseTime = sortedForecasts.first.validDateTime;

    final List<FlSpot> spots = [];
    for (var forecast in sortedForecasts) {
      // Get normalized hours from base time
      final hours =
          forecast.validDateTime.difference(baseTime).inHours.toDouble();
      spots.add(FlSpot(hours, forecast.flow));
    }

    return spots;
  }

  // Medium range spots (daily)
  List<FlSpot> _generateMediumRangeSpots() {
    if (widget.forecasts.isEmpty) return [];

    // Sort forecasts by time
    final sortedForecasts = List<Forecast>.from(widget.forecasts)
      ..sort((a, b) => a.validDateTime.compareTo(b.validDateTime));

    // Use the first valid time as the base time for x-axis normalization
    final baseTime = sortedForecasts.first.validDateTime;

    final List<FlSpot> spots = [];

    // Add regular forecast spots
    for (var forecast in sortedForecasts) {
      // Get normalized days from base time (in hours / 24)
      final days = forecast.validDateTime.difference(baseTime).inHours / 24;
      spots.add(FlSpot(days, forecast.flow));
    }

    // Add spots from dailyStats if available
    if (widget.dailyStats != null && widget.dailyStats!.isNotEmpty) {
      for (var entry in widget.dailyStats!.entries) {
        final date = entry.key;
        final stats = entry.value;

        // Use 'mean' or 'avg' flow value if available
        final flow = stats['mean'] ?? stats['avg'] ?? stats['flow'];

        if (flow != null) {
          final days = date.difference(baseTime).inHours / 24;
          spots.add(FlSpot(days, flow));
        }
      }
    }

    // Sort spots by x-value
    spots.sort((a, b) => a.x.compareTo(b.x));

    return spots;
  }

  // Long range spots (weekly)
  List<FlSpot> _generateLongRangeSpots() {
    if (widget.forecasts.isEmpty) return [];

    // Sort forecasts by time
    final sortedForecasts = List<Forecast>.from(widget.forecasts)
      ..sort((a, b) => a.validDateTime.compareTo(b.validDateTime));

    // Use the first valid time as the base time for x-axis normalization
    final baseTime = sortedForecasts.first.validDateTime;

    final List<FlSpot> spots = [];

    // Add regular forecast spots
    for (var forecast in sortedForecasts) {
      // Get normalized weeks from base time (in days / 7)
      final weeks = forecast.validDateTime.difference(baseTime).inDays / 7;
      spots.add(FlSpot(weeks, forecast.flow));
    }

    // Add spots from longRangeFlows if available
    if (widget.longRangeFlows != null && widget.longRangeFlows!.isNotEmpty) {
      for (var entry in widget.longRangeFlows!.entries) {
        try {
          final dateStr = entry.key;
          final flowData = entry.value;

          // Parse the date string
          final parts = dateStr.split('-');
          if (parts.length >= 3) {
            final date = DateTime(
              int.parse(parts[0]),
              int.parse(parts[1]),
              int.parse(parts[2]),
            );

            // Use 'mean' or 'avg' flow value if available
            final flow =
                flowData['mean'] ?? flowData['avg'] ?? flowData['flow'];

            if (flow != null) {
              final weeks = date.difference(baseTime).inDays / 7;
              spots.add(FlSpot(weeks, flow));
            }
          }
        } catch (e) {
          // Skip entries that can't be parsed
          continue;
        }
      }
    }

    // Sort spots by x-value
    spots.sort((a, b) => a.x.compareTo(b.x));

    return spots;
  }

  double _getMinY() {
    // Start from zero for a clearer representation
    return 0.0;
  }

  double _getMaxY() {
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

  double _getMinX() {
    return 0.0;
  }

  double _getMaxX() {
    switch (widget.forecastType) {
      case ForecastType.shortRange:
        return widget.forecasts.isEmpty
            ? 72.0
            : _spots.map((s) => s.x).reduce((a, b) => a > b ? a : b);
      case ForecastType.mediumRange:
        return widget.forecasts.isEmpty
            ? 10.0
            : _spots.map((s) => s.x).reduce((a, b) => a > b ? a : b);
      case ForecastType.longRange:
        return widget.forecasts.isEmpty
            ? 8.0
            : _spots.map((s) => s.x).reduce((a, b) => a > b ? a : b);
    }
  }

  // Get horizontal lines for return periods
  List<HorizontalLine> _getReturnPeriodLines() {
    if (widget.returnPeriod == null) {
      return [];
    }

    final List<HorizontalLine> lines = [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    for (final year in [2, 5, 10, 25, 50, 100]) {
      final threshold = widget.returnPeriod!.getFlowForYear(year);

      if (threshold != null) {
        lines.add(
          HorizontalLine(
            y: threshold,
            color: _getReturnPeriodColor(year),
            strokeWidth: 2,
            dashArray: [5, 5], // Create dashed line
            label: HorizontalLineLabel(
              show: true,
              alignment: Alignment.topRight,
              padding: const EdgeInsets.only(right: 5, bottom: 5),
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
              labelResolver: (line) => '$year-yr',
            ),
          ),
        );
      }
    }

    return lines;
  }

  // Helper method to get color for return period
  Color _getReturnPeriodColor(int year) {
    // These colors should be distinguishable in both light and dark modes
    switch (year) {
      case 2:
        return Colors.yellow;
      case 5:
        return Colors.orange;
      case 10:
        return Colors.deepOrange;
      case 25:
        return Colors.redAccent;
      case 50:
        return const Color.fromARGB(255, 187, 42, 212);
      case 100:
        return const Color.fromARGB(255, 130, 85, 255);
      default:
        return Colors.grey;
    }
  }

  // Get tooltip text based on forecast type
  String _getTooltipDateText(LineBarSpot spot) {
    switch (widget.forecastType) {
      case ForecastType.shortRange:
        // For hourly forecasts, show date and time
        final sortedForecasts = List<Forecast>.from(widget.forecasts)
          ..sort((a, b) => a.validDateTime.compareTo(b.validDateTime));
        final baseTime = sortedForecasts.first.validDateTime;
        final time = baseTime.add(Duration(hours: spot.x.toInt()));
        return DateFormat('MMM d, h:mm a').format(time);

      case ForecastType.mediumRange:
        // For daily forecasts, show day of week and date
        final sortedForecasts = List<Forecast>.from(widget.forecasts)
          ..sort((a, b) => a.validDateTime.compareTo(b.validDateTime));
        final baseTime = sortedForecasts.first.validDateTime;
        final time = baseTime.add(Duration(hours: (spot.x * 24).toInt()));
        return DateFormat('EEE, MMM d').format(time);

      case ForecastType.longRange:
        // For weekly forecasts, show date range
        final sortedForecasts = List<Forecast>.from(widget.forecasts)
          ..sort((a, b) => a.validDateTime.compareTo(b.validDateTime));
        final baseTime = sortedForecasts.first.validDateTime;
        final time = baseTime.add(Duration(days: (spot.x * 7).toInt()));
        final weekEnd = time.add(const Duration(days: 6));
        return '${DateFormat('MMM d').format(time)} - ${DateFormat('MMM d').format(weekEnd)}';
    }
  }

  // Build bottom axis titles based on forecast type
  FlTitlesData _buildTitlesData(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;

    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        axisNameWidget: Text(
          'ft³/s',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        axisNameSize: 30,
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 50,
          getTitlesWidget: (value, meta) {
            if (value == _baseMaxY || value < 0) {
              return Container();
            }
            return Padding(
              padding: const EdgeInsets.only(right: 5),
              child: Text(
                value.toStringAsFixed(0),
                style: TextStyle(fontSize: 12, color: textColor),
                textAlign: TextAlign.right,
              ),
            );
          },
        ),
      ),
    );
  }

  // Build touch tooltip data
  LineTouchData _buildTouchData(bool isDark) {
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
            return LineTooltipItem(
              '${flowFormatter.format(spot.y)} ft³/s',
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              children: [
                TextSpan(
                  text: '\n${_getTooltipDateText(spot)}',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor =
        isDark ? colorScheme.surface : colorScheme.surfaceContainerHighest;

    if (_spots.isEmpty) {
      return Center(
        child: Text(
          'No data available to display',
          style: theme.textTheme.titleMedium,
        ),
      );
    }

    // Get chart elements
    final horizontalLines = _getReturnPeriodLines();
    final touchData = _buildTouchData(isDark);

    // Gradient colors
    final gradientColors = [colorScheme.primary, colorScheme.secondary];

    // Chart padding
    final EdgeInsets chartPadding = const EdgeInsets.only(
      top: 16,
      right: 30,
      bottom: 80,
      left: 10,
    );

    // Create the chart with gesture detection for zoom/pan
    return Stack(
      children: [
        // The chart with gesture detector for zooming
        GestureDetector(
          onScaleStart: (details) {
            _initialZoomLevel = _currentZoomLevel;
          },
          onScaleUpdate: (details) {
            setState(() {
              // Update zoom level based on scale gesture
              _currentZoomLevel = (_initialZoomLevel * details.scale).clamp(
                _minZoomLevel,
                _maxZoomLevel,
              );

              // Handle horizontal panning
              if (details.pointerCount == 1) {
                // Only apply horizontal pan for single finger gestures
                _xOffset -=
                    details.focalPointDelta.dx * 0.01 / _currentZoomLevel;

                // Constrain panning to valid range
                final visibleRange =
                    (_baseMaxX - _baseMinX) / _currentZoomLevel;
                final maxOffset = _baseMaxX - visibleRange - _baseMinX;
                _xOffset = _xOffset.clamp(-maxOffset, 0);
              }
            });
          },
          onDoubleTap: _resetZoom, // Reset zoom on double tap
          child: Container(
            color: backgroundColor,
            padding: chartPadding,
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: _spots,
                    isCurved: true,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    gradient: LinearGradient(colors: gradientColors),
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors:
                            gradientColors
                                .map((color) => color.withValues(alpha: 0.3))
                                .toList(),
                      ),
                    ),
                  ),
                ],
                extraLinesData: ExtraLinesData(
                  horizontalLines: horizontalLines,
                ),
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  drawVerticalLine: true,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color:
                          isDark
                              ? colorScheme.primary.withValues(alpha: 0.15)
                              : colorScheme.primary.withValues(alpha: 0.2),
                      strokeWidth: 1,
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color:
                          isDark
                              ? colorScheme.primary.withValues(alpha: 0.25)
                              : colorScheme.primary.withValues(alpha: 0.4),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: _buildTitlesData(isDark),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: colorScheme.outline),
                ),
                lineTouchData: touchData,
                // Apply transformed X bounds based on zoom and pan
                minX: _transformedMinX,
                maxX: _transformedMaxX,
                minY: _baseMinY,
                maxY: _baseMaxY,
              ),
            ),
          ),
        ),

        // Zoom indicator
        if (_currentZoomLevel > 1.05)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_currentZoomLevel.toStringAsFixed(1)}x',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),

        // Zoom instructions hint
        Positioned(
          bottom: 12,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.tertiary.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Pinch to zoom • Double tap to reset',
                style: TextStyle(
                  color: colorScheme.onTertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
