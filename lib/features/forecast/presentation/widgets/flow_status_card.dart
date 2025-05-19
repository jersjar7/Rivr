// lib/features/forecast/presentation/widgets/flow_status_card.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rivr/core/formatters/flow_value_formatter.dart';
import 'package:rivr/core/models/flow_unit.dart';
import 'package:rivr/core/services/flow_units_service.dart';
import 'package:rivr/features/forecast/domain/entities/forecast.dart';
import 'package:rivr/features/forecast/domain/entities/return_period.dart';
import 'package:rivr/features/forecast/presentation/widgets/flow_indicator_bar.dart';
import 'package:rivr/features/forecast/utils/flow_thresholds.dart';

class FlowStatusCard extends StatefulWidget {
  final Forecast? currentFlow;
  final ReturnPeriod? returnPeriod;
  final double? historicalAverage; // Optional historical average flow
  final VoidCallback? onTap;
  final bool expanded;
  final FlowUnit sourceUnit; // Source unit for flow values

  const FlowStatusCard({
    super.key,
    required this.currentFlow,
    this.returnPeriod,
    this.historicalAverage,
    this.onTap,
    this.expanded = false,
    this.sourceUnit = FlowUnit.cfs, // Default source unit is CFS
  });

  @override
  State<FlowStatusCard> createState() => _FlowStatusCardState();
}

class _FlowStatusCardState extends State<FlowStatusCard> {
  late final FlowUnitsService _flowUnitsService;
  late final FlowValueFormatter _flowFormatter;
  bool _returnPeriodExpanded = false;

  @override
  void initState() {
    super.initState();
    // Initialize unit services
    _flowUnitsService = Provider.of<FlowUnitsService>(context, listen: false);
    _flowFormatter = Provider.of<FlowValueFormatter>(context, listen: false);

    // Listen for unit changes
    _flowUnitsService.addListener(_onUnitChanged);
  }

  @override
  void dispose() {
    // Remove listener when disposed
    _flowUnitsService.removeListener(_onUnitChanged);
    super.dispose();
  }

