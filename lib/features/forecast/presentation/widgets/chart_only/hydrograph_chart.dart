// lib/features/forecast/presentation/widgets/chart_only/hydrograph_chart.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rivr/features/forecast/domain/entities/forecast.dart';
import 'package:rivr/features/forecast/domain/entities/forecast_types.dart';
import 'package:rivr/features/forecast/domain/entities/return_period.dart';

class HydrographChart extends StatefulWidget {
  final ForecastType forecastType;
  final List<Forecast> forecasts;
  final ReturnPeriod? returnPeriod;
  final Map<DateTime, Map<String, double>>? dailyStats;
  final Map<String, Map<String, double>>? longRangeFlows;

  const HydrographChart({
    super.key,
    required this.forecastType,
    required this.forecasts,
    this.returnPeriod,
    this.dailyStats,
    this.longRangeFlows,
  });

  @override
  State<HydrographChart> createState() => _HydrographChartState();
}

class _HydrographChartState extends State<HydrographChart> {
  // Variables for zoom/pan capabilities
  double _currentZoomLevel = 1.0;
  final double _minZoomLevel = 0.5;
  final double _maxZoomLevel = 5.0;
  late double _zoomStartLevel;
  double _xOffset = 0.0;

  // Chart data
  late List<FlSpot> _spots;
  late double _minX;
  late double _maxX;
  late double _minY;
  late double _maxY;

  // Formatters
  final NumberFormat flowFormatter = NumberFormat('#,##0.0');

  @override
  void initState() {
    super.initState();
    _zoomStartLevel = _currentZoomLevel;
    _generateChartData();
  }

  void _generateChartData() {
    _spots = _generateSpots();
    _minY = _calculateMinY();
    _maxY = _calculateMaxY();
    _minX = _calculateMinX();
    _maxX = _calculateMaxX();
  }

  // Reset zoom to original values
  void _resetZoom() {
    setState(() {
      _currentZoomLevel = 1.0;
      _xOffset = 0.0;
    });
  }

