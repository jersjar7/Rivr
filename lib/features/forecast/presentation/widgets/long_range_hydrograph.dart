// lib/features/forecast/presentation/widgets/long_range_hydrograph.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rivr/features/forecast/domain/entities/forecast.dart';
import 'package:rivr/features/forecast/domain/entities/return_period.dart';
import 'package:rivr/features/forecast/presentation/widgets/hydrograph/base_hydrograph.dart';

class LongRangeHydrograph extends BaseHydrograph {
  final List<Forecast> forecasts;
  final Map<String, Map<String, double>>? longRangeFlows;

  const LongRangeHydrograph({
    super.key,
    required super.reachId,
    required this.forecasts,
    this.longRangeFlows,
    super.returnPeriod,
  }) : super(title: '30-Day Forecast');

  @override
  LongRangeHydrographState createState() => LongRangeHydrographState();
}

class LongRangeHydrographState
    extends BaseHydrographState<LongRangeHydrograph> {
  // Track dates for x-axis
  late final Map<DateTime, int> _dateIndices = {};
  late final List<DateTime> _uniqueDates = [];

  // Track peak and mean flow values
  List<FlSpot> _peakFlowSpots = [];
  List<FlSpot> _meanFlowSpots = [];

  @override
  void initState() {
    super.initState();

    // Process provided long range flows if available
    if (widget.longRangeFlows != null) {
      _processLongRangeFlows();
    } else {
      _processForecasts();
    }
  }

  void _processLongRangeFlows() {
    _peakFlowSpots = [];
    _meanFlowSpots = [];

    // Convert string dates to DateTime objects
    final Map<DateTime, Map<String, double>> parsedFlows = {};
    for (final entry in widget.longRangeFlows!.entries) {
      try {
        final date = DateTime.parse(entry.key);
        parsedFlows[date] = entry.value;
      } catch (e) {
        print('Error parsing date: ${entry.key}');
      }
    }

    // Sort dates chronologically
    _uniqueDates.addAll(parsedFlows.keys);
    _uniqueDates.sort();

    // Assign indices to dates
    for (int i = 0; i < _uniqueDates.length; i++) {
      _dateIndices[_uniqueDates[i]] = i;
    }

    // Create spots for peak and mean flows
    for (final date in _uniqueDates) {
      final index = _dateIndices[date]!.toDouble();
      final flows = parsedFlows[date]!;

      if (flows.containsKey('peakFlow')) {
        _peakFlowSpots.add(FlSpot(index, flows['peakFlow']!));
      }

      if (flows.containsKey('meanFlow')) {
        _meanFlowSpots.add(FlSpot(index, flows['meanFlow']!));
      }
    }
  }

  void _processForecasts() {
    // Group forecasts by day
    final Map<DateTime, List<Forecast>> forecastsByDay = {};

    for (var forecast in widget.forecasts) {
      final date = DateTime(
        forecast.validDateTime.year,
        forecast.validDateTime.month,
        forecast.validDateTime.day,
      );

      forecastsByDay.putIfAbsent(date, () => []).add(forecast);
    }

    // Sort dates chronologically
    _uniqueDates.addAll(forecastsByDay.keys);
    _uniqueDates.sort();

    // Assign indices to dates
    for (int i = 0; i < _uniqueDates.length; i++) {
      _dateIndices[_uniqueDates[i]] = i;
    }

    // Calculate peak and mean flows for each day
    for (final date in _uniqueDates) {
      final forecasts = forecastsByDay[date]!;
      final index = _dateIndices[date]!.toDouble();

      // Calculate peak flow (maximum)
      final peakFlow = forecasts
          .map((f) => f.flow)
          .reduce((a, b) => a > b ? a : b);
      _peakFlowSpots.add(FlSpot(index, peakFlow));

      // Calculate mean flow (average)
      final meanFlow =
          forecasts.map((f) => f.flow).reduce((a, b) => a + b) /
          forecasts.length;
      _meanFlowSpots.add(FlSpot(index, meanFlow));
    }
  }

  DateTime? _getDateFromIndex(int index) {
    if (index < 0 || index >= _uniqueDates.length) {
      return null;
    }
    return _uniqueDates[index];
  }

  @override
  List<FlSpot> generateSpots() {
    // For long range, we use peak flow values
    return _peakFlowSpots;
  }

  @override
  double getMinY() {
    return 0.0;
  }

  @override
  double getMaxY() {
    if (_peakFlowSpots.isEmpty) return 100.0;

    // Find max flow and add 20% padding
    double maxFlow = _peakFlowSpots
        .map((s) => s.y)
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

    return maxFlow * 1.2;
  }

  @override
  double getMinX() {
    return 0.0;
  }

  @override
  double getMaxX() {
    if (_uniqueDates.isEmpty) return 30.0; // Default 30 days
    return (_uniqueDates.length - 1).toDouble();
  }

  @override
  String _getTooltipDateText(LineBarSpot spot) {
    final date = _getDateFromIndex(spot.x.toInt());
    if (date == null) return 'Unknown date';

    // Get the mean flow for this day
    double? meanFlow;
    for (var s in _meanFlowSpots) {
      if (s.x == spot.x) {
        meanFlow = s.y;
        break;
      }
    }

    final dateText = DateFormat('EEE, MMM d').format(date);
    if (meanFlow != null && meanFlow != spot.y) {
      // Show both mean and peak
      return '$dateText\nMean: ${flowFormatter.format(meanFlow)} ft³/s';
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
                // Mean flow line (dashed)
                if (_meanFlowSpots.isNotEmpty)
                  LineChartBarData(
                    spots: _meanFlowSpots,
                    isCurved: true,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    color: gradientColors[0].withOpacity(0.6),
                    dotData: const FlDotData(show: false),
                    dashArray: [5, 5], // Create a dashed line
                  ),
                // Peak flow line
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
        interval: 5, // Show every 5 days to prevent crowding
        getTitlesWidget: (value, meta) {
          final index = value.toInt();

          // Only show every 5th date or first/last
          if (index != 0 &&
              index != _uniqueDates.length - 1 &&
              index % 5 != 0) {
            return const SizedBox.shrink();
          }

          final date = _getDateFromIndex(index);
          if (date == null) return const SizedBox.shrink();

          // Format the date
          String dateText = DateFormat('MMM d').format(date);

          return Transform.rotate(
            angle: -45 * 3.14159 / 180,
            child: Padding(
              padding: const EdgeInsets.only(top: 15, right: 15),
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
    // Create a custom tooltip that shows mean and peak flow
    return LineTouchData(
      enabled: true,
      touchTooltipData: LineTouchTooltipData(
        tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
        tooltipRoundedRadius: 8,
        getTooltipItems: (List<LineBarSpot> lineBarsSpot) {
          return lineBarsSpot.map((spot) {
            // Find mean value for this day
            double? meanValue;
            for (var s in _meanFlowSpots) {
              if (s.x == spot.x) {
                meanValue = s.y;
                break;
              }
            }

            final peakFlow = spot.y;
            String flowText = 'Peak: ${flowFormatter.format(peakFlow)} ft³/s';
            if (meanValue != null && meanValue != peakFlow) {
              flowText += '\nMean: ${flowFormatter.format(meanValue)} ft³/s';
            }

            final date = _getDateFromIndex(spot.x.toInt());
            String dateText = 'Unknown date';
            if (date != null) {
              dateText = DateFormat('EEE, MMM d, yyyy').format(date);
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