  // Handle unit changes
  void _onUnitChanged() {
    if (mounted) {
      setState(() {
        // Just rebuild the UI with new units
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    // Get current theme to adapt colors
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // If we don't have flow data yet, show loading
    if (widget.currentFlow == null) {
      return _buildLoadingCard(context);
    }

    // Convert flow to preferred unit if needed
    final flow = _flowUnitsService.convertToPreferredUnit(
      widget.currentFlow!.flow,
      widget.sourceUnit,
    );

    final String category =
        widget.returnPeriod?.getFlowCategory(flow) ?? 'Unknown';
    final Color statusColor = FlowThresholds.getColorForCategory(category);
    final String statusDescription =
        widget.returnPeriod != null
            ? FlowThresholds.getFlowSummary(flow, widget.returnPeriod!)
            : 'Flow information unavailable';

    // Calculate percentage comparison with historical average
    String comparisonText = '';
    if (widget.historicalAverage != null && widget.historicalAverage! > 0) {
      // Convert historical average to preferred unit if needed
      final convertedHistAvg = _flowUnitsService.convertToPreferredUnit(
        widget.historicalAverage!,
        widget.sourceUnit,
      );

      final percentDiff =
          ((flow - convertedHistAvg) / convertedHistAvg * 100).round();
      if (percentDiff > 0) {
        comparisonText = '$percentDiff% above normal';
      } else if (percentDiff < 0) {
        comparisonText = '${percentDiff.abs()}% below normal';
      } else {
        comparisonText = 'at normal level';
      }
    }

    // Card colors - adapt to theme
    final Color cardColor =
        isDark ? colorScheme.secondary : colorScheme.secondary;
    final Color cardColorDark =
        isDark
            ? colorScheme.secondaryContainer
            : colorScheme.secondary.withValues(alpha: 0.7);
    final Color textColor =
        Colors
            .white; // Text should be white in both themes on this colored card

    return GestureDetector(
      onTap: widget.onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [cardColor, cardColorDark],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Current Flow',
                      style: theme.textTheme.bodyLarge!.copyWith(
                        color: textColor,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Current flow value
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _flowFormatter.format(flow),
                      style: theme.textTheme.displaySmall!.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Padding(padding: const EdgeInsets.only(bottom: 6.0)),
                    if (comparisonText.isNotEmpty) const Spacer(),
                    if (comparisonText.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: textColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          comparisonText,
                          style: theme.textTheme.bodyMedium!.copyWith(
                            color:
                                flow >
                                        _flowUnitsService
                                            .convertToPreferredUnit(
                                              widget.historicalAverage!,
                                              widget.sourceUnit,
                                            )
                                    ? (isDark
                                        ? Colors.amber
                                        : Colors
                                            .orange) // Different colors for light/dark
                                    : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 16),

                // Flow indicator bar
                if (widget.returnPeriod != null)
                  Center(
                    child: FlowIndicatorBar(
                      currentFlow: flow,
                      returnPeriod: widget.returnPeriod,
                      width: MediaQuery.of(context).size.width * 0.8,
                    ),
                  ),

                const SizedBox(height: 8),

                // Historical comparison with proper unit handling
                if (widget.historicalAverage != null)
                  Row(
                    children: [
                      Icon(
                        Icons.history,
                        color: textColor.withValues(alpha: 0.7),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Historical Average: ${_flowFormatter.formatNumberOnly(_flowUnitsService.convertToPreferredUnit(widget.historicalAverage!, widget.sourceUnit))} ${_flowUnitsService.unitLabel}',
                        style: theme.textTheme.bodyMedium!.copyWith(
                          color: textColor.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),

                // Additional information in expanded mode
                if (widget.expanded) ...[
                  // const SizedBox(height: 8),
                  Divider(color: textColor.withValues(alpha: 0.2)),
                  const SizedBox(height: 8),
                  Text(
                    statusDescription,
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Return period information if available - now collapsible
                  if (widget.returnPeriod != null) ...[
                    // Clickable header row with arrow indicator and button styling
                    Material(
                      color: Colors.black.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          setState(() {
                            _returnPeriodExpanded = !_returnPeriodExpanded;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10.0,
                            horizontal: 12.0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Return Period Information',
                                style: theme.textTheme.bodyMedium!.copyWith(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: textColor.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  _returnPeriodExpanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: textColor,
                                  size: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Animation for smooth transition
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      child:
                          _returnPeriodExpanded
                              ? Padding(
                                padding: const EdgeInsets.only(top: 12.0),
                                child: _buildReturnPeriodTable(
                                  widget.returnPeriod!,
                                  textColor,
                                ),
                              )
                              : const SizedBox.shrink(),
                    ),
                  ],
                ] else ...[
                  // Expand button
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: textColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Build a table showing return period flows with proper unit handling
  Widget _buildReturnPeriodTable(ReturnPeriod returnPeriod, Color textColor) {
    final theme = Theme.of(context);
    final rows = <TableRow>[];
    final currentUnit = _flowUnitsService.preferredUnit;

    // Header row
    rows.add(
      TableRow(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: textColor.withValues(alpha: 0.3)),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              'Return Period',
              style: theme.textTheme.bodyMedium!.copyWith(
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              'Flow (${_flowUnitsService.unitLabel})',
              style: theme.textTheme.bodyMedium!.copyWith(
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );

    // Data rows
    for (final year in [2, 5, 10, 25, 50, 100]) {
      // Get flow value and convert to current display unit if needed
      final flow = returnPeriod.getFlowForYear(year, toUnit: currentUnit);

      if (flow != null) {
        rows.add(
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(
                  '$year-year',
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: textColor.withValues(alpha: 0.9),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(
                  _flowFormatter.formatIntegerOnly(flow),
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: textColor.withValues(alpha: 0.9),
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }
    }

    return Table(
      columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1)},
      children: rows,
    );
  }

  // Loading state card
  Widget _buildLoadingCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Card colors - adapt to theme
    final Color cardColor =
        isDark ? colorScheme.secondary : colorScheme.secondary;
    final Color cardColorLight =
        isDark
            ? colorScheme.secondary.withValues(alpha: 0.7)
            : colorScheme.secondary.withValues(alpha: 0.8);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [cardColorLight, cardColor],
          ),
        ),
        height: 180,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading flow data...',
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
