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

    // Get the earliest and latest hour in our data
    if (hourLabels.isEmpty) return const SizedBox.shrink();

    final DateTime firstTime = hourLabels.first;
    final DateTime lastTime = hourLabels.last;

    // Calculate the total time span in hours (might span multiple days)
    final int totalHours = lastTime.difference(firstTime).inHours;
    if (totalHours <= 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Fixed positions regardless of available data
        return Stack(
          children: [
            // Start marker (first hour)
            Positioned(
              left: 0,
              child: Text(
                DateFormat('h a').format(firstTime),
                style: markerStyle,
              ),
            ),

            // Middle marker (halfway point)
            if (totalHours >= 6)
              Positioned(
                left: constraints.maxWidth / 2,
                child: Text(
                  DateFormat(
                    'h a',
                  ).format(firstTime.add(Duration(hours: totalHours ~/ 2))),
                  style: markerStyle,
                  textAlign: TextAlign.center,
                ),
              ),

            // End marker (last hour)
            Positioned(
              right: 0,
              child: Text(
                DateFormat('h a').format(lastTime),
                style: markerStyle,
              ),
            ),
          ],
        );
      },
    );
  }
}
