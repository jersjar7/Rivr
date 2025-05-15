// lib/features/forecast/presentation/widgets/medium_range/daily_flow_forecast/flow_range_bar.dart

import 'package:flutter/material.dart';
import 'package:rivr/features/forecast/domain/entities/return_period.dart';
import 'package:rivr/features/forecast/presentation/widgets/medium_range/daily_flow_forecast/forecast_data_processor.dart';
import 'package:rivr/features/forecast/utils/flow_thresholds.dart';

/// A horizontal bar that represents the flow range for a day
class FlowRangeBar extends StatelessWidget {
  final DailyFlowForecast forecast;
  final double minFlowBound;
  final double maxFlowBound;
  final double height;
  final ReturnPeriod? returnPeriod;

  const FlowRangeBar({
    super.key,
    required this.forecast,
    required this.minFlowBound,
    required this.maxFlowBound,
    this.height = 6.0,
    this.returnPeriod,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate normalized positions (0-1) for min and max flow
    final range = maxFlowBound - minFlowBound;

    // Avoid division by zero
    if (range <= 0) {
      return Container(
        height: height,
        color: Colors.grey.withValues(alpha: 0.3),
      );
    }

    final normalizedMin = ((forecast.minFlow - minFlowBound) / range).clamp(
      0.0,
      1.0,
    );
    final normalizedMax = ((forecast.maxFlow - minFlowBound) / range).clamp(
      0.0,
      1.0,
    );

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
      ),
      clipBehavior: Clip.hardEdge,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final minPos = normalizedMin * totalWidth;
          final maxPos = normalizedMax * totalWidth;

          return Stack(
            children: [
              // Background track
              Container(
                width: totalWidth,
                height: height,
                color: Colors.grey.withValues(alpha: 0.3),
              ),

              // Range bar with gradient
              Positioned(
                left: minPos,
                width: maxPos - minPos,
                child: _buildRangeBar(),
              ),

              // Return period threshold markers
              if (returnPeriod != null) ..._buildThresholdMarkers(totalWidth),
            ],
          );
        },
      ),
    );
  }

  /// Build the colored range bar with gradient
  Widget _buildRangeBar() {
    // Get colors for min and max flow
    Color minColor = Colors.blue;
    Color maxColor = Colors.blue;

    if (returnPeriod != null) {
      final minCategory = returnPeriod!.getFlowCategory(forecast.minFlow);
      final maxCategory = returnPeriod!.getFlowCategory(forecast.maxFlow);
      minColor = FlowThresholds.getColorForCategory(minCategory);
      maxColor = FlowThresholds.getColorForCategory(maxCategory);
    } else {
      // Fallback gradient if no return period data
      minColor = forecast.categoryColor.withValues(alpha: 0.7);
      maxColor = forecast.categoryColor;
    }

    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [minColor, maxColor],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
    );
  }

  /// Build markers for return period thresholds
  List<Widget> _buildThresholdMarkers(double totalWidth) {
    final markers = <Widget>[];
    final range = maxFlowBound - minFlowBound;

    // Only show threshold markers within our min/max range
    for (final year in [2, 5, 10, 25, 50, 100]) {
      final threshold = returnPeriod!.getFlowForYear(year);
      if (threshold == null) continue;

      // Only show if within our display range
      if (threshold >= minFlowBound && threshold <= maxFlowBound) {
        final normalized = ((threshold - minFlowBound) / range).clamp(0.0, 1.0);
        final xPos = normalized * totalWidth;

        markers.add(
          Positioned(
            left: xPos - 1, // Center the 2px wide marker
            child: Container(
              width: 2,
              height: height,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        );
      }
    }

    return markers;
  }
}
