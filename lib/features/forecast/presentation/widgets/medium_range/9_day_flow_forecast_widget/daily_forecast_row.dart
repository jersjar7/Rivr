// lib/features/forecast/presentation/widgets/medium_range/daily_flow_forecast/daily_forecast_row_with_hourly.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rivr/features/forecast/domain/entities/return_period.dart';
import 'package:rivr/features/forecast/presentation/widgets/medium_range/9_day_flow_forecast_widget/flow_condition_icon.dart';
import 'package:rivr/features/forecast/presentation/widgets/medium_range/9_day_flow_forecast_widget/flow_range_bar.dart';
import 'package:rivr/features/forecast/presentation/widgets/medium_range/9_day_flow_forecast_widget/forecast_data_processor.dart';
import 'package:rivr/features/forecast/presentation/widgets/medium_range/9_day_flow_forecast_widget/hourly_slider_widget/hourly_flow_display.dart';

/// An enhanced version of the expandable daily forecast row that includes hourly data
class ExpandableDailyForecastRowWithHourly extends StatefulWidget {
  final DailyFlowForecast forecast;
  final double minFlowBound;
  final double maxFlowBound;
  final bool isToday;
  final NumberFormat? flowFormatter;
  final ReturnPeriod? returnPeriod;
  final bool isExpanded;
  final Function(bool)? onExpandChanged;
  final bool isLastRow;

  const ExpandableDailyForecastRowWithHourly({
    super.key,
    required this.forecast,
    required this.minFlowBound,
    required this.maxFlowBound,
    this.isToday = false,
    this.flowFormatter,
    this.returnPeriod,
    this.isExpanded = false,
    this.onExpandChanged,
    this.isLastRow = false,
  });

  @override
  State<ExpandableDailyForecastRowWithHourly> createState() =>
      _ExpandableDailyForecastRowWithHourlyState();
}

class _ExpandableDailyForecastRowWithHourlyState
    extends State<ExpandableDailyForecastRowWithHourly> {
  late bool _isExpanded;
  late NumberFormat _flowFormatter;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isExpanded;
    _flowFormatter = widget.flowFormatter ?? NumberFormat('#,##0');
  }

  @override
  void didUpdateWidget(ExpandableDailyForecastRowWithHourly oldWidget) {
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
          child: _buildDailyForecastRow(),
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

  /// Builds the daily forecast row (collapsed view)
  Widget _buildDailyForecastRow() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    // Get day label (Today, Tomorrow, or weekday)
    final dayLabel = ForecastDataProcessor.getDayLabel(
      widget.forecast.date,
      widget.isToday,
    );

    return Column(
      children: [
        // Main content container
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color:
                _isExpanded
                    ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                    : null,
          ),
          child: Row(
            children: [
              // Day label (left-aligned)
              SizedBox(
                width: 90,
                child: Text(
                  dayLabel,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight:
                        widget.isToday ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),

              // Flow icon with data source badge
              Stack(
                children: [
                  FlowConditionIcon(
                    flowCategory: widget.forecast.flowCategory,
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
                      _flowFormatter.format(widget.forecast.minFlow),
                      style: textTheme.bodyMedium?.copyWith(
                        fontSize: 16,
                        color:
                            widget.isToday
                                ? colorScheme.primary
                                : colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Flow range bar
                    Expanded(
                      child: FlowRangeBar(
                        forecast: widget.forecast,
                        minFlowBound: widget.minFlowBound,
                        maxFlowBound: widget.maxFlowBound,
                        height: 7.0,
                        returnPeriod: widget.returnPeriod,
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Maximum flow value
                    Text(
                      _flowFormatter.format(widget.forecast.maxFlow),
                      style: textTheme.bodyMedium?.copyWith(
                        fontSize: 16,
                        color:
                            widget.isToday
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

        // Add the divider as a separate element after the row
        if (!widget.isLastRow)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0),
            child: Divider(
              height: 1,
              thickness: 1.5,
              color: colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
      ],
    );
  }

  /// Builds the expanded details view
  Widget _buildDetailsView() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Format the date for the header
    final dateStr = DateFormat(
      'EEEE, MMMM d, yyyy',
    ).format(widget.forecast.date);

    return Container(
      width: double.infinity,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
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
                  _flowFormatter.format(widget.forecast.minFlow),
                  Colors.blue,
                ),
                _buildStatRow(
                  'Max Flow',
                  _flowFormatter.format(widget.forecast.maxFlow),
                  Colors.red,
                ),
                _buildStatRow(
                  'Avg Flow',
                  _flowFormatter.format(widget.forecast.avgFlow),
                  Colors.purple,
                ),
              ],
            ),
          ),

          // Hourly flow display widget - the new component we're adding
          if (widget.forecast.hourlyData.isNotEmpty)
            HourlyFlowDisplay(
              forecast: widget.forecast,
              returnPeriod: widget.returnPeriod,
              flowFormatter: _flowFormatter,
            ),

          // Data source info
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Data source: ${widget.forecast.dataSource}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
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
