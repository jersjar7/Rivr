// lib/features/forecast/presentation/widgets/medium_range/daily_flow_forecast/daily_forecast_row.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rivr/features/forecast/domain/entities/return_period.dart';
import 'package:rivr/features/forecast/presentation/widgets/medium_range/daily_flow_forecast/flow_condition_icon.dart';
import 'package:rivr/features/forecast/presentation/widgets/medium_range/daily_flow_forecast/flow_range_bar.dart';
import 'package:rivr/features/forecast/presentation/widgets/medium_range/daily_flow_forecast/forecast_data_processor.dart';

/// A widget that displays a single day's forecast as a row
class DailyForecastRow extends StatelessWidget {
  final DailyFlowForecast forecast;
  final double minFlowBound;
  final double maxFlowBound;
  final bool isToday;
  final NumberFormat flowFormatter;
  final ReturnPeriod? returnPeriod;
  final VoidCallback? onTap;
  final bool isSelected;

  DailyForecastRow({
    super.key,
    required this.forecast,
    required this.minFlowBound,
    required this.maxFlowBound,
    this.isToday = false,
    NumberFormat? flowFormatter,
    this.returnPeriod,
    this.onTap,
    this.isSelected = false,
  }) : flowFormatter = flowFormatter ?? NumberFormat('#,##0');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    // Get day label (Today, Tomorrow, or weekday)
    final dayLabel = ForecastDataProcessor.getDayLabel(forecast.date, isToday);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                  : null,
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // Day label (left-aligned)
            SizedBox(
              width: 90,
              child: Text(
                dayLabel,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),

            // Flow icon with data source badge
            Stack(
              children: [
                FlowConditionIcon(
                  flowCategory: forecast.flowCategory,
                  size: 24,
                  withBackground: true,
                ),
              ],
            ),

            const SizedBox(width: 40),

            // Flow values and range bar
            Expanded(
              child: Row(
                children: [
                  // Minimum flow value
                  Text(
                    flowFormatter.format(forecast.minFlow),
                    style: textTheme.bodyMedium?.copyWith(
                      fontSize: 16,
                      color:
                          isToday
                              ? colorScheme.primary
                              : colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Flow range bar
                  Expanded(
                    child: FlowRangeBar(
                      forecast: forecast,
                      minFlowBound: minFlowBound,
                      maxFlowBound: maxFlowBound,
                      height: 7.0,
                      returnPeriod: returnPeriod,
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Maximum flow value
                  Text(
                    flowFormatter.format(forecast.maxFlow),
                    style: textTheme.bodyMedium?.copyWith(
                      fontSize: 16,
                      color:
                          isToday
                              ? colorScheme.primary
                              : colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An expandable version of the daily forecast row with additional details
class ExpandableDailyForecastRow extends StatefulWidget {
  final DailyFlowForecast forecast;
  final double minFlowBound;
  final double maxFlowBound;
  final bool isToday;
  final NumberFormat flowFormatter;
  final ReturnPeriod? returnPeriod;
  final bool isExpanded;
  final Function(bool)? onExpandChanged;

  ExpandableDailyForecastRow({
    super.key,
    required this.forecast,
    required this.minFlowBound,
    required this.maxFlowBound,
    this.isToday = false,
    NumberFormat? flowFormatter,
    this.returnPeriod,
    this.isExpanded = false,
    this.onExpandChanged,
  }) : flowFormatter = flowFormatter ?? NumberFormat('#,##0');

  @override
  State<ExpandableDailyForecastRow> createState() =>
      _ExpandableDailyForecastRowState();
}

class _ExpandableDailyForecastRowState
    extends State<ExpandableDailyForecastRow> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isExpanded;
  }

  @override
  void didUpdateWidget(ExpandableDailyForecastRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isExpanded != widget.isExpanded) {
      _isExpanded = widget.isExpanded;
    }
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (widget.onExpandChanged != null) {
        widget.onExpandChanged!(_isExpanded);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Standard row with tap to expand
        GestureDetector(
          onTap: _toggleExpanded,
          child: DailyForecastRow(
            forecast: widget.forecast,
            minFlowBound: widget.minFlowBound,
            maxFlowBound: widget.maxFlowBound,
            isToday: widget.isToday,
            flowFormatter: widget.flowFormatter,
            returnPeriod: widget.returnPeriod,
            isSelected: _isExpanded,
          ),
        ),

        // Expandable details section
        AnimatedCrossFade(
          firstChild: const SizedBox(height: 0),
          secondChild: _buildDetailsView(),
          crossFadeState:
              _isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
        ),
      ],
    );
  }

  Widget _buildDetailsView() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Format the date for the header
    final dateStr = DateFormat(
      'EEEE, MMMM d, yyyy',
    ).format(widget.forecast.date);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date and flow status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(dateStr, style: theme.textTheme.titleSmall),
              Text(
                'Flow: ${widget.forecast.flowCategory}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: widget.forecast.categoryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Flow statistics
          _buildStatRow(
            'Min Flow',
            widget.flowFormatter.format(widget.forecast.minFlow),
            Colors.blue,
          ),
          _buildStatRow(
            'Max Flow',
            widget.flowFormatter.format(widget.forecast.maxFlow),
            Colors.red,
          ),
          _buildStatRow(
            'Avg Flow',
            widget.flowFormatter.format(widget.forecast.avgFlow),
            Colors.purple,
          ),

          const SizedBox(height: 8),

          // Data source info
          Row(
            children: [
              const Icon(Icons.info_outline, size: 16),
              const SizedBox(width: 8),
              Text(
                'Data source: ${widget.forecast.dataSource}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),

          // Here you could add more detailed information or a small chart
          // showing hourly values throughout the day
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 8),
              Text(label),
            ],
          ),
          Text(
            '$value ft³/s',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
