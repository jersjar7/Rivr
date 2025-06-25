// lib/features/settings/presentation/widgets/time_picker_widget.dart
// Reusable time picker widget for notification settings

import 'package:flutter/material.dart';

/// Reusable time picker widget
class TimePickerWidget extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final ValueChanged<TimeOfDay> onTimeChanged;
  final bool enabled;

  const TimePickerWidget({
    super.key,
    required this.label,
    required this.time,
    required this.onTimeChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? () => _selectTime(context) : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: enabled ? Colors.grey.shade300 : Colors.grey.shade200,
          ),
          borderRadius: BorderRadius.circular(8),
          color: enabled ? null : Colors.grey.shade50,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: enabled ? Colors.grey : Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(time),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: enabled ? null : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectTime(BuildContext context) async {
    final newTime = await showTimePicker(context: context, initialTime: time);
    if (newTime != null) {
      onTimeChanged(newTime);
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}

/// Info banner widget for notifications
class InfoBanner extends StatelessWidget {
  final String message;
  final IconData icon;
  final MaterialColor? color; // <--- Change Color? to MaterialColor?

  const InfoBanner({
    super.key,
    required this.message,
    this.icon = Icons.info_outline,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final MaterialColor bannerColor =
        color ?? Colors.amber; // <--- Ensure type here too

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bannerColor.shade50, // This will now work!
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: bannerColor.shade200), // This will now work!
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: bannerColor.shade700, // This will now work!
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}
