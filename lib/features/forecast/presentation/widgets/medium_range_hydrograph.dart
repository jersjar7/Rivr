// lib/features/forecast/presentation/widgets/medium_range_hydrograph.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rivr/features/forecast/domain/entities/forecast.dart';
import 'package:rivr/features/forecast/domain/entities/return_period.dart';
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
  }) : super(title: '9-Day Forecast');

  @override
  MediumRangeHydrographState createState() => MediumRangeHydrographState();
}

class MediumRangeHydrographState
    extends BaseHydrographState<MediumRangeHydrograph> {
  // Track day-based indices for better x-axis alignment
  late final Map<DateTime, int> _dayIndices = {};
  late final List<DateTime> _uniqueDays = [];

  // Range band spots for min/max flow
  List<FlSpot> _minSpots = [];
  List<FlSpot> _maxSpots = [];

  @override
  void initState() {
    super.initState();

    // Group forecasts by day to calculate daily stats
    final Map<DateTime, List<Forecast>> forecastsByDay = {};

    for (var forecast in widget.forecasts) {
      final date = DateTime(
        forecast.validDateTime.year,
        forecast.validDateTime.month,
        forecast.validDateTime.day,
      );

      forecastsByDay.putIfAbsent(date, () => []).add(forecast);
    }

    // Sort days chronologically
    _uniqueDays.addAll(forecastsByDay.keys);
    _uniqueDays.sort();

    // Assign indices to days
    for (int i = 0; i < _uniqueDays.length; i++) {
      _dayIndices[_uniqueDays[i]] = i;
    }

    // Process daily statistics
    _processRangeBands();
  }

  void _processRangeBands() {
    _minSpots = [];
    _maxSpots = [];

    // If daily stats are provided directly, use them
    if (widget.dailyStats != null) {
      final stats = widget.dailyStats!;
      for (var date in stats.keys) {
        final dayIndex = _getDayIndex(date);
        if (stats[date]!.containsKey('min')) {
          _minSpots.add(FlSpot(dayIndex.toDouble(), stats[date]!['min']!));
        }
        if (stats[date]!.containsKey('max')) {
          _maxSpots.add(FlSpot(dayIndex.toDouble(), stats[date]!['max']!));
        }
      }
      return;
    }

    // Otherwise calculate from raw forecasts
    final Map<int, double> dayMinFlow = {};
    final Map<int, double> dayMaxFlow = {};

    for (var forecast in widget.forecasts) {
      final day = DateTime(
        forecast.validDateTime.year,
        forecast.validDateTime.month,
        forecast.validDateTime.day,
      );

      final dayIndex = _getDayIndex(day);

      // Update min/max flows
      if (!dayMinFlow.containsKey(dayIndex) ||
          forecast.flow < dayMinFlow[dayIndex]!) {
        dayMinFlow[dayIndex] = forecast.flow;
      }

      if (!dayMaxFlow.containsKey(dayIndex) ||
          forecast.flow > dayMaxFlow[dayIndex]!) {
        dayMaxFlow[dayIndex] = forecast.flow;
      }
    }

    // Create spots
    for (var index in dayMinFlow.keys) {
      _minSpots.add(FlSpot(index.toDouble(), dayMinFlow[index]!));
    }

    for (var index in dayMaxFlow.keys) {
      _maxSpots.add(FlSpot(index.toDouble(), dayMaxFlow[index]!));
    }

    // Sort spots by x value
    _minSpots.sort((a, b) => a.x.compareTo(b.x));
    _maxSpots.sort((a, b) => a.x.compareTo(b.x));
  }

  int _getDayIndex(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return _dayIndices[day] ?? 0;
  }

  DateTime? _getDateFromIndex(int index) {
    if (index < 0 || index >= _uniqueDays.length) {
      return null;
    }
    return _uniqueDays[index];
  }

  @override
  List<FlSpot> generateSpots() {
    // For medium range, we use max flow for the main line
    final List<FlSpot> spots = [];

    // Add a spot for each day using max flow
    for (var i = 0; i < _maxSpots.length; i++) {
      spots.add(_maxSpots[i]);
    }

    return spots;
  }

  @override
  double getMinY() {
    return 0.0;
  }

  @override
  double getMaxY() {
    if (_maxSpots.isEmpty) return 100.0;

    // Find max flow from spots and add 20% padding
    double maxFlow = _maxSpots.map((s) => s.y).reduce((a, b) => a > b ? a : b);

    // Consider return period thresholds
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
    if (_uniqueDays.isEmpty) return 9.0; // Default 9 days
    return (_uniqueDays.length - 1).toDouble();
  }

  @override
  String _getTooltipDateText(LineBarSpot spot) {
    final date = _getDateFromIndex(spot.x.toInt());
    if (date == null) return 'Unknown date';

    // Get the min flow for this day
    double? minFlow;
    for (var s in _minSpots) {
      if (s.x == spot.x) {
        minFlow = s.y;
        break;
      }
    }

    final dateText = DateFormat('EEE, MMM d').format(date);
    if (minFlow != null) {
      return '$dateText\nRange: ${flowFormatter.format(minFlow)} - ${flowFormatter.format(spot.y)} ft³/s';
    }

    return dateText;
  }

  @override
  Widget build(BuildContext context) {
    final spots = generateSpots();

    if (spots.isEmpty) {
      return _buildNoDataView();
    }

    // Calculate y-axis bounds
    final minY = getMinY();
    final maxY = getMaxY();

    // Get return period lines
    final horizontalLines = getReturnPeriodLines();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(0xFFBFBFBF),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFBFBFBF), Color(0xFFBFBFBF), Color(0xFFBFBFBF)],
            stops: [0.0, 0.8, 1.0],
          ),
        ),
        child: Padding(
          padding: chartPadding,
          child: LineChart(
            LineChartData(
              lineBarsData: [
                // Min flow line (dashed)
                if (_minSpots.isNotEmpty)
                  LineChartBarData(
                    spots: _minSpots,
                    isCurved: true,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    color: gradientColors[0].withOpacity(0.6),
                    dotData: const FlDotData(show: false),
                    dashArray: [5, 5], // Create a dashed line
                  ),
                // Max flow line
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
                              .map((color) => color.withOpacity(0.3))
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
                    color: gradientColors[0].withOpacity(0.2),
                    strokeWidth: 1,
                  );
                },
                getDrawingVerticalLine: (value) {
                  return FlLine(
                    color: gradientColors[0].withOpacity(0.45),
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: _buildTitlesData(),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: const Color(0xff37434d)),
              ),
              lineTouchData: _buildTouchData(),
              minX: getMinX(),
              maxX: getMaxX(),
              minY: minY,
              maxY: maxY,
            ),
          ),
        ),
      ),
    );
  }

  @override
  AxisTitles _buildBottomTitles() {
    return AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 50,
        getTitlesWidget: (value, meta) {
          final index = value.toInt();
          final date = _getDateFromIndex(index);
          if (date == null) return const SizedBox.shrink();

          // Format based on index
          String dateText;
          if (index == 0) {
            // Check if first day is today
            final today = DateTime.now();
            if (date.year == today.year &&
                date.month == today.month &&
                date.day == today.day) {
              dateText = 'Today';
            } else {
              dateText = DateFormat('MMM d').format(date);
            }
          } else {
            dateText = DateFormat('MMM d').format(date);
          }

          return Transform.rotate(
            angle: -45 * 3.14159 / 180,
            child: Padding(
              padding: const EdgeInsets.only(top: 20, right: 15),
              child: Text(
                dateText,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  LineTouchData _buildTouchData() {
    // Create a custom tooltip that shows min-max range
    return LineTouchData(
      enabled: true,
      touchTooltipData: LineTouchTooltipData(
        tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
        tooltipRoundedRadius: 8,
        getTooltipItems: (List<LineBarSpot> lineBarsSpot) {
          return lineBarsSpot.map((spot) {
            // Find min value for this day
            double? minValue;
            for (var s in _minSpots) {
              if (s.x == spot.x) {
                minValue = s.y;
                break;
              }
            }

            String flowText;
            if (minValue != null && minValue != spot.y) {
              flowText =
                  'Range: ${flowFormatter.format(minValue)} - ${flowFormatter.format(spot.y)} ft³/s';
            } else {
              flowText = '${flowFormatter.format(spot.y)} ft³/s';
            }

            final date = _getDateFromIndex(spot.x.toInt());
            String dateText = 'Unknown date';
            if (date != null) {
              dateText = DateFormat('EEE, MMM d').format(date);
            }

            return LineTooltipItem(
              flowText,
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              children: [
                TextSpan(
                  text: '\n$dateText',
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
                  color: gradientColors[0],
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
