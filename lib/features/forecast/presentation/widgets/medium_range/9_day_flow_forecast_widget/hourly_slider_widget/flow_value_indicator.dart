// lib/features/forecast/presentation/widgets/medium_range/9_day_flow_forecast_widget/hourly_slider_widget/flow_value_indicator.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rivr/core/formatters/flow_value_formatter.dart';
import 'package:rivr/core/services/flow_units_service.dart';
import 'package:rivr/features/forecast/domain/entities/return_period.dart';
import 'package:rivr/features/forecast/utils/flow_thresholds.dart';

/// A circular indicator that displays the flow value for a selected hour
class FlowValueIndicator extends StatelessWidget {
  final double? flowValue;
  final DateTime? time;
  final String? flowCategory;
  final ReturnPeriod? returnPeriod;
  final NumberFormat? flowFormatter; // Keep for backward compatibility
  final FlowValueFormatter?
  flowValueFormatter; // Add support for FlowValueFormatter

  const FlowValueIndicator({
    super.key,
    this.flowValue,
    this.time,
    this.flowCategory,
    this.returnPeriod,
    this.flowFormatter,
    this.flowValueFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    // Get formatters - either from props or from context
    final FlowValueFormatter valueFormatter =
        flowValueFormatter ?? Provider.of<FlowValueFormatter>(context);
    final FlowUnitsService unitsService = Provider.of<FlowUnitsService>(
      context,
    );

    // If no flow value, show placeholder
    if (flowValue == null || time == null) {
      return _buildEmptyIndicator(context);
    }

    // Get color based on flow category
    final Color borderColor = _getColorForFlow(flowValue!);

    // Format time
    final String timeStr = DateFormat('h:mm a').format(time!);

    // Container size
    const double containerSize = 90.0;

    return Container(
      width: containerSize,
      height: containerSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).cardColor,
        border: Border.all(color: borderColor, width: 3.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Flow value - use FlowValueFormatter for formatting
            Text(
              valueFormatter.formatNumberOnly(flowValue!),
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            // Unit
            Text(
              unitsService.unitLabel,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),

            // Time
            Text(
              timeStr,
              style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds an empty placeholder indicator
  Widget _buildEmptyIndicator(BuildContext context) {
    final theme = Theme.of(context);
    const double containerSize = 80.0;

    return Container(
      width: containerSize,
      height: containerSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).cardColor,
        border: Border.all(color: theme.colorScheme.outline, width: 2.0),
      ),
      child: Center(
        child: Text(
          'No Data',
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// Gets the appropriate color for a flow value
  Color _getColorForFlow(double flow) {
    if (flowCategory != null) {
      return FlowThresholds.getColorForCategory(flowCategory!);
    } else if (returnPeriod != null) {
      final category = returnPeriod!.getFlowCategory(flow);
      return FlowThresholds.getColorForCategory(category);
    } else {
      // Fallback color if no category info available
      return Colors.blue;
    }
  }
}
