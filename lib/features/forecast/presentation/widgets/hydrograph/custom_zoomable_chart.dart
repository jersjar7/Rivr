// lib/features/forecast/presentation/widgets/hydrograph/custom_zoomable_chart.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:rivr/features/forecast/domain/entities/forecast.dart';
import 'package:rivr/features/forecast/domain/entities/forecast_types.dart';
import 'package:rivr/features/forecast/domain/entities/return_period.dart';
import 'package:rivr/features/forecast/presentation/widgets/short_range_hydrograph.dart';
import 'package:rivr/features/forecast/presentation/widgets/medium_range_hydrograph.dart';
import 'package:rivr/features/forecast/presentation/widgets/long_range_hydrograph.dart';
import 'package:rivr/features/forecast/presentation/widgets/hydrograph/base_hydrograph.dart';

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

  // Chart bounds (will be initialized when we create the state objects)
  double _baseMinX = 0.0;
  double _baseMaxX = 100.0;
  double _baseMinY = 0.0;
  double _baseMaxY = 100.0;

  // Hydrograph state (will be initialized in initState)
  late BaseHydrographState _hydrographState;
  late List<FlSpot> _spots;
  late Color _backgroundColor;

  // Transformations based on zoom/pan
  double get _transformedMinX => _baseMinX + _xOffset;
  double get _transformedMaxX =>
      _baseMinX + (_baseMaxX - _baseMinX) / _currentZoomLevel + _xOffset;

  @override
  void initState() {
    super.initState();
    _initializeHydrographState();
  }

  void _initializeHydrographState() {
    // Create the appropriate hydrograph state based on forecast type
    switch (widget.forecastType) {
      case ForecastType.shortRange:
        final hydrographWidget = ShortRangeHydrograph(
          reachId: widget.reachId,
          forecasts: widget.forecasts,
          returnPeriod: widget.returnPeriod,
        );
        _hydrographState = ShortRangeHydrographState();
        (_hydrographState as dynamic).widget = hydrographWidget;
        break;

      case ForecastType.mediumRange:
        final hydrographWidget = MediumRangeHydrograph(
          reachId: widget.reachId,
          forecasts: widget.forecasts,
          dailyStats: widget.dailyStats,
          returnPeriod: widget.returnPeriod,
        );
        _hydrographState = MediumRangeHydrographState();
        (_hydrographState as dynamic).widget = hydrographWidget;
        break;

      case ForecastType.longRange:
        final hydrographWidget = LongRangeHydrograph(
          reachId: widget.reachId,
          forecasts: widget.forecasts,
          longRangeFlows: widget.longRangeFlows,
          returnPeriod: widget.returnPeriod,
        );
        _hydrographState = LongRangeHydrographState();
        (_hydrographState as dynamic).widget = hydrographWidget;
        break;
    }

    // Set context and initialize state
    (_hydrographState as dynamic).context = context;
    _hydrographState.initState();

    // Get initial data
    _spots = _hydrographState.generateSpots();
    _baseMinX = _hydrographState.getMinX();
    _baseMaxX = _hydrographState.getMaxX();
    _baseMinY = _hydrographState.getMinY();
    _baseMaxY = _hydrographState.getMaxY();

    // Background color
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    _backgroundColor =
        isDark ? colorScheme.surface : colorScheme.surfaceContainerHighest;
  }

  // Reset zoom to original values
  void _resetZoom() {
    setState(() {
      _currentZoomLevel = 1.0;
      _xOffset = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    if (_spots.isEmpty) {
      return Center(
        child: Text(
          'No data available to display',
          style: theme.textTheme.titleMedium,
        ),
      );
    }

    // Get chart elements from the hydrograph state
    final horizontalLines = _hydrographState.getReturnPeriodLines();
    final titlesData = _hydrographState.buildTitlesData(isDark);
    final touchData = _hydrographState.buildTouchData(isDark);
    final gradientColors = _hydrographState.gradientColors;

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
            color: _backgroundColor,
            padding: _hydrographState.chartPadding,
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
                titlesData: titlesData,
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
