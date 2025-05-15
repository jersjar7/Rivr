// lib/features/forecast/presentation/widgets/medium_range/daily_flow_forecast/hourly_daily_flows_widget/time_slider.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A custom time slider that allows selection of an hour of the day
class HourlyTimeSlider extends StatelessWidget {
  final int hourCount;
  final double currentValue;
  final ValueChanged<double> onChanged;
  final List<DateTime> hourLabels;

  const HourlyTimeSlider({
    super.key,
    required this.hourCount,
    required this.currentValue,
    required this.onChanged,
    required this.hourLabels,
  });

  @override
  Widget build(BuildContext context) {
    // We need at least 2 data points for a meaningful slider
    if (hourCount <= 1 || hourLabels.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Center(
          child: Text(
            hourCount == 1
                ? 'Only one hour of data available'
                : 'No hourly data available',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The slider itself
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: colorScheme.primary,
            inactiveTrackColor: colorScheme.surfaceContainerHighest,
            trackHeight: 4.0,
            thumbColor: colorScheme.primary,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 6.0,
              elevation: 2.0,
            ),
            overlayColor: colorScheme.primary.withValues(alpha: 0.12),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18.0),
            tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 1.0),
            activeTickMarkColor: colorScheme.onPrimary.withValues(alpha: 0.5),
            inactiveTickMarkColor: colorScheme.onSurfaceVariant.withValues(
              alpha: 0.3,
            ),
            valueIndicatorColor: colorScheme.primary,
            valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
            valueIndicatorTextStyle: TextStyle(
              color: colorScheme.onPrimary,
              fontSize: 12.0,
            ),
            showValueIndicator: ShowValueIndicator.onlyForDiscrete,
          ),
          child: Slider(
            min: 0,
            max: hourCount - 1.0,
            divisions: hourCount - 1,
            value: currentValue.clamp(0, hourCount - 1.0),
            onChanged: onChanged,
            label: _formatTimeLabel(hourLabels[currentValue.round()]),
          ),
        ),

        // Time markers below the slider
        SizedBox(height: 16, child: _buildTimeMarkers(context)),
      ],
    );
  }

  /// Formats the time label for the value indicator
  String _formatTimeLabel(DateTime time) {
    return DateFormat('h:mm a').format(time);
  }

  /// Builds the time markers (AM/PM indicators)
  Widget _buildTimeMarkers(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodySmall;
    final markerStyle = textStyle?.copyWith(
      fontSize: 10,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    // We'll place markers for key times (12 AM, 6 AM, 12 PM, 6 PM)
    return Stack(
      children: [
        // AM marker
        if (_hasHourInRange(0, 2))
          Positioned(left: 0, child: Text('12 AM', style: markerStyle)),

        // 6 AM marker
        if (_hasHourInRange(5, 7))
          Positioned(
            left: _calculateMarkerPosition(6),
            child: Text('6 AM', style: markerStyle),
          ),

        // Noon marker
        if (_hasHourInRange(11, 13))
          Positioned(
            left: _calculateMarkerPosition(12),
            child: Text('Noon', style: markerStyle),
          ),

        // 6 PM marker
        if (_hasHourInRange(17, 19))
          Positioned(
            left: _calculateMarkerPosition(18),
            child: Text('6 PM', style: markerStyle),
          ),

        // Midnight marker if we have late hours
        if (_hasHourInRange(22, 24))
          Positioned(right: 0, child: Text('12 AM', style: markerStyle)),
      ],
    );
  }

  /// Checks if we have data for an hour in the given range
  bool _hasHourInRange(int minHour, int maxHour) {
    return hourLabels.any(
      (time) => time.hour >= minHour && time.hour < maxHour,
    );
  }

  /// Calculates the position for a time marker
  double _calculateMarkerPosition(int targetHour) {
    // Find the closest hour to the target hour
    DateTime? closestTime;
    int smallestDifference = 24;

    for (final time in hourLabels) {
      final difference = (time.hour - targetHour).abs();
      if (difference < smallestDifference) {
        smallestDifference = difference;
        closestTime = time;
      }
    }

    if (closestTime == null) return 0;

    // Calculate the index of this time in our list
    final index = hourLabels.indexOf(closestTime);
    if (index < 0) return 0;

    // Convert to percentage of width
    return (index / (hourCount - 1) * 100).clamp(0, 100);
  }
}
