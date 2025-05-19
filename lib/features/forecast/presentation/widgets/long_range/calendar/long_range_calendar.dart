// lib/features/forecast/presentation/widgets/long_range/calendar/long_range_calendar.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rivr/core/formatters/flow_value_formatter.dart';
import 'package:rivr/core/models/flow_unit.dart';
import 'package:rivr/core/services/flow_units_service.dart';
import 'package:rivr/features/forecast/domain/entities/forecast.dart';
import 'package:rivr/features/forecast/domain/entities/return_period.dart';
import 'package:rivr/features/forecast/presentation/widgets/long_range/calendar/calendar_day_cell.dart';

class LongRangeCalendar extends StatefulWidget {
  final List<Forecast> forecasts;
  final ReturnPeriod? returnPeriod;
  final DateTime? initialMonth;
  final Map<DateTime, Map<String, double>>? longRangeFlows;
  final VoidCallback? onRefresh;

  const LongRangeCalendar({
    super.key,
    required this.forecasts,
    this.returnPeriod,
    this.initialMonth,
    this.longRangeFlows,
    this.onRefresh,
  });

  @override
  State<LongRangeCalendar> createState() => _LongRangeCalendarState();
}

class _LongRangeCalendarState extends State<LongRangeCalendar> {
  late DateTime _currentMonth;
  DateTime? _selectedDate;
  OverlayEntry? _tooltipOverlay;
  final GlobalKey _calendarKey = GlobalKey();

  // Unit services
  late FlowValueFormatter _flowValueFormatter;
  late FlowUnitsService _flowUnitsService;

  // Source unit - assume CFS for API data
  final FlowUnit _sourceUnit = FlowUnit.cfs;

  @override
  void initState() {
    super.initState();
    _currentMonth = widget.initialMonth ?? DateTime.now();

    // Initialize formatters
    _flowValueFormatter = Provider.of<FlowValueFormatter>(
      context,
      listen: false,
    );
    _flowUnitsService = Provider.of<FlowUnitsService>(context, listen: false);

    // Listen for unit changes
    _flowUnitsService.addListener(_onUnitChanged);

    _processForecasts();
  }

