// lib/features/forecast/presentation/widgets/chart_only/hydrograph_chart.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rivr/core/formatters/flow_value_formatter.dart';
import 'package:rivr/core/models/flow_unit.dart';
import 'package:rivr/core/services/flow_units_service.dart';
import 'package:rivr/features/forecast/domain/entities/forecast.dart';
import 'package:rivr/features/forecast/domain/entities/forecast_types.dart';
import 'package:rivr/features/forecast/domain/entities/return_period.dart';
import 'package:rivr/features/forecast/utils/format_large_number.dart';

class HydrographChart extends StatefulWidget {
  final ForecastType forecastType;
  final List<Forecast> forecasts;
  final ReturnPeriod? returnPeriod;
  final Map<DateTime, Map<String, double>>? dailyStats;
  final Map<String, Map<String, double>>? longRangeFlows;
  final FlowUnit sourceUnit; // Add source unit parameter

  const HydrographChart({
    super.key,
    required this.forecastType,
    required this.forecasts,
    this.returnPeriod,
    this.dailyStats,
    this.longRangeFlows,
    this.sourceUnit = FlowUnit.cfs, // Default to CFS as source unit
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

  // Flow unit services
  late final FlowUnitsService _flowUnitsService;
  late final FlowValueFormatter _flowValueFormatter;

  @override
  void initState() {
    super.initState();
    _zoomStartLevel = _currentZoomLevel;

    // Initialize flow unit services
    _flowUnitsService = Provider.of<FlowUnitsService>(context, listen: false);
    _flowValueFormatter = Provider.of<FlowValueFormatter>(
      context,
      listen: false,
    );

    // Listen for unit changes
    _flowUnitsService.addListener(_onUnitChanged);

    _generateChartData();
  }

  @override
  void dispose() {
    // Remove listener when widget is disposed
    _flowUnitsService.removeListener(_onUnitChanged);
    super.dispose();
  }

  // Handle unit changes
  void _onUnitChanged() {
    if (mounted) {
      // Regenerate chart data with the new unit
      _generateChartData();
      setState(() {}); // Trigger rebuild
    }
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

      // Convert flow from source unit to preferred unit if needed
      double flowValue = forecast.flow;
      if (widget.sourceUnit != _flowUnitsService.preferredUnit) {
        flowValue = _flowUnitsService.convertToPreferredUnit(
          flowValue,
          widget.sourceUnit,
        );
      }

      spots.add(FlSpot(x, flowValue));
    }

    // Add additional data points from dailyStats if available
    if (widget.forecastType == ForecastType.mediumRange &&
        widget.dailyStats != null) {
      _addDailyStatsSpots(spots, baseTime);
    }

    // Add additional data points from longRangeFlows if available
    if (widget.forecastType == ForecastType.longRange &&
        widget.longRangeFlows != null) {
      _addLongRangeSpots(spots, baseTime);
    }

    return spots;
  }

  // Add spots from daily stats with proper unit conversion
  void _addDailyStatsSpots(List<FlSpot> spots, DateTime baseTime) {
    for (var entry in widget.dailyStats!.entries) {
      final date = entry.key;
      final stats = entry.value;

      // Use 'mean' or 'avg' flow value if available
      final flow = stats['mean'] ?? stats['avg'] ?? stats['flow'];

      if (flow != null) {
        // Calculate x based on days difference
        final days = date.difference(baseTime).inHours / 24;

        // Convert flow if needed
        double convertedFlow = flow;
        if (widget.sourceUnit != _flowUnitsService.preferredUnit) {
          convertedFlow = _flowUnitsService.convertToPreferredUnit(
            flow,
            widget.sourceUnit,
          );
        }

        spots.add(FlSpot(days, convertedFlow));
      }
    }
  }

  // Add spots from long range flows with proper unit conversion
  void _addLongRangeSpots(List<FlSpot> spots, DateTime baseTime) {
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
          final flow = flowData['mean'] ?? flowData['avg'] ?? flowData['flow'];

          if (flow != null) {
            // Calculate x in weeks
            final weeks = date.difference(baseTime).inDays / 7;

            // Convert flow if needed
            double convertedFlow = flow;
            if (widget.sourceUnit != _flowUnitsService.preferredUnit) {
              convertedFlow = _flowUnitsService.convertToPreferredUnit(
                flow,
                widget.sourceUnit,
              );
            }

            spots.add(FlSpot(weeks, convertedFlow));
          }
        }
      } catch (e) {
        // Skip entries that can't be parsed
        continue;
      }
    }
  }

  // Find forecast at specific normalized time (x-value)
  Forecast? _getForecastAtX(double x) {
    // Find closest forecast to the given x value
    Forecast? closest;
    double minDifference = double.infinity;

    for (var forecast in widget.forecasts) {
      double normalizedTime;
      final baseTime = widget.forecasts.first.validDateTime;

      switch (widget.forecastType) {
        case ForecastType.shortRange:
          normalizedTime =
              forecast.validDateTime.difference(baseTime).inHours.toDouble();
          break;
        case ForecastType.mediumRange:
          normalizedTime =
              forecast.validDateTime.difference(baseTime).inHours / 24;
          break;
        case ForecastType.longRange:
          normalizedTime =
              forecast.validDateTime.difference(baseTime).inDays / 7;
          break;
      }

      final difference = (normalizedTime - x).abs();

      if (difference < minDifference) {
        minDifference = difference;
        closest = forecast;
      }
    }

    return closest;
  }

  double _calculateMinY() {
    // Start from zero for a clearer representation
    return 0.0;
  }

  double _calculateMaxY() {
    if (widget.forecasts.isEmpty) return 100.0;

    // Find max flow and add 20% for padding - convert to preferred unit first
    double maxFlow = 0;

    for (var forecast in widget.forecasts) {
      double flowValue = forecast.flow;
      if (widget.sourceUnit != _flowUnitsService.preferredUnit) {
        flowValue = _flowUnitsService.convertToPreferredUnit(
          flowValue,
          widget.sourceUnit,
        );
      }

      if (flowValue > maxFlow) {
        maxFlow = flowValue;
      }
    }

    // Also check dailyStats max values
    if (widget.dailyStats != null) {
      for (var entry in widget.dailyStats!.entries) {
        final stats = entry.value;
        final maxDaily = stats['max'] ?? stats['maxFlow'];

        if (maxDaily != null) {
          double convertedMaxDaily = maxDaily;
          if (widget.sourceUnit != _flowUnitsService.preferredUnit) {
            convertedMaxDaily = _flowUnitsService.convertToPreferredUnit(
              maxDaily,
              widget.sourceUnit,
            );
          }

          if (convertedMaxDaily > maxFlow) {
            maxFlow = convertedMaxDaily;
          }
        }
      }
    }

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

  double _calculateMinX() {
    return 0.0;
  }

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
                                .map((color) => color.withValues(alpha: 0.3))
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
                  color: colorScheme.tertiary.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                // child: Text(
                //   'Pinch to zoom • Double tap to reset',
                //   style: TextStyle(
                //     color: colorScheme.onTertiary,
                //     fontSize: 12,
                //     fontWeight: FontWeight.bold,
                //   ),
                // ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build chart titles
  FlTitlesData _buildTitlesData(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;

    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          getTitlesWidget: (value, meta) {
            // Custom title widgets based on forecast type
            return _getBottomTitleWidget(value, isDark);
          },
        ),
      ),
      leftTitles: AxisTitles(
        axisNameWidget: Text(
          _flowUnitsService.unitLabel, // Use current unit label from service
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
            if (value == _maxY || value < 0) {
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
    );
  }

  // Generate bottom title widget based on forecast type
  Widget _getBottomTitleWidget(double value, bool isDark) {
    if (widget.forecasts.isEmpty) {
      return const SizedBox.shrink();
    }

    final textColor = isDark ? Colors.white : Colors.black87;
    final baseTime = widget.forecasts.first.validDateTime;

    switch (widget.forecastType) {
      case ForecastType.shortRange:
        // For hourly data
        final time = baseTime.add(Duration(hours: value.toInt()));

        // Format based on hour
        if (value == 0) {
          return _buildTitleText('Now', textColor);
        } else if (time.hour == 0) {
          // At midnight, show the date
          return _buildTitleText(DateFormat('MMM d').format(time), textColor);
        } else {
          // Show the hour
          return _buildTitleText(
            DateFormat('ha').format(time).toLowerCase(),
            textColor,
          );
        }

      case ForecastType.mediumRange:
        // For daily data
        final time = baseTime.add(Duration(hours: (value * 24).toInt()));

        // Format based on day
        if (value == 0) {
          return _buildTitleText('Today', textColor);
        } else if (value == 1) {
          return _buildTitleText('Tmrw', textColor);
        } else {
          // Show day of week and date
          return _buildTitleText(DateFormat('E\nM/d').format(time), textColor);
        }

      case ForecastType.longRange:
        // For weekly data
        final time = baseTime.add(Duration(days: (value * 7).toInt()));

        // Format based on week
        if (value == 0) {
          return _buildTitleText('This\nWeek', textColor);
        } else if (value == 1) {
          return _buildTitleText('Next\nWeek', textColor);
        } else {
          // Show month and week of month
          final weekOfMonth = (time.day / 7).ceil();
          return _buildTitleText(
            '${DateFormat('MMM').format(time)}\nWk $weekOfMonth',
            textColor,
          );
        }
    }
  }

  // Helper to build the title text widget
  Widget _buildTitleText(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
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
                    ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.8)
                    : Colors.blueGrey.withValues(alpha: 0.8),
        tooltipRoundedRadius: 8,
        getTooltipItems: (List<LineBarSpot> lineBarsSpot) {
          return lineBarsSpot.map((spot) {
            // Get the forecast that corresponds to this spot
            final forecast = _getForecastAtX(spot.x);

            // Format the flow value using the formatter (automatically uses correct units)
            final flowText = _flowValueFormatter.format(spot.y);

            // Get date/time information
            String timeInfo = _getTimeInfoText(spot, forecast);

            return LineTooltipItem(
              flowText, // Flow with proper unit
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

  // Helper to format time information for tooltips
  String _getTimeInfoText(LineBarSpot spot, Forecast? forecast) {
    if (forecast == null) {
      // Fallback if forecast not found - estimate time based on x value
      final baseTime = widget.forecasts.first.validDateTime;

      switch (widget.forecastType) {
        case ForecastType.shortRange:
          final time = baseTime.add(Duration(hours: spot.x.toInt()));
          return DateFormat('MMM d, h:mm a').format(time);

        case ForecastType.mediumRange:
          final time = baseTime.add(Duration(hours: (spot.x * 24).toInt()));
          return DateFormat('EEE, MMM d').format(time);

        case ForecastType.longRange:
          final time = baseTime.add(Duration(days: (spot.x * 7).toInt()));
          final weekEnd = time.add(const Duration(days: 6));
          return '${DateFormat('MMM d').format(time)} - ${DateFormat('MMM d').format(weekEnd)}';
      }
    }

    // Use actual forecast time
    final forecastTime = forecast.validDateTime;
    final now = DateTime.now();

    switch (widget.forecastType) {
      case ForecastType.shortRange:
        final timeStr = DateFormat('MMM d, h:mm a').format(forecastTime);
        // Add relative time
        final difference = forecastTime.difference(now);

        if (difference.inHours > 0) {
          return '$timeStr (in ${difference.inHours}h)';
        } else if (difference.inHours < 0) {
          return '$timeStr (${-difference.inHours}h ago)';
        } else {
          return '$timeStr (now)';
        }

      case ForecastType.mediumRange:
        final timeStr = DateFormat('EEE, MMM d').format(forecastTime);
        // Add relative time
        final difference = forecastTime.difference(now);

        if (difference.inDays > 0) {
          return '$timeStr (in ${difference.inDays}d)';
        } else if (difference.inDays < 0) {
          return '$timeStr (${-difference.inDays}d ago)';
        } else {
          return '$timeStr (today)';
        }

      case ForecastType.longRange:
        // Calculate week start/end
        final weekStart = DateTime(
          forecastTime.year,
          forecastTime.month,
          forecastTime.day,
        ).subtract(Duration(days: forecastTime.weekday % 7));
        final weekEnd = weekStart.add(const Duration(days: 6));
        final timeStr =
            '${DateFormat('MMM d').format(weekStart)} - ${DateFormat('MMM d').format(weekEnd)}';

        // Add relative weeks
        final difference = weekStart.difference(now);
        final weeks = (difference.inDays / 7).round();

        if (weeks > 0) {
          return '$timeStr (in $weeks weeks)';
        } else if (weeks < 0) {
          return '$timeStr (${-weeks} weeks ago)';
        } else {
          return '$timeStr (this week)';
        }
    }
  }
}
