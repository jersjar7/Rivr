// lib/features/forecast/presentation/widgets/medium_range/daily_flow_forecast/flow_condition_icon.dart

import 'package:flutter/material.dart';
import 'package:rivr/features/forecast/utils/flow_thresholds.dart';

/// Widget that displays an appropriate icon based on flow category
class FlowConditionIcon extends StatelessWidget {
  final String flowCategory;
  final double size;
  final bool withBackground;

  const FlowConditionIcon({
    super.key,
    required this.flowCategory,
    this.size = 24.0,
    this.withBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = FlowThresholds.getColorForCategory(flowCategory);

    // Choose icon based on flow category
    IconData iconData;
    switch (flowCategory) {
      case 'Low':
        iconData = Icons.waves_outlined;
      case 'Normal':
        iconData = Icons.waves;
      case 'Moderate':
        iconData = Icons.water;
      case 'Elevated':
        iconData = Icons.arrow_upward;
      case 'High':
        iconData = Icons.warning_outlined;
      case 'Very High':
        iconData = Icons.warning;
      case 'Extreme':
        iconData = Icons.dangerous;
      default:
        iconData = Icons.waves;
    }

    if (withBackground) {
      return Container(
        width: size * 1.5,
        height: size * 1.5,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: Center(child: Icon(iconData, color: color, size: size)),
      );
    }

    return Icon(iconData, color: color, size: size);
  }
}

/// A badge indicating the data source of the forecast
class DataSourceBadge extends StatelessWidget {
  final String dataSource;
  final double size;

  const DataSourceBadge({
    super.key,
    required this.dataSource,
    this.size = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    // Use a different color based on data source
    Color badgeColor;
    String label;

    if (dataSource == 'mean') {
      badgeColor = Colors.blue;
      label = 'M';
    } else if (dataSource.startsWith('member')) {
      badgeColor = Colors.orange;
      // Extract the number from "member1", "member2", etc.
      final memberNumber = dataSource.substring(6);
      label = 'M$memberNumber';
    } else {
      badgeColor = Colors.grey;
      label = '?';
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: badgeColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.7,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
