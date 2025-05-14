// lib/features/forecast/presentation/widgets/hydrograph/base_hydrograph.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rivr/features/forecast/domain/entities/return_period.dart';

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

  // Abstract methods that must be implemented by subclasses
  List<FlSpot> generateSpots();
  double getMinY();
  double getMaxY();
  double getMinX();
  double getMaxX();

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

    // Define gradient colors based on theme
    final List<Color> gradientColors = [
      colorScheme.primary,
      colorScheme.secondary,
    ];

    if (spots.isEmpty) {
      return buildNoDataView();
    }

    // Calculate y-axis bounds
    final minY = getMinY();
    final maxY = getMaxY();

    // Get return period lines
    final horizontalLines = getReturnPeriodLines();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor:
            isDark ? colorScheme.surface : colorScheme.surfaceContainerHighest,
        elevation: 0,
      ),
      body: Container(
        color:
            isDark ? colorScheme.surface : colorScheme.surfaceContainerHighest,
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
              titlesData: buildTitlesData(isDark),
              borderData: FlBorderData(
                show: true,
                border: Border.all(
                  color: isDark ? colorScheme.outline : colorScheme.outline,
                ),
              ),
              lineTouchData: buildTouchData(isDark),
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
              '${flowFormatter.format(spot.y)} ft³/s',
              TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              children: [
                TextSpan(
                  text: '\n${getTooltipDateText(spot)}',
                  style: TextStyle(
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
    final textColor = isDark ? Colors.white : Colors.black;

    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: buildBottomTitles(),
      leftTitles: AxisTitles(
        axisNameWidget: Text(
          'ft³/s',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
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
                style: TextStyle(fontSize: 12, color: textColor),
                textAlign: TextAlign.right,
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
