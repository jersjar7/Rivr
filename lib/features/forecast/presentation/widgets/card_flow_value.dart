// lib/features/forecast/presentation/widgets/card_flow_value.dart

import 'package:flutter/material.dart';
import 'package:rivr/features/forecast/utils/format_large_number.dart';

/// Widget that displays flow value in a space-efficient manner
class FlowValueDisplay extends StatelessWidget {
  final double flow;
  final Color color;
  final double containerWidth;
  final double containerHeight;

  const FlowValueDisplay({
    super.key,
    required this.flow,
    required this.color,
    this.containerWidth = 60.0,
    this.containerHeight = 60.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    // Format the flow value compactly
    final String formattedFlow = formatLargeNumber(flow);

    // Always maintain the circular container with dynamic colors
    return Container(
      width: containerWidth,
      height: containerHeight,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.2),
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
                'ft³/s',
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
