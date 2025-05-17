// lib/features/forecast/presentation/widgets/unit_selector_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/models/flow_unit.dart';
import '../../../../core/services/flow_units_service.dart';

/// A widget for selecting flow measurement units
class UnitSelectorWidget extends StatelessWidget {
  /// Optional callback when unit is changed
  final Function(FlowUnit)? onUnitChanged;

  /// If true, shows as a dropdown instead of a toggle
  final bool useDropdown;

  /// Optional label to display
  final String? label;

  const UnitSelectorWidget({
    super.key,
    this.onUnitChanged,
    this.useDropdown = false,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<FlowUnitsService>(
      builder: (context, unitsService, child) {
        final currentUnit = unitsService.preferredUnit;

        return useDropdown
            ? _buildDropdown(context, unitsService, currentUnit)
            : _buildToggle(context, unitsService, currentUnit);
      },
    );
  }

  /// Builds a dropdown selector for units
  Widget _buildDropdown(
    BuildContext context,
    FlowUnitsService unitsService,
    FlowUnit currentUnit,
  ) {
    final theme = Theme.of(context);

    return Row(
      children: [
        if (label != null) ...[
          Text(label!, style: theme.textTheme.bodyMedium),
          const SizedBox(width: 8),
        ],
        DropdownButton<FlowUnit>(
          value: currentUnit,
          onChanged: (FlowUnit? newValue) {
            if (newValue != null) {
              unitsService.setPreferredUnit(newValue);
              if (onUnitChanged != null) {
                onUnitChanged!(newValue);
              }
            }
          },
          items:
              FlowUnit.values.map((FlowUnit unit) {
                return DropdownMenuItem<FlowUnit>(
                  value: unit,
                  child: Text(unit.shortName),
                );
              }).toList(),
        ),
      ],
    );
  }

  /// Builds a toggle switch for units
  Widget _buildToggle(
    BuildContext context,
    FlowUnitsService unitsService,
    FlowUnit currentUnit,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(label!, style: theme.textTheme.bodyMedium),
          const SizedBox(width: 8),
        ],
        Container(
          height: 36,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // CFS Option
              GestureDetector(
                onTap: () {
                  unitsService.setPreferredUnit(FlowUnit.cfs);
                  if (onUnitChanged != null) {
                    onUnitChanged!(FlowUnit.cfs);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color:
                        currentUnit == FlowUnit.cfs
                            ? colorScheme.primary
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'CFS',
                    style: TextStyle(
                      color:
                          currentUnit == FlowUnit.cfs
                              ? colorScheme.onPrimary
                              : colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),

              // CMS Option
              GestureDetector(
                onTap: () {
                  unitsService.setPreferredUnit(FlowUnit.cms);
                  if (onUnitChanged != null) {
                    onUnitChanged!(FlowUnit.cms);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color:
                        currentUnit == FlowUnit.cms
                            ? colorScheme.primary
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'CMS',
                    style: TextStyle(
                      color:
                          currentUnit == FlowUnit.cms
                              ? colorScheme.onPrimary
                              : colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
