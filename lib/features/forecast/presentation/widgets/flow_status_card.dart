// lib/features/forecast/presentation/widgets/flow_status_card.dart
import 'package:flutter/material.dart';
import 'package:rivr/features/forecast/domain/entities/forecast.dart';
import 'package:rivr/features/forecast/domain/entities/return_period.dart';
import 'package:rivr/features/forecast/presentation/widgets/FlowIndicatorBar.dart';
import 'package:rivr/features/forecast/utils/flow_thresholds.dart';
import 'package:intl/intl.dart';

class FlowStatusCard extends StatefulWidget {
  final Forecast? currentFlow;
  final ReturnPeriod? returnPeriod;
  final double? historicalAverage; // Optional historical average flow
  final VoidCallback? onTap;
  final bool expanded;

  const FlowStatusCard({
    super.key,
    required this.currentFlow,
    this.returnPeriod,
    this.historicalAverage,
    this.onTap,
    this.expanded = false,
  });

  @override
  State<FlowStatusCard> createState() => _FlowStatusCardState();
}

class _FlowStatusCardState extends State<FlowStatusCard> {
  bool _returnPeriodExpanded = false;

  @override
  Widget build(BuildContext context) {
    // If we don't have flow data yet, show loading
    if (widget.currentFlow == null) {
      return _buildLoadingCard(context);
    }

    final flow = widget.currentFlow!.flow;
    final String category =
        widget.returnPeriod?.getFlowCategory(flow) ?? 'Unknown';
    final Color statusColor = FlowThresholds.getColorForCategory(category);
    final String statusDescription =
        widget.returnPeriod != null
            ? FlowThresholds.getFlowSummary(flow, widget.returnPeriod!)
            : 'Flow information unavailable';

    // Format flow values with NumberFormat
    final NumberFormat flowFormat = NumberFormat('#,##0.0');
    final String formattedFlow = flowFormat.format(flow);
    final String formattedHistorical =
        widget.historicalAverage != null
            ? flowFormat.format(widget.historicalAverage!)
            : 'N/A';

    // Calculate percentage comparison with historical average
    String comparisonText = '';
    if (widget.historicalAverage != null && widget.historicalAverage! > 0) {
      final percentDiff =
          ((flow - widget.historicalAverage!) / widget.historicalAverage! * 100)
              .round();
      if (percentDiff > 0) {
        comparisonText = '$percentDiff% above normal';
      } else if (percentDiff < 0) {
        comparisonText = '${percentDiff.abs()}% below normal';
      } else {
        comparisonText = 'at normal level';
      }
    }

    // Format timestamp
    final String formattedTime = DateFormat(
      'MMM d, h:mm a',
    ).format(widget.currentFlow!.validDateTime);

    final theme = Theme.of(context);
    final surfaceColor = theme.colorScheme.primary;

    return GestureDetector(
      onTap: widget.onTap,
      child: Card(
        color: surfaceColor,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.teal.shade700, Colors.teal.shade900],
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
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: theme.colorScheme.surface,
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
                        style: const TextStyle(
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
                      formattedFlow,
                      style: theme.textTheme.titleLarge!.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Text(
                        'ft³/s',
                        style: theme.textTheme.bodyMedium!.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (comparisonText.isNotEmpty) const Spacer(),
                    if (comparisonText.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          comparisonText,
                          style: theme.textTheme.bodyMedium!.copyWith(
                            color:
                                flow > widget.historicalAverage!
                                    ? Colors.orange
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
                      width: MediaQuery.of(context).size.width * 0.75,
                    ),
                  ),

                // const SizedBox(height: 16),

                // Historical comparison
                if (widget.historicalAverage != null)
                  Row(
                    children: [
                      const Icon(
                        Icons.history,
                        color: Colors.white70,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Historical Average: $formattedHistorical ft³/s',
                        style: theme.textTheme.bodyMedium!.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 8),

                // Timestamp information
                // Row(
                //   children: [
                //     const Icon(
                //       Icons.access_time_rounded,
                //       color: Colors.white70,
                //       size: 18,
                //     ),
                //     const SizedBox(width: 8),
                //     Text(
                //       'As of $formattedTime',
                //       style: const TextStyle(color: Colors.white70),
                //     ),
                //   ],
                // ),

                // Additional information in expanded mode
                if (widget.expanded) ...[
                  const SizedBox(height: 8),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 8),
                  Text(
                    statusDescription,
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: theme.colorScheme.surface,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Return period information if available - now collapsible
                  if (widget.returnPeriod != null) ...[
                    // Clickable header row with arrow indicator and button styling
                    Material(
                      color: Colors.black26,
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
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  _returnPeriodExpanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: theme.colorScheme.onSurfaceVariant,
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
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
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

  // Build a table showing return period flows
  Widget _buildReturnPeriodTable(ReturnPeriod returnPeriod) {
    final theme = Theme.of(context);
    final rows = <TableRow>[];

    // Header row
    rows.add(
      TableRow(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.dividerColor)),
        ),
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              'Return Period',
              style: theme.textTheme.bodyMedium!.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              'Flow (ft³/s)',
              style: theme.textTheme.bodyMedium!.copyWith(
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
      final flow = returnPeriod.getFlowForYear(year);
      if (flow != null) {
        rows.add(
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text('$year-year', style: theme.textTheme.bodyMedium),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(
                  NumberFormat('#,##0.0').format(flow),
                  style: theme.textTheme.bodyMedium,
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
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blueGrey.shade800, Colors.blueGrey.shade900],
          ),
        ),
        height: 180,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
              ),
              SizedBox(height: 16),
              Text(
                'Loading flow data...',
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
