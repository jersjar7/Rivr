// lib/features/forecast/presentation/widgets/medium_range/9_day_flow_forecast_widget/flow_range_bar.dart

import 'package:flutter/material.dart';
import 'package:rivr/core/models/flow_unit.dart'; // Import for FlowUnit
import 'package:rivr/core/services/flow_units_service.dart'; // Import the service
import 'package:rivr/features/forecast/domain/entities/return_period.dart';
import 'package:rivr/features/forecast/presentation/widgets/medium_range/9_day_flow_forecast_widget/forecast_data_processor.dart';
import 'package:rivr/features/forecast/utils/flow_thresholds.dart';

/// A horizontal bar that represents the flow range for a day
class FlowRangeBar extends StatelessWidget {
  final DailyFlowForecast forecast;
  final double minFlowBound;
  final double maxFlowBound;
  final double height;
  final ReturnPeriod? returnPeriod;
  final FlowUnit fromUnit; // Add parameter for source unit
  final FlowUnitsService?
  flowUnitsService; // Optional service for unit conversions

  const FlowRangeBar({
    super.key,
    required this.forecast,
    required this.minFlowBound,
    required this.maxFlowBound,
    this.height = 6.0,
    this.returnPeriod,
    this.fromUnit = FlowUnit.cfs, // Default to CFS
    this.flowUnitsService, // Optional flow units service
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

    // Get flow values - no need to convert if the DailyFlowForecast already has the correct unit
    // or if minFlowBound/maxFlowBound are already in the correct unit (they should be)
    double minFlow = forecast.minFlow;
    double maxFlow = forecast.maxFlow;

    // Calculate normalized positions (0-1) for min and max flow
    final normalizedMin = ((minFlow - minFlowBound) / range).clamp(0.0, 1.0);
    final normalizedMax = ((maxFlow - minFlowBound) / range).clamp(0.0, 1.0);

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
                color: Colors.grey.withValues(alpha: 0.2),
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
    // Get colors for min and max flow - being explicit about unit conversion
    Color minColor = Colors.blue;
    Color maxColor = Colors.blue;

    if (returnPeriod != null) {
      // Pass the source unit for proper category determination
      final minCategory = returnPeriod!.getFlowCategory(
        forecast.minFlow,
        fromUnit: fromUnit, // Be explicit about the source unit
      );
      final maxCategory = returnPeriod!.getFlowCategory(
        forecast.maxFlow,
        fromUnit: fromUnit, // Be explicit about the source unit
      );

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
        borderRadius: BorderRadius.circular(3),
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
      // Get threshold in correct unit
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