  // Generate chart spots based on forecast type
  List<FlSpot> _generateSpots() {
    final spots = <FlSpot>[];
    final sortedForecasts = List<Forecast>.from(widget.forecasts)
      ..sort((a, b) => a.validDateTime.compareTo(b.validDateTime));

    if (sortedForecasts.isEmpty) return spots;

    final baseTime = sortedForecasts.first.validDateTime;

    for (var forecast in sortedForecasts) {
      double x;
      switch (widget.forecastType) {
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

    // Add additional data points if available
    // (code to handle dailyStats or longRangeFlows)

    return spots;
  }

  // Calculate chart bounds
  double _calculateMinY() => 0.0; // Start from zero

  double _calculateMaxY() {
    if (widget.forecasts.isEmpty) return 100.0;

    double maxFlow = widget.forecasts
        .map((f) => f.flow)
        .reduce((a, b) => a > b ? a : b);

    // Consider return period thresholds
    if (widget.returnPeriod != null) {
      for (final year in [2, 5, 10, 25, 50, 100]) {
        final threshold = widget.returnPeriod!.getFlowForYear(year);
        if (threshold != null && threshold > maxFlow) {
          maxFlow = threshold;
        }
      }
    }

    return maxFlow * 1.2; // Add 20% padding
  }

  double _calculateMinX() => 0.0;

  double _calculateMaxX() {
    if (widget.forecasts.isEmpty) {
      // Default ranges if no data
      switch (widget.forecastType) {
        case ForecastType.shortRange:
          return 72.0; // 3 days in hours
        case ForecastType.mediumRange:
          return 10.0; // 10 days
        case ForecastType.longRange:
          return 8.0; // 8 weeks
      }
    }

    // Find the maximum x value based on the last forecast time
    final sortedForecasts = List<Forecast>.from(widget.forecasts)
      ..sort((a, b) => a.validDateTime.compareTo(b.validDateTime));

    if (sortedForecasts.isEmpty) return 10.0;

    final firstTime = sortedForecasts.first.validDateTime;
    final lastTime = sortedForecasts.last.validDateTime;

    switch (widget.forecastType) {
      case ForecastType.shortRange:
        return lastTime.difference(firstTime).inHours.toDouble();
      case ForecastType.mediumRange:
        return lastTime.difference(firstTime).inHours / 24;
      case ForecastType.longRange:
        return lastTime.difference(firstTime).inDays / 7;
    }
  }

  // Get horizontal lines for return periods
  List<HorizontalLine> _getReturnPeriodLines() {
    if (widget.returnPeriod == null) return [];

    final lines = <HorizontalLine>[];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    for (final year in [2, 5, 10, 25, 50, 100]) {
      final threshold = widget.returnPeriod!.getFlowForYear(year);
      if (threshold != null) {
        lines.add(
          HorizontalLine(
            y: threshold,
            color: _getReturnPeriodColor(year),
            strokeWidth: 2,
            dashArray: [5, 5],
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

  // Color for return period lines
  Color _getReturnPeriodColor(int year) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Transformations based on zoom/pan
    final transformedMinX = _minX + _xOffset;
    final transformedMaxX =
        _minX + (_maxX - _minX) / _currentZoomLevel + _xOffset;

    // Background color based on current theme
    final backgroundColor =
        isDark ? colorScheme.surface : colorScheme.surfaceContainerHighest;

    // Gradient colors defined based on current theme
    final gradientColors = [colorScheme.primary, colorScheme.secondary];

    if (_spots.isEmpty) {
      return Center(
        child: Text(
          'No data available to display',
          style: theme.textTheme.titleMedium,
        ),
      );
    }

    // Build the chart with gesture detection for zoom/pan
    return GestureDetector(
      onScaleStart: (details) {
        _zoomStartLevel = _currentZoomLevel;
      },
      onScaleUpdate: (details) {
        setState(() {
          // Update zoom level based on scale gesture
          _currentZoomLevel = (_zoomStartLevel * details.scale).clamp(
            _minZoomLevel,
            _maxZoomLevel,
          );

          // Handle horizontal panning
          if (details.pointerCount == 1) {
            _xOffset -= details.focalPointDelta.dx * 0.01 / _currentZoomLevel;

            // Constrain panning to valid range
            final visibleRange = (_maxX - _minX) / _currentZoomLevel;
            final maxOffset = _maxX - visibleRange - _minX;
            _xOffset = _xOffset.clamp(-maxOffset, 0);
          }
        });
      },
      onDoubleTap: _resetZoom,
      child: Stack(
        children: [
          Container(
            color: backgroundColor,
            padding: const EdgeInsets.fromLTRB(10, 16, 30, 80),
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
                                .map((color) => color.withOpacity(0.3))
                                .toList(),
                      ),
                    ),
                  ),
                ],
                extraLinesData: ExtraLinesData(
                  horizontalLines: _getReturnPeriodLines(),
                ),
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  drawVerticalLine: true,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color:
                          isDark
                              ? colorScheme.primary.withOpacity(0.15)
                              : colorScheme.primary.withOpacity(0.2),
                      strokeWidth: 1,
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color:
                          isDark
                              ? colorScheme.primary.withOpacity(0.25)
                              : colorScheme.primary.withOpacity(0.4),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: _buildTitlesData(isDark),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: colorScheme.outline),
                ),
                lineTouchData: _buildTouchData(isDark),
                minX: transformedMinX,
                maxX: transformedMaxX,
                minY: _minY,
                maxY: _maxY,
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
                  color: colorScheme.primaryContainer.withOpacity(0.8),
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

          // Zoom instructions
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.tertiary.withOpacity(0.7),
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
      ),
    );
  }

  // Build chart titles
  FlTitlesData _buildTitlesData(bool isDark) {
    // Implementation depends on forecast type
    // This would have custom implementations for each forecast type
    // ...

    // Simplified implementation for demonstration
    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          getTitlesWidget: (value, meta) {
            // Custom title widgets based on forecast type
            // ...
            return const SizedBox.shrink(); // Placeholder
          },
        ),
      ),
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
            return Text(
              value.toStringAsFixed(0),
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white : Colors.black87,
              ),
            );
          },
        ),
      ),
    );
  }

  // Build touch data for tooltips
  LineTouchData _buildTouchData(bool isDark) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LineTouchData(
      enabled: true,
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor:
            (spot) =>
                isDark
                    ? colorScheme.surfaceContainerHighest.withOpacity(0.8)
                    : Colors.blueGrey.withOpacity(0.8),
        tooltipRoundedRadius: 8,
        getTooltipItems: (spots) {
          return spots.map((spot) {
            return LineTooltipItem(
              '${flowFormatter.format(spot.y)} ft³/s',
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              children: [
                TextSpan(
                  text: '\nDate/time info would go here',
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
