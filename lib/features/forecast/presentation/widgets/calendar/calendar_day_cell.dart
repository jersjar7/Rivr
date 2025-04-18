// lib/features/forecast/presentation/widgets/calendar/calendar_day_cell.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rivr/features/forecast/domain/entities/return_period.dart';
import 'package:rivr/features/forecast/utils/flow_thresholds.dart';

class CalendarDayCell extends StatelessWidget {
  final DateTime date;
  final double? flowValue;
  final ReturnPeriod? returnPeriod;
  final bool isCurrentMonth;
  final bool isToday;
  final VoidCallback? onTap;
  final bool isSelected;
  final NumberFormat flowFormatter;

  CalendarDayCell({
    super.key,
    required this.date,
    this.flowValue,
    this.returnPeriod,
    this.isCurrentMonth = true,
    this.isToday = false,
    this.onTap,
    this.isSelected = false,
    NumberFormat? flowFormatter,
  }) : flowFormatter = flowFormatter ?? NumberFormat('#,##0.0');

  @override
  Widget build(BuildContext context) {
    final hasData = flowValue != null;
    String? flowCategory;
    Color cellColor = Colors.grey.shade100;
    Color textColor = isCurrentMonth ? Colors.black87 : Colors.grey.shade400;

    // Determine flow category and color if we have data
    if (hasData && returnPeriod != null) {
      flowCategory = returnPeriod!.getFlowCategory(flowValue!);
      cellColor = _getBackgroundColor(flowCategory);

      // Ensure text is readable on colored backgrounds
      textColor = _getTextColor(cellColor);
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: hasData ? _getGradient(flowCategory) : null,
          color:
              !hasData
                  ? (isCurrentMonth ? Colors.white : Colors.grey.shade100)
                  : null,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                isToday
                    ? Colors.blue.shade700
                    : (isSelected ? Colors.black : Colors.grey.shade300),
            width: isToday || isSelected ? 2 : 1,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Stack(
          children: [
            // Day number
            Positioned(
              top: 4,
              left: 6,
              child: Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      isToday || isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                  color: textColor,
                ),
              ),
            ),

            // Flow indicator
            if (hasData)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(7),
                      bottomRight: Radius.circular(7),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      flowFormatter.format(flowValue!),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              ),

            // "Today" indicator
            if (isToday)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getBackgroundColor(String? category) {
    if (category == null) return Colors.grey.shade100;
    return FlowThresholds.getColorForCategory(category).withOpacity(0.7);
  }

  Color _getTextColor(Color backgroundColor) {
    // Calculate luminance to determine if text should be light or dark
    return backgroundColor.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;
  }

  LinearGradient? _getGradient(String? category) {
    if (category == null) return null;

    final baseColor = FlowThresholds.getColorForCategory(category);
    final lighterColor = _lightenColor(baseColor, 0.3);

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [lighterColor, baseColor],
    );
  }

  Color _lightenColor(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }
}

class CalendarDayCellTooltip extends StatelessWidget {
  final DateTime date;
  final double flowValue;
  final ReturnPeriod? returnPeriod;

  const CalendarDayCellTooltip({
    super.key,
    required this.date,
    required this.flowValue,
    this.returnPeriod,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEEE, MMMM d, y').format(date);
    final flowStr = NumberFormat('#,##0.0').format(flowValue);
    String? category;
    String description = 'Flow information not available';

    if (returnPeriod != null) {
      category = returnPeriod!.getFlowCategory(flowValue);
      description = FlowThresholds.getFlowSummary(flowValue, returnPeriod!);
    }

    final categoryColor =
        category != null
            ? FlowThresholds.getColorForCategory(category)
            : Colors.grey;

    return Container(
      width: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateStr,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'Flow: ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('$flowStr ft³/s'),
            ],
          ),
          if (category != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Text(
                  'Status: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: categoryColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    category,
                    style: TextStyle(
                      color:
                          categoryColor.computeLuminance() > 0.5
                              ? Colors.black87
                              : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(color: Colors.black87, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
