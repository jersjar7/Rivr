// lib/features/forecast/presentation/widgets/app_bar_unit_selector.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/models/flow_unit.dart';
import '../../../../core/services/flow_units_service.dart';

/// A compact unit selector for use in app bars or other tight spaces
class AppBarUnitSelector extends StatelessWidget {
  /// Optional callback for when unit changes
  final Function(FlowUnit)? onUnitChanged;

  /// Whether to show as button (true) or simple display (false)
  final bool actionable;

  const AppBarUnitSelector({
    super.key,
    this.onUnitChanged,
    this.actionable = true,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<FlowUnitsService>(
      builder: (context, service, _) {
        final unit = service.preferredUnit;

        if (!actionable) {
          // Simple display with no action
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              unit.shortName,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          );
        }

        // Button with action
        return TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          onPressed: () {
            final newUnit = unit == FlowUnit.cfs ? FlowUnit.cms : FlowUnit.cfs;
            service.setPreferredUnit(newUnit);
            if (onUnitChanged != null) {
              onUnitChanged!(newUnit);
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                unit.shortName,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 4),
              Icon(Icons.swap_horiz, size: 16),
            ],
          ),
        );
      },
    );
  }
}
