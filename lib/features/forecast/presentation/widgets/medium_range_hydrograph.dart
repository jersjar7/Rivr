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

  String _getTooltipDateText(LineBarSpot spot) {
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
  Widget build(BuildContext context) {
    final spots = generateSpots();

    if (spots.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.show_chart, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No data available to display',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Try again later or select a different time range',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
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
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: buildBottomTitles(),
                leftTitles: AxisTitles(
                  axisNameWidget: const Text(
                    'ft³/s',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  axisNameSize: 30,
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: getReservedSizeForYAxis(getMaxY()),
                    getTitlesWidget: (value, meta) {
                      if (value == getMaxY() || value < 0) {
                        return Container();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: Text(
                          value.toStringAsFixed(0),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: const Color(0xff37434d)),
              ),
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor:
                      (spot) => Colors.blueGrey.withValues(alpha: 0.8),
                  tooltipRoundedRadius: 8,
                  getTooltipItems: (List<LineBarSpot> lineBarsSpot) {
                    return lineBarsSpot.map((spot) {
                      final forecast = _getForecastAtX(spot.x);
                      String timeInfo = _getTooltipDateText(spot);

                      // Add relative time (e.g. "2 days from now")
                      if (forecast != null) {
                        final now = DateTime.now();
                        final difference = forecast.validDateTime.difference(
                          now,
                        );

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
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
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
                      FlLine(
                        color: Colors.white,
                        strokeWidth: 2,
                        dashArray: [3, 3],
                      ),
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
              ),
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
}
