// lib/features/forecast/presentation/widgets/card_flow_value.dart

import 'package:flutter/material.dart';
import 'package:rivr/core/models/flow_unit.dart';
import 'package:rivr/core/services/flow_units_service.dart';
import 'package:rivr/core/formatters/flow_value_formatter.dart';
import 'package:rivr/features/forecast/utils/format_large_number.dart';

/// Widget that displays flow value in a space-efficient manner
class FlowValueDisplay extends StatelessWidget {
  final double flow;
  final Color color;
  final double containerWidth;
  final double containerHeight;
  final FlowUnitsService? flowUnitsService;
  final FlowValueFormatter? flowFormatter;
  final FlowUnit? fromUnit;

  const FlowValueDisplay({
    super.key,
    required this.flow,
    required this.color,
    this.containerWidth = 60.0,
    this.containerHeight = 60.0,
    this.flowUnitsService,
    this.flowFormatter,
    this.fromUnit = FlowUnit.cfs, // Default assumes flow is in CFS
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    // Format the flow value based on provided services or fallback to old method
    String formattedFlow;
    String unitLabel;

    if (flowFormatter != null) {
      // Use the provided flow formatter (preferred)
      formattedFlow = flowFormatter!.formatNumberOnly(flow);
      unitLabel = flowFormatter!.unitString;
    } else if (flowUnitsService != null) {
      // Convert and format using flow units service
      double displayFlow = flow;

      // Convert if needed and fromUnit is provided
      if (fromUnit != null && fromUnit != flowUnitsService!.preferredUnit) {
        displayFlow = flowUnitsService!.convertToPreferredUnit(flow, fromUnit!);
      }

      // Format number without units
      formattedFlow = formatLargeNumber(displayFlow);
      unitLabel = flowUnitsService!.unitLabel;
    } else {
      // Fallback to original implementation
      formattedFlow = formatLargeNumber(flow);
      unitLabel = 'ft³/s';
    }

    // Always maintain the circular container with dynamic colors
    return Container(
      width: containerWidth,
      height: containerHeight,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.2),
        border: Border.all(color: color, width: 2),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                formattedFlow,
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                unitLabel,
                style: textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
