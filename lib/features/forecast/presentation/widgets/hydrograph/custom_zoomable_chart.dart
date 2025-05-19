// lib/features/forecast/presentation/widgets/hydrograph/custom_zoomable_chart.dart

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

/// A custom zoomable chart component specifically for the expandable overlay view
class CustomZoomableChart extends StatefulWidget {
  final String reachId;
  final ForecastType forecastType;
  final List<Forecast> forecasts;
  final ReturnPeriod? returnPeriod;
  final Map<DateTime, Map<String, double>>? dailyStats;
  final Map<String, Map<String, double>>? longRangeFlows;
  final FlowUnit sourceUnit; // Add source unit parameter

  const CustomZoomableChart({
    super.key,
    required this.reachId,
    required this.forecastType,
    required this.forecasts,
    this.returnPeriod,
    this.dailyStats,
    this.longRangeFlows,
    this.sourceUnit = FlowUnit.cfs, // Default to CFS as source unit
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

  // Track where "now" is on the x-axis
  double? _nowX;

  // Data for chart
  late List<FlSpot> _spots;
  late final DateFormat dateFormatter = DateFormat('MMM d');
  late final DateFormat timeFormatter = DateFormat('h:mm a');
  late DateTime _currentLocalTime;

  // Flow unit services
  late final FlowUnitsService _flowUnitsService;
  late final FlowValueFormatter _flowValueFormatter;

  // Transformations based on zoom/pan
  double get _transformedMinX => _baseMinX + _xOffset;
  double get _transformedMaxX =>
      _baseMinX + (_baseMaxX - _baseMinX) / _currentZoomLevel + _xOffset;

  @override
  void initState() {
    super.initState();
    _currentLocalTime = DateTime.now();

    // Initialize flow unit services
    _flowUnitsService = Provider.of<FlowUnitsService>(context, listen: false);
    _flowValueFormatter = Provider.of<FlowValueFormatter>(
      context,
      listen: false,
    );

    // Listen for unit changes
    _flowUnitsService.addListener(_onUnitChanged);

    _initializeChartData();
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
      // Reinitialize chart data with the new unit
      _initializeChartData();
      setState(() {}); // Trigger rebuild
    }
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

  // Short range spots (hourly) with unit conversion
  List<FlSpot> _generateShortRangeSpots() {
    if (widget.forecasts.isEmpty) return [];

    // Sort forecasts by time
    final sortedForecasts = List<Forecast>.from(widget.forecasts)
      ..sort((a, b) => a.validDateTimeLocal.compareTo(b.validDateTimeLocal));

    // Always use the first forecast time as base time for consistent x-axis
    final baseTime = sortedForecasts.first.validDateTimeLocal;

    // Calculate where "now" is relative to the first forecast time
    final now = _currentLocalTime;
    final hourDifference = now.difference(baseTime).inMinutes / 60;

    // Only set now offset if it's within the forecast range
    if (hourDifference >= 0 &&
        hourDifference <=
            sortedForecasts.last.validDateTimeLocal
                    .difference(baseTime)
                    .inMinutes /
                60) {
      _nowX = hourDifference;
    }

    final List<FlSpot> spots = [];
    for (var forecast in sortedForecasts) {
      // Get normalized hours from base time
      final hours =
          forecast.validDateTimeLocal.difference(baseTime).inMinutes / 60;

      // Convert flow to preferred unit if needed
      double flowValue = forecast.flow;
      if (widget.sourceUnit != _flowUnitsService.preferredUnit) {
        flowValue = _flowUnitsService.convertToPreferredUnit(
          flowValue,
          widget.sourceUnit,
        );
      }

      spots.add(FlSpot(hours, flowValue));
    }

    return spots;
  }

  // Medium range spots (daily) with unit conversion
  List<FlSpot> _generateMediumRangeSpots() {
    if (widget.forecasts.isEmpty) return [];

    // Sort forecasts by time
    final sortedForecasts = List<Forecast>.from(widget.forecasts)
      ..sort((a, b) => a.validDateTimeLocal.compareTo(b.validDateTimeLocal));

    // Always use the first forecast day as base time for consistent x-axis
    final firstForecastTime = sortedForecasts.first.validDateTimeLocal;
    final baseTime = DateTime(
      firstForecastTime.year,
      firstForecastTime.month,
      firstForecastTime.day,
    );

    // Calculate where "now" is relative to the first forecast time
    final now = _currentLocalTime;
    final nowDay = DateTime(now.year, now.month, now.day);
    final dayDifference = nowDay.difference(baseTime).inHours / 24;

    // Only set now marker if it's within the forecast range
    final lastDayDifference =
        sortedForecasts.last.validDateTimeLocal.difference(baseTime).inHours /
        24;
    if (dayDifference >= 0 && dayDifference <= lastDayDifference) {
      _nowX = dayDifference;
    }

    final List<FlSpot> spots = [];

    // Add regular forecast spots with unit conversion
    for (var forecast in sortedForecasts) {
      // Get normalized days from base time (in hours / 24)
      final days =
          forecast.validDateTimeLocal.difference(baseTime).inHours / 24;

      // Convert flow to preferred unit if needed
      double flowValue = forecast.flow;
      if (widget.sourceUnit != _flowUnitsService.preferredUnit) {
        flowValue = _flowUnitsService.convertToPreferredUnit(
          flowValue,
          widget.sourceUnit,
        );
      }

      spots.add(FlSpot(days, flowValue));
    }

    // Add spots from dailyStats if available - with unit conversion
    if (widget.dailyStats != null && widget.dailyStats!.isNotEmpty) {
      for (var entry in widget.dailyStats!.entries) {
        final date = entry.key;
        final stats = entry.value;

        // Use 'mean' or 'avg' flow value if available
        final flow = stats['mean'] ?? stats['avg'] ?? stats['flow'];

        if (flow != null) {
          final days = date.difference(baseTime).inHours / 24;

          // Convert flow to preferred unit if needed
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

    // Sort spots by x-value
    spots.sort((a, b) => a.x.compareTo(b.x));

    return spots;
  }

  // Long range spots (weekly) with unit conversion
  List<FlSpot> _generateLongRangeSpots() {
    if (widget.forecasts.isEmpty) return [];

    // Sort forecasts by time
    final sortedForecasts = List<Forecast>.from(widget.forecasts)
      ..sort((a, b) => a.validDateTimeLocal.compareTo(b.validDateTimeLocal));

    // Always use the first forecast week as base time for consistent x-axis
    final firstForecastTime = sortedForecasts.first.validDateTimeLocal;
    final baseTime = DateTime(
      firstForecastTime.year,
      firstForecastTime.month,
      firstForecastTime.day,
    ).subtract(Duration(days: firstForecastTime.weekday % 7));

    // Calculate where "now" is relative to the first forecast week
    final now = _currentLocalTime;
    final nowWeekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday % 7));
    final weekDifference = nowWeekStart.difference(baseTime).inDays / 7;

    // Only set now marker if it's within the forecast range
    final lastWeekDifference =
        sortedForecasts.last.validDateTimeLocal.difference(baseTime).inDays / 7;
    if (weekDifference >= 0 && weekDifference <= lastWeekDifference) {
      _nowX = weekDifference;
    }

    final List<FlSpot> spots = [];

    // Add regular forecast spots with unit conversion
    for (var forecast in sortedForecasts) {
      // Get normalized weeks from base time (in days / 7)
      final weeks = forecast.validDateTimeLocal.difference(baseTime).inDays / 7;

      // Convert flow to preferred unit if needed
      double flowValue = forecast.flow;
      if (widget.sourceUnit != _flowUnitsService.preferredUnit) {
        flowValue = _flowUnitsService.convertToPreferredUnit(
          flowValue,
          widget.sourceUnit,
        );
      }

      spots.add(FlSpot(weeks, flowValue));
    }

    // Add spots from longRangeFlows if available - with unit conversion
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

              // Convert flow to preferred unit if needed
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

    // Find max flow from all sources and add 20% for padding
    double maxFlow = 0;

    // Check forecast data
    for (var forecast in widget.forecasts) {
      // Convert flow to preferred unit if needed
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

    // Check daily stats if available
    if (widget.dailyStats != null) {
      for (var entry in widget.dailyStats!.entries) {
        final stats = entry.value;
        final maxValue = stats['max'] ?? stats['maxFlow'] ?? stats['mean'];

        if (maxValue != null) {
          // Convert to preferred unit if needed
          double convertedValue = maxValue;
          if (widget.sourceUnit != _flowUnitsService.preferredUnit) {
            convertedValue = _flowUnitsService.convertToPreferredUnit(
              maxValue,
              widget.sourceUnit,
            );
          }

          if (convertedValue > maxFlow) {
            maxFlow = convertedValue;
          }
        }
      }
    }

    // Check long range flows if available
    if (widget.longRangeFlows != null) {
      for (var entry in widget.longRangeFlows!.entries) {
        final flowData = entry.value;
        final maxValue =
            flowData['max'] ?? flowData['maxFlow'] ?? flowData['mean'];

        if (maxValue != null) {
          // Convert to preferred unit if needed
          double convertedValue = maxValue;
          if (widget.sourceUnit != _flowUnitsService.preferredUnit) {
            convertedValue = _flowUnitsService.convertToPreferredUnit(
              maxValue,
              widget.sourceUnit,
            );
          }

          if (convertedValue > maxFlow) {
            maxFlow = convertedValue;
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

  // Find forecast at specific x value
  Forecast? _getForecastAtX(double x) {
    if (widget.forecasts.isEmpty) return null;

    // Find the forecast closest to this x value
    Forecast? closest;
    double minDistance = double.infinity;

    for (final forecast in widget.forecasts) {
      DateTime baseTime;
      double forecastX;

      // Calculate the x value for this forecast based on forecast type
      switch (widget.forecastType) {
        case ForecastType.shortRange:
          baseTime = widget.forecasts.first.validDateTimeLocal;
          forecastX =
              forecast.validDateTimeLocal.difference(baseTime).inMinutes / 60;
          break;
        case ForecastType.mediumRange:
          baseTime = DateTime(
            widget.forecasts.first.validDateTimeLocal.year,
            widget.forecasts.first.validDateTimeLocal.month,
            widget.forecasts.first.validDateTimeLocal.day,
          );
          forecastX =
              forecast.validDateTimeLocal.difference(baseTime).inHours / 24;
          break;
        case ForecastType.longRange:
          final firstForecastTime = widget.forecasts.first.validDateTimeLocal;
          baseTime = DateTime(
            firstForecastTime.year,
            firstForecastTime.month,
            firstForecastTime.day,
          ).subtract(Duration(days: firstForecastTime.weekday % 7));
          forecastX =
              forecast.validDateTimeLocal.difference(baseTime).inDays / 7;
          break;
      }

      final distance = (forecastX - x).abs();
      if (distance < minDistance) {
        minDistance = distance;
        closest = forecast;
      }
    }

    return closest;
  }

  // Get tooltip text based on forecast type
  String _getTooltipDateText(LineBarSpot spot) {
    final forecast = _getForecastAtX(spot.x);
    if (forecast != null) {
      final now = _currentLocalTime;
      final forecastTime = forecast.validDateTimeLocal;

      switch (widget.forecastType) {
        case ForecastType.shortRange:
          final isSameDay =
              forecastTime.day == now.day &&
              forecastTime.month == now.month &&
              forecastTime.year == now.year;

          if (isSameDay) {
            if ((forecastTime.hour == now.hour) &&
                (forecastTime.minute - now.minute).abs() < 15) {
              return "Today, Now";
            }
            return "Today, ${DateFormat('h:mm a').format(forecastTime)}";
          }
          return DateFormat('EEE, MMM d, h:mm a').format(forecastTime);

        case ForecastType.mediumRange:
          return DateFormat('EEE, MMM d').format(forecastTime);

        case ForecastType.longRange:
          final weekStart = DateTime(
            forecastTime.year,
            forecastTime.month,
            forecastTime.day,
          ).subtract(Duration(days: forecastTime.weekday % 7));
          final weekEnd = weekStart.add(const Duration(days: 6));
          return '${DateFormat('MMM d').format(weekStart)} - ${DateFormat('MMM d').format(weekEnd)}';
      }
    }

    // Fallback if forecast not found - use spot.x to estimate the date
    final firstForecastTime = widget.forecasts.first.validDateTimeLocal;

    switch (widget.forecastType) {
      case ForecastType.shortRange:
        final time = firstForecastTime.add(
          Duration(minutes: (spot.x * 60).toInt()),
        );
        return DateFormat('EEE, MMM d, h:mm a').format(time);

      case ForecastType.mediumRange:
        final baseTime = DateTime(
          firstForecastTime.year,
          firstForecastTime.month,
          firstForecastTime.day,
        );
        final time = baseTime.add(Duration(hours: (spot.x * 24).toInt()));
        return DateFormat('EEE, MMM d').format(time);

      case ForecastType.longRange:
        final baseTime = DateTime(
          firstForecastTime.year,
          firstForecastTime.month,
          firstForecastTime.day,
        ).subtract(Duration(days: firstForecastTime.weekday % 7));
        final time = baseTime.add(Duration(days: (spot.x * 7).toInt()));
        final weekEnd = time.add(const Duration(days: 6));
        return '${DateFormat('MMM d').format(time)} - ${DateFormat('MMM d').format(weekEnd)}';
    }
  }

  // Get relative time description (e.g., "2 hours from now")
  String _getRelativeTimeText(LineBarSpot spot) {
    final forecast = _getForecastAtX(spot.x);
    if (forecast == null) return '';

    final now = _currentLocalTime;
    final forecastTime = forecast.validDateTimeLocal;
    final difference = forecastTime.difference(now);

    // If time difference is less than 1 minute, consider it "now"
    if (difference.inMinutes.abs() < 1) return 'Now';

    switch (widget.forecastType) {
      case ForecastType.shortRange:
        if (difference.inHours == 0) {
          final minutes = difference.inMinutes;
          if (minutes.abs() < 5) return 'Now';
          return minutes > 0 ? 'In $minutes min' : '${-minutes} min ago';
        }
        if (difference.inHours > 0) {
          return difference.inHours == 1
              ? 'In 1 hour'
              : 'In ${difference.inHours} hours';
        } else {
          return difference.inHours == -1
              ? '1 hour ago'
              : '${-difference.inHours} hours ago';
        }

      case ForecastType.mediumRange:
        if (difference.inDays == 0) return 'Today';
        if (difference.inDays == 1) return 'Tomorrow';
        if (difference.inDays == -1) return 'Yesterday';
        if (difference.inDays > 1) return 'In ${difference.inDays} days';
        return '${-difference.inDays} days ago';

      case ForecastType.longRange:
        final weeks = (difference.inDays / 7).round();
        if (weeks == 0) return 'This week';
        if (weeks == 1) return 'Next week';
        if (weeks == -1) return 'Last week';
        if (weeks > 1) return 'In $weeks weeks';
        return '${-weeks} weeks ago';
    }
  }

  // Build bottom axis titles based on forecast type
  FlTitlesData _buildTitlesData(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final highlightColor = Theme.of(context).colorScheme.primary;

    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          getTitlesWidget: (value, meta) {
            // Don't show labels if no forecasts
            if (widget.forecasts.isEmpty) return const SizedBox.shrink();

            // Check if we should display a "Now" label at the current time position
            if (_nowX != null && (value - _nowX!).abs() < 0.1) {
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Now',
                  style: TextStyle(
                    fontSize: 12,
                    color: highlightColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }

            // First forecast time as reference point
            final baseTime = widget.forecasts.first.validDateTimeLocal;

            // Custom implementation based on forecast type
            if (widget.forecastType == ForecastType.shortRange) {
              // Only show labels every 6 hours or at midnight
              final timeAtX = baseTime.add(
                Duration(minutes: (value * 60).toInt()),
              );
              final isAtHour =
                  timeAtX.minute < 15; // Within 15 minutes of an hour
              final isMidnight = timeAtX.hour == 0 && isAtHour;
              final isMultipleOf6 = timeAtX.hour % 6 == 0 && isAtHour;

              if (!isMidnight &&
                  !isMultipleOf6 &&
                  (_nowX == null || (value - _nowX!).abs() > 0.1)) {
                return const SizedBox.shrink();
              }

              // Format based on hour
              String timeText;
              if (_nowX != null && (value - _nowX!).abs() < 0.1) {
                timeText = 'Now';
              } else if (isMidnight) {
                // At midnight, show the date
                timeText = DateFormat('MMM d').format(timeAtX);
              } else {
                // Otherwise show the hour
                timeText = DateFormat('ha').format(timeAtX).toLowerCase();
              }

              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  timeText,
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            } else if (widget.forecastType == ForecastType.mediumRange) {
              // Only show whole days
              if (value % 1 > 0.1 && value % 1 < 0.9) {
                return const SizedBox.shrink();
              }

              // For day-based x-axis
              final baseTime = DateTime(
                widget.forecasts.first.validDateTimeLocal.year,
                widget.forecasts.first.validDateTimeLocal.month,
                widget.forecasts.first.validDateTimeLocal.day,
              );
              final datetime = baseTime.add(
                Duration(hours: (value * 24).toInt()),
              );

              String dayText;
              if (_nowX != null && (value - _nowX!).abs() < 0.1) {
                dayText = 'Today';
              } else if (_nowX != null && (value - _nowX! - 1).abs() < 0.1) {
                dayText = 'Tmrw';
              } else {
                dayText = DateFormat('EEE\nM/d').format(datetime);
              }

              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  dayText,
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            } else {
              // Long range (weekly) implementation
              // Only show whole weeks
              if (value % 1 > 0.1 && value % 1 < 0.9) {
                return const SizedBox.shrink();
              }

              // For week-based x-axis
              final firstForecastTime =
                  widget.forecasts.first.validDateTimeLocal;
              final baseTime = DateTime(
                firstForecastTime.year,
                firstForecastTime.month,
                firstForecastTime.day,
              ).subtract(Duration(days: firstForecastTime.weekday % 7));
              final datetime = baseTime.add(
                Duration(days: (value * 7).toInt()),
              );

              String weekText;
              if (_nowX != null && (value - _nowX!).abs() < 0.1) {
                weekText = 'This\nWeek';
              } else if (_nowX != null && (value - _nowX! - 1).abs() < 0.1) {
                weekText = 'Next\nWeek';
              } else {
                final weekOfMonth = (datetime.day / 7).ceil();
                weekText =
                    '${DateFormat('MMM').format(datetime)}\nWk $weekOfMonth';
              }

              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  weekText,
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            }
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
            final dateText = _getTooltipDateText(spot);
            final relativeText = _getRelativeTimeText(spot);

            // Use the flow formatter for proper unit format
            final flowFormatted = _flowValueFormatter.format(spot.y);

            return LineTooltipItem(
              flowFormatted, // Flow with unit
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
                if (relativeText.isNotEmpty)
                  TextSpan(
                    text: '\n$relativeText',
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

  // Add a vertical line to show "Now"
  List<VerticalLine> _getVerticalNowLine(bool isDark) {
    if (_nowX == null) return [];

    final colorScheme = Theme.of(context).colorScheme;
    final lineColor = colorScheme.primary;

    return [
      VerticalLine(
        x: _nowX!,
        color: lineColor.withValues(alpha: 0.7),
        strokeWidth: 2,
        dashArray: [5, 3],
        label: VerticalLineLabel(
          show: true,
          alignment: Alignment.topRight,
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
          labelResolver: (line) => 'Now',
        ),
      ),
    ];
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
    final verticalNowLine = _getVerticalNowLine(isDark);
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
                  verticalLines: verticalNowLine,
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
