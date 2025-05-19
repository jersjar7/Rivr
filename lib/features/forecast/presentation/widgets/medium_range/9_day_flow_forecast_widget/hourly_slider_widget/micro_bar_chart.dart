// lib/features/forecast/presentation/widgets/medium_range/9_day_flow_forecast_widget/hourly_slider_widget/micro_bar_chart.dart

import 'package:flutter/material.dart';
import 'package:rivr/core/models/flow_unit.dart'; // Import for FlowUnit
import 'package:rivr/core/services/flow_units_service.dart'; // Import the service
import 'package:rivr/features/forecast/domain/entities/return_period.dart';
import 'package:rivr/features/forecast/utils/flow_thresholds.dart';

/// A micro bar chart that displays hourly flow data
class MicroBarChart extends StatelessWidget {
  final List<MapEntry<DateTime, double>> hourlyData;
  final int selectedIndex;
  final double minValue;
  final double maxValue;
  final ReturnPeriod? returnPeriod;
  final FlowUnit fromUnit; // Add parameter for source unit
  final FlowUnitsService? flowUnitsService; // Optional service for conversions

  const MicroBarChart({
    super.key,
    required this.hourlyData,
    required this.selectedIndex,
    required this.minValue,
    required this.maxValue,
    this.returnPeriod,
    this.fromUnit = FlowUnit.cfs, // Default to CFS as source unit
    this.flowUnitsService, // Optional service for unit conversions
  });

  /// Gets the appropriate color for a flow value
  Color _getColorForFlow(double flow, ReturnPeriod returnPeriod) {
    final category = returnPeriod.getFlowCategory(flow, fromUnit: fromUnit);
    return FlowThresholds.getColorForCategory(category);
  }

  @override
  Widget build(BuildContext context) {
    if (hourlyData.isEmpty) {
      return Container(); // Empty container if no data
    }

    // For a single data point, we need a special case
    if (hourlyData.length == 1) {
      final theme = Theme.of(context);
      final colorScheme = theme.colorScheme;

      // Get the color for the single bar
      final flow = hourlyData.first.value;
      final Color barColor =
          returnPeriod != null
              ? _getColorForFlow(flow, returnPeriod!)
              : colorScheme.primary;

      return Center(
        child: Container(
          width: 20, // Single wide bar
          height: 80, // Fixed height
          decoration: BoxDecoration(
            color: barColor.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: barColor, width: 1),
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Grid line colors should be theme aware
    final gridLineColor =
        isDark ? colorScheme.surfaceContainerHighest : Colors.grey[400];

    return CustomPaint(
      painter: _MicroBarChartPainter(
        hourlyData: hourlyData,
        selectedIndex: selectedIndex,
        minValue: minValue,
        maxValue: maxValue,
        returnPeriod: returnPeriod,
        gridLineColor: gridLineColor!,
        primaryColor: colorScheme.primary,
        surfaceColor: colorScheme.surface,
        isDark: isDark,
        fromUnit: fromUnit, // Pass the source unit
        flowUnitsService: flowUnitsService, // Pass the service for conversions
      ),
      child: Container(), // Size is controlled by parent
    );
  }
}

class _MicroBarChartPainter extends CustomPainter {
  final List<MapEntry<DateTime, double>> hourlyData;
  final int selectedIndex;
  final double minValue;
  final double maxValue;
  final ReturnPeriod? returnPeriod;
  final Color gridLineColor;
  final Color primaryColor;
  final Color surfaceColor;
  final bool isDark;
  final FlowUnit fromUnit; // Source unit for flow values
  final FlowUnitsService? flowUnitsService; // Service for unit conversions

  _MicroBarChartPainter({
    required this.hourlyData,
    required this.selectedIndex,
    required this.minValue,
    required this.maxValue,
    this.returnPeriod,
    required this.gridLineColor,
    required this.primaryColor,
    required this.surfaceColor,
    required this.isDark,
    this.fromUnit = FlowUnit.cfs, // Default to CFS
    this.flowUnitsService, // Optional service
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double barWidth = size.width / hourlyData.length;
    final double maxBarHeight = size.height - 10; // Leave space for guides

    // Draw horizontal guide lines (subtle)
    _drawGuideLines(canvas, size, maxBarHeight);

    // Draw each bar
    for (int i = 0; i < hourlyData.length; i++) {
      final flow = hourlyData[i].value;
      // No need to convert flow here as min/max values should already be in the correct unit
      // This is assuming upstream components properly convert min/max values

      // Calculate normalized height
      final normValue = (flow - minValue) / (maxValue - minValue);
      final double barHeight = (normValue.clamp(0.0, 1.0) * maxBarHeight).clamp(
        2.0,
        maxBarHeight,
      );

      // Calculate position
      final double left = i * barWidth;
      final double top = size.height - barHeight;
      final double right =
          left +
          (barWidth * 0.7); // Make bars slightly narrower than full width
      final double bottom = size.height;

      // Create the bar rectangle
      final rect = Rect.fromLTRB(left, top, right, bottom);

      // Get the color based on flow category
      final Color barColor = _getColorForFlow(flow);

      // Determine if this is the selected bar
      final isSelected = i == selectedIndex;

      // Create paint object
      final paint =
          Paint()
            ..color =
                isSelected
                    ? barColor.withValues(
                      alpha: 1.0,
                    ) // Full opacity for selected
                    : barColor.withValues(
                      alpha: 0.6,
                    ); // Slightly transparent for others

      // Draw the bar
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2.0)),
        paint,
      );

      // Draw selection highlight
      if (isSelected) {
        // Draw a highlight border around the selected bar
        final highlightPaint =
            Paint()
              ..color = isDark ? Colors.white70 : Colors.black54
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5;

        final highlightRect = Rect.fromLTRB(
          left - 1,
          top - 1,
          right + 1,
          bottom + 1,
        );

        canvas.drawRRect(
          RRect.fromRectAndRadius(highlightRect, const Radius.circular(3.0)),
          highlightPaint,
        );
      }
    }
  }

  /// Draws subtle guide lines across the chart
  void _drawGuideLines(Canvas canvas, Size size, double maxBarHeight) {
    final linePaint =
        Paint()
          ..color = gridLineColor
          ..strokeWidth = 0.5;

    // Draw a few guide lines (25%, 50%, 75%, 100%)
    final linePositions = [0.25, 0.5, 0.75, 1.0];

    for (final position in linePositions) {
      final y = size.height - (maxBarHeight * position);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  /// Gets the appropriate color for a flow value - with proper unit handling
  Color _getColorForFlow(double flow) {
    if (returnPeriod != null) {
      // Use the proper getFlowCategory method that handles unit conversions
      final category = returnPeriod!.getFlowCategory(flow, fromUnit: fromUnit);
      return FlowThresholds.getColorForCategory(category);
    } else {
      // Fallback to a gradient if no return period data
      final normalizedValue = (flow - minValue) / (maxValue - minValue);
      return _getGradientColor(normalizedValue.clamp(0.0, 1.0));
    }
  }

  /// Creates a gradient color based on normalized value (0-1)
  Color _getGradientColor(double normalizedValue) {
    // Blue (low) to green (normal) to yellow (moderate) to orange to red (high)
    if (normalizedValue < 0.2) {
      return Colors.blue;
    } else if (normalizedValue < 0.4) {
      return Colors.green;
    } else if (normalizedValue < 0.6) {
      return Colors.yellow;
    } else if (normalizedValue < 0.8) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  @override
  bool shouldRepaint(_MicroBarChartPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.hourlyData != hourlyData ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue;
  }
}
