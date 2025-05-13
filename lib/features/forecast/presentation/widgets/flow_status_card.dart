// lib/features/forecast/presentation/widgets/flow_status_card.dart
import 'package:flutter/material.dart';
import 'package:rivr/features/forecast/domain/entities/forecast.dart';
import 'package:rivr/features/forecast/domain/entities/return_period.dart';
import 'package:rivr/features/forecast/presentation/widgets/FlowIndicatorBar.dart';
import 'package:rivr/features/forecast/utils/flow_thresholds.dart';
import 'package:intl/intl.dart';

class FlowStatusCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    // If we don't have flow data yet, show loading
    if (currentFlow == null) {
      return _buildLoadingCard(context);
    }

    final flow = currentFlow!.flow;
    final String category = returnPeriod?.getFlowCategory(flow) ?? 'Unknown';
    final Color statusColor = FlowThresholds.getColorForCategory(category);
    final String statusDescription =
        returnPeriod != null
            ? FlowThresholds.getFlowSummary(flow, returnPeriod!)
            : 'Flow information unavailable';

    // Format flow values with NumberFormat
    final NumberFormat flowFormat = NumberFormat('#,##0.0');
    final String formattedFlow = flowFormat.format(flow);
    final String formattedHistorical =
        historicalAverage != null
            ? flowFormat.format(historicalAverage!)
            : 'N/A';

    // Calculate percentage comparison with historical average
    String comparisonText = '';
    if (historicalAverage != null && historicalAverage! > 0) {
      final percentDiff =
          ((flow - historicalAverage!) / historicalAverage! * 100).round();
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
    ).format(currentFlow!.validDateTime);

    return GestureDetector(
      onTap: onTap,
      child: Card(
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
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Current Flow',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 34,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text(
                        'ft³/s',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
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
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          comparisonText,
                          style: TextStyle(
                            color:
                                flow > historicalAverage!
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
                if (returnPeriod != null)
                  Center(
                    child: FlowIndicatorBar(
                      currentFlow: flow,
                      returnPeriod: returnPeriod,
                      width: MediaQuery.of(context).size.width * 0.8,
                    ),
                  ),

                const SizedBox(height: 16),

                // Historical comparison
                if (historicalAverage != null)
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
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),

                const SizedBox(height: 8),

                // Timestamp information
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      color: Colors.white70,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'As of $formattedTime',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),

                // Additional information in expanded mode
                if (expanded) ...[
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 8),
                  Text(
                    statusDescription,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: 16),

                  // Return period information if available
                  if (returnPeriod != null) ...[
                    const Text(
                      'Return Period Information',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildReturnPeriodTable(returnPeriod!),
                  ],
                ] else ...[
                  // Expand button
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white.withValues(alpha: 0.5),
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
    final rows = <TableRow>[];

    // Header row
    rows.add(
      const TableRow(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white24)),
        ),
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              'Return Period',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              'Flow (ft³/s)',
              style: TextStyle(
                color: Colors.white70,
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
                child: Text(
                  '$year-year',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(
                  NumberFormat('#,##0.0').format(flow),
                  style: const TextStyle(color: Colors.white70),
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
    return Card(
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
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              SizedBox(height: 16),
              Text(
                'Loading flow data...',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
