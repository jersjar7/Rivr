// lib/features/forecast/presentation/widgets/hydrograph/base_hydrograph.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rivr/core/formatters/flow_value_formatter.dart';
import 'package:rivr/core/services/flow_units_service.dart';
import 'package:rivr/features/forecast/domain/entities/return_period.dart';
import 'package:rivr/features/forecast/utils/format_large_number.dart';

abstract class BaseHydrograph extends StatefulWidget {
  final String reachId;
  final ReturnPeriod? returnPeriod;
  final String title;

  const BaseHydrograph({
    super.key,
    required this.reachId,
    required this.title,
    this.returnPeriod,
  });

  @override
  BaseHydrographState createState();
}

abstract class BaseHydrographState<T extends BaseHydrograph> extends State<T> {
  // Formatters
  final DateFormat dateFormatter = DateFormat('MMM d');
  final DateFormat timeFormatter = DateFormat('h:mm a');
  final NumberFormat flowFormatter = NumberFormat('#,##0.0');

  // Chart padding
  final EdgeInsets chartPadding = const EdgeInsets.only(
    top: 16,
    right: 30,
    bottom: 80,
    left: 10,
  );

  // Variables for zoom/pan capabilities
  double _currentZoomLevel = 1.0;
  final double _minZoomLevel = 0.5; // Allow zooming out to see more data
  final double _maxZoomLevel = 5.0; // Allow zooming in up to 5x
  late double _zoomStartLevel;
  double _xOffset = 0.0; // Horizontal pan offset
  double _baseMinX = 0.0; // Original min X value
  double _baseMaxX = 0.0; // Original max X value
  late double _baseMinY; // Original min Y value - using late
  late double _baseMaxY; // Original max Y value - using late
  bool _initialBoundsSet = false; // Track if we've initialized bounds

  // Transformations based on zoom/pan
  double get _transformedMinX => _baseMinX + _xOffset;
  double get _transformedMaxX =>
      _baseMinX + (_baseMaxX - _baseMinX) / _currentZoomLevel + _xOffset;

  late final FlowUnitsService _flowUnitsService;
  late final FlowValueFormatter _flowFormatter;

  // Gradient colors defined based on current theme
  List<Color> get gradientColors {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return [colorScheme.primary, colorScheme.secondary];
  }

  // Background color based on current theme
  Color get chartBackgroundColor {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return isDark ? colorScheme.surface : colorScheme.surfaceContainerHighest;
  }

  // Abstract methods that must be implemented by subclasses
  List<FlSpot> generateSpots();
  double getMinY();
  double getMaxY();
  double getMinX();
  double getMaxX();

  // Initialize zoom-related values
  void _initializeZoomBounds() {
    if (!_initialBoundsSet) {
      _baseMinX = getMinX();
      _baseMaxX = getMaxX();
      _baseMinY = getMinY();
      _baseMaxY = getMaxY();
      _initialBoundsSet = true;
    }
  }

  @override
  void initState() {
    super.initState();
    _zoomStartLevel = _currentZoomLevel;

    // Initialize formatter and units service
    _flowUnitsService = Provider.of<FlowUnitsService>(context, listen: false);
    _flowFormatter = Provider.of<FlowValueFormatter>(context, listen: false);
  }

  // Reset zoom to original values
  void _resetZoom() {
    setState(() {
      _currentZoomLevel = 1.0;
      _xOffset = 0.0;
    });
  }

  // Return period horizontal lines
  List<HorizontalLine> getReturnPeriodLines() {
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

  // Helper to determine appropriate space for y-axis labels
  double getReservedSizeForYAxis(double maxValue) {
    int numDigits = maxValue.toInt().toString().length;

    switch (numDigits) {
      case 1:
        return 25;
      case 2:
        return 30;
      case 3:
        return 35;
      case 4:
        return 40;
      case 5:
        return 45;
      case 6:
        return 55;
      case 7:
        return 60;
      case 8:
        return 65;
      default:
        return 35;
    }
  }

  @override
  Widget build(BuildContext context) {
    final spots = generateSpots();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    if (spots.isEmpty) {
      return buildNoDataView();
    }

    // Initialize zoom bounds on first build
    _initializeZoomBounds();

    // Get return period lines
    final horizontalLines = getReturnPeriodLines();

    // Create the chart with gesture detection for zoom/pan
    final chart = GestureDetector(
      onScaleStart: (details) {
        // Store the initial zoom level when gesture starts
        // store the current zoom so we can multiply by the gesture scale
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
            // Only apply horizontal pan for single finger gestures
            _xOffset -= details.focalPointDelta.dx * 0.01 / _currentZoomLevel;

            // Constrain panning to valid range
            final visibleRange = (_baseMaxX - _baseMinX) / _currentZoomLevel;
            final maxOffset = _baseMaxX - visibleRange - _baseMinX;
            _xOffset = _xOffset.clamp(-maxOffset, 0);
          }
        });
      },
      onDoubleTap: _resetZoom, // Reset zoom on double tap
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: spots,
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
          extraLinesData: ExtraLinesData(horizontalLines: horizontalLines),
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
          titlesData: buildTitlesData(isDark),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: colorScheme.outline),
          ),
          lineTouchData: buildTouchData(isDark),
          // Apply transformed X bounds based on zoom and pan
          minX: _transformedMinX,
          maxX: _transformedMaxX,
          minY: _baseMinY,
          maxY: _baseMaxY,
        ),
      ),
    );

    // Build the complete UI with scaffold and zoom indicator
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: chartBackgroundColor,
        elevation: 0,
        actions: [
          // Add a reset zoom button
          IconButton(
            icon: const Icon(Icons.zoom_out_map),
            onPressed: _resetZoom,
            tooltip: 'Reset zoom',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Chart background
          Container(
            color: chartBackgroundColor,
            child: Padding(padding: chartPadding, child: chart),
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

          // Zoom instructions hint - show briefly or on first view
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
      ),
    );
  }

  // Implement default touch data behavior - can be overridden
  LineTouchData buildTouchData([bool isDark = false]) {
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
        getTooltipItems: (List<LineBarSpot> lineBarsSpot) {
          return lineBarsSpot.map((spot) {
            return LineTooltipItem(
              _flowFormatter.format(spot.y), // Use formatter here
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              children: [
                TextSpan(
                  text: '\n${getTooltipDateText(spot)}',
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

  // Implement default titles data - can be overridden
  FlTitlesData buildTitlesData([bool isDark = false]) {
    final textColor = isDark ? Colors.white : Colors.black87;

    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: buildBottomTitles(),
      leftTitles: AxisTitles(
        axisNameWidget: Text(
          _flowUnitsService.unitLabel, // Use unit label from service
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        axisNameSize: 30,
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: getReservedSizeForYAxis(_baseMaxY),
          getTitlesWidget: (value, meta) {
            if (value == _baseMaxY || value < 0) {
              return Container();
            }
            return Padding(
              padding: const EdgeInsets.only(right: 5),
              child: Text(
                formatLargeNumber(value),
                style: TextStyle(fontSize: 12, color: textColor),
                textAlign: TextAlign.right,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
        ),
      ),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  // To be implemented by subclasses
  AxisTitles buildBottomTitles() {
    return const AxisTitles(sideTitles: SideTitles(showTitles: false));
  }

  // To be implemented by subclasses
  String getTooltipDateText(LineBarSpot spot) {
    return 'Date/time not available';
  }

  // No data view
  Widget buildNoDataView() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart,
              size: 48,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No data available to display',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try again later or select a different time range',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