  @override
  void didUpdateWidget(LongRangeCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.forecasts != widget.forecasts ||
        oldWidget.longRangeFlows != widget.longRangeFlows) {
      _processForecasts();
    }
  }

  @override
  void dispose() {
    _removeTooltip();
    _flowUnitsService.removeListener(_onUnitChanged);
    super.dispose();
  }

  // Handle unit changes
  void _onUnitChanged() {
    if (mounted) {
      // Reprocess forecasts when units change
      setState(() {
        _processForecasts();
      });
    }
  }

  // Map to store aggregated daily flow values - already in the correct unit
  final Map<DateTime, double> _dailyFlows = {};

  void _processForecasts() {
    _dailyFlows.clear();

    // First process forecasts
    for (var forecast in widget.forecasts) {
      final date = DateTime(
        forecast.validDateTime.year,
        forecast.validDateTime.month,
        forecast.validDateTime.day,
      );

      // Convert flow to preferred unit
      final convertedFlow = _flowUnitsService.convertToPreferredUnit(
        forecast.flow,
        _sourceUnit,
      );

      // If we already have a value for this day, average them
      if (_dailyFlows.containsKey(date)) {
        _dailyFlows[date] = (_dailyFlows[date]! + convertedFlow) / 2;
      } else {
        _dailyFlows[date] = convertedFlow;
      }
    }

    // Then process longRangeFlows if available
    if (widget.longRangeFlows != null) {
      widget.longRangeFlows!.forEach((date, flowData) {
        try {
          // Use 'mean' or 'avg' flow value if available
          final flow = flowData['mean'] ?? flowData['avg'] ?? flowData['flow'];
          if (flow != null) {
            // Convert flow to preferred unit
            final convertedFlow = _flowUnitsService.convertToPreferredUnit(
              flow,
              _sourceUnit,
            );

            // Normalize to start of day to ensure proper matching
            final normalizedDate = DateTime(date.year, date.month, date.day);
            _dailyFlows[normalizedDate] = convertedFlow;
          }
        } catch (e) {
          // Skip entries that can't be processed
        }
      });
    }
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  void _showTooltip(
    BuildContext context,
    DateTime date,
    double flowValue,
    Offset position,
  ) {
    _removeTooltip();

    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    final calendarRenderBox =
        _calendarKey.currentContext?.findRenderObject() as RenderBox?;

    if (renderBox == null || calendarRenderBox == null) return;

    final calendarPosition = calendarRenderBox.localToGlobal(Offset.zero);
    final calendarSize = calendarRenderBox.size;

    // Tooltip position calculation
    var tooltipPosition = position;

    // Ensure tooltip is within screen bounds
    const tooltipWidth = 250.0;
    const tooltipHeight = 130.0;

    // Adjust X position if needed
    if (tooltipPosition.dx + tooltipWidth >
        calendarPosition.dx + calendarSize.width) {
      tooltipPosition = Offset(
        calendarPosition.dx + calendarSize.width - tooltipWidth,
        tooltipPosition.dy,
      );
    }

    // Adjust Y position if needed (if tooltip would go below screen)
    if (tooltipPosition.dy + tooltipHeight >
        calendarPosition.dy + calendarSize.height) {
      // Position it above the cell
      tooltipPosition = Offset(
        tooltipPosition.dx,
        tooltipPosition.dy - tooltipHeight - 20, // 20 is a buffer
      );
    }

    _tooltipOverlay = OverlayEntry(
      builder:
          (context) => Positioned(
            left: tooltipPosition.dx,
            top: tooltipPosition.dy,
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: _removeTooltip,
                child: CalendarDayCellTooltip(
                  date: date,
                  flowValue: flowValue,
                  returnPeriod: widget.returnPeriod,
                  flowValueFormatter: _flowValueFormatter,
                  // Flow values are already in the preferred unit
                  fromUnit: _flowUnitsService.preferredUnit,
                ),
              ),
            ),
          ),
    );

    overlay.insert(_tooltipOverlay!);
  }

  void _removeTooltip() {
    _tooltipOverlay?.remove();
    _tooltipOverlay = null;
  }

  void _selectDate(DateTime date, double? flowValue, Offset position) {
    _removeTooltip(); // Remove any existing tooltip

    setState(() {
      if (_selectedDate == date) {
        _selectedDate = null; // Deselect if tapping the same date
      } else {
        _selectedDate = date;
      }
    });

    if (flowValue != null && _selectedDate != null) {
      _showTooltip(context, date, flowValue, position);
    }
  }

  List<Widget> _buildCalendarRows() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final rows = <Widget>[];

    // Get the first day of the month
    final firstDayOfMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month,
      1,
    );

    // Calculate the first day to display (may be from the previous month)
    final firstWeekday = firstDayOfMonth.weekday % 7; // 0 = Sunday
    final firstDisplayDate = firstDayOfMonth.subtract(
      Duration(days: firstWeekday),
    );

    // Build day labels (Sun, Mon, etc.)
    final dayLabels = Row(
      children: List.generate(7, (index) {
        final dayName = DateFormat(
          'E',
        ).format(DateTime(2023, 1, 1 + index)); // 2023-01-01 was a Sunday
        return Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                dayName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color:
                      index == 0 || index == 6
                          ? Colors
                              .red
                              .shade300 // Weekend
                          : Colors.grey.shade700, // Weekday
                ),
              ),
            ),
          ),
        );
      }),
    );

    rows.add(dayLabels);

    // Build calendar grid
    for (var week = 0; week < 6; week++) {
      final weekRow = Row(
        children: List.generate(7, (day) {
          final date = firstDisplayDate.add(Duration(days: week * 7 + day));
          final isCurrentMonth = date.month == _currentMonth.month;
          final isToday = date.isAtSameMomentAs(today);

          // Check if we have flow data for this date
          final flowValue =
              _dailyFlows[DateTime(date.year, date.month, date.day)];

          return Expanded(
            child: AspectRatio(
              aspectRatio: 1.0,
              child: Padding(
                padding: const EdgeInsets.all(2.0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      onTapUp: (details) {
                        if (flowValue != null) {
                          // Calculate position for tooltip
                          final renderBox =
                              context.findRenderObject() as RenderBox;
                          final offset = renderBox.localToGlobal(Offset.zero);
                          final position = Offset(
                            offset.dx,
                            offset.dy + constraints.maxHeight,
                          );
                          _selectDate(date, flowValue, position);
                        }
                      },
                      child: CalendarDayCell(
                        date: date,
                        flowValue: flowValue,
                        returnPeriod: widget.returnPeriod,
                        isCurrentMonth: isCurrentMonth,
                        isToday: isToday,
                        isSelected: _selectedDate == date,
                        flowValueFormatter: _flowValueFormatter,
                        // Flow values in _dailyFlows are already converted
                        fromUnit: _flowUnitsService.preferredUnit,
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        }),
      );

      rows.add(weekRow);

      // Stop after we've displayed all days of the current month
      final lastDateInRow = firstDisplayDate.add(
        Duration(days: (week + 1) * 7 - 1),
      );
      if (lastDateInRow.month > _currentMonth.month &&
          lastDateInRow.year >= _currentMonth.year) {
        break;
      }
    }

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Calendar header with month navigation
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _previousMonth,
                tooltip: 'Previous Month',
              ),
              Text(
                DateFormat('MMMM yyyy').format(_currentMonth),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _nextMonth,
                tooltip: 'Next Month',
              ),
            ],
          ),
        ),

        // Calendar grid
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(key: _calendarKey, children: _buildCalendarRows()),
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }
}
