// lib/features/forecast/presentation/widgets/card_flow_value.dart

import 'package:flutter/material.dart';

/// Helper function to format flow values compactly
String formatFlowCompact(double flow) {
  if (flow >= 1000000) {
    return '${(flow / 1000000).toStringAsFixed(1)}M';
  } else if (flow >= 10000) {
    return '${(flow / 1000).toStringAsFixed(1)}K';
  } else {
    return flow.toInt().toString();
  }
}

/// Widget that displays flow value in a space-efficient manner
class FlowValueDisplay extends StatelessWidget {
  final double flow;
  final double containerWidth;
  final double containerHeight;

  const FlowValueDisplay({
    super.key,
    required this.flow,
    this.containerWidth = 56.0,
    this.containerHeight = 56.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    // Format the flow value compactly
    final String formattedFlow = formatFlowCompact(flow);

    // For very large numbers, arrange horizontally instead of vertically
    final bool useHorizontalLayout = flow >= 100000;

    if (useHorizontalLayout) {
      // Horizontal layout for very large numbers
      return Container(
        width: containerWidth,
        height: containerHeight,
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formattedFlow,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.only(bottom: 2.0),
                child: Text('ft³/s', style: textTheme.bodySmall),
              ),
            ],
          ),
        ),
      );
    } else {
      // Vertical layout for smaller numbers
      return Container(
        width: containerWidth,
        height: containerHeight,
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                formattedFlow,
                style: textTheme.bodyLarge?.copyWith(
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
      );
    }
  }
}
