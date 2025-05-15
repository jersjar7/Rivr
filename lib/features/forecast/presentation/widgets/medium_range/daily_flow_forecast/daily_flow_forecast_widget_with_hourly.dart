// lib/features/forecast/presentation/widgets/medium_range/daily_flow_forecast/daily_flow_forecast_widget_with_hourly.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rivr/features/forecast/domain/entities/forecast.dart';
import 'package:rivr/features/forecast/domain/entities/return_period.dart';
import 'package:rivr/features/forecast/presentation/widgets/medium_range/daily_flow_forecast/daily_forecast_row_with_hourly.dart';
import 'package:rivr/features/forecast/presentation/widgets/medium_range/daily_flow_forecast/forecast_data_processor.dart';

/// Enhanced version of the daily flow forecast widget that includes hourly data visualization
class DailyFlowForecastWidgetWithHourly extends StatefulWidget {
  final ForecastCollection? forecastCollection;
  final ReturnPeriod? returnPeriod;
  final VoidCallback? onRefresh;
  final NumberFormat? flowFormatter;

  const DailyFlowForecastWidgetWithHourly({
    super.key,
    required this.forecastCollection,
    this.returnPeriod,
    this.onRefresh,
    this.flowFormatter,
  });

  @override
  State<DailyFlowForecastWidgetWithHourly> createState() =>
      _DailyFlowForecastWidgetWithHourlyState();
}

class _DailyFlowForecastWidgetWithHourlyState
    extends State<DailyFlowForecastWidgetWithHourly> {
  List<DailyFlowForecast> _dailyForecasts = [];
  Map<String, double> _flowBounds = {'min': 0, 'max': 100};
  int? _expandedIndex;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _processData();
  }

  @override
  void didUpdateWidget(DailyFlowForecastWidgetWithHourly oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.forecastCollection != widget.forecastCollection ||
        oldWidget.returnPeriod != widget.returnPeriod) {
      _processData();
    }
  }

  void _processData() {
    if (widget.forecastCollection == null) {
      setState(() {
        _errorMessage = 'No forecast data available';
        _isProcessing = false;
        _dailyForecasts = [];
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // Process the forecast data into daily forecasts
      final dailyForecasts = ForecastDataProcessor.processMediumRangeForecast(
        widget.forecastCollection!,
        widget.returnPeriod,
      );

      // Calculate overall min/max flow bounds for consistent bar scaling
      final flowBounds = ForecastDataProcessor.getFlowBounds(dailyForecasts);

      // Update state with processed data
      setState(() {
        _dailyForecasts = dailyForecasts;
        _flowBounds = flowBounds;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error processing forecast data: $e';
        _isProcessing = false;
      });
    }
  }

  void _toggleExpanded(int index) {
    setState(() {
      if (_expandedIndex == index) {
        _expandedIndex = null;
      } else {
        _expandedIndex = index;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    // If processing, show loading indicator
    if (_isProcessing) {
      return const Center(child: CircularProgressIndicator());
    }

    // If error, show error message
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (widget.onRefresh != null)
              ElevatedButton(
                onPressed: widget.onRefresh,
                child: const Text('Refresh'),
              ),
          ],
        ),
      );
    }

    // If no data, show empty state
    if (_dailyForecasts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.waves_outlined, size: 48, color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'No daily forecast data available',
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (widget.onRefresh != null)
              ElevatedButton(
                onPressed: widget.onRefresh,
                child: const Text('Refresh'),
              ),
          ],
        ),
      );
    }

    // Get today's date for highlighting today
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Build the list of daily forecast rows with hourly data
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with 10-Day Flow Forecast title
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Text(
              '${_dailyForecasts.length}-Day Flow Forecast',
              style: textTheme.titleMedium,
            ),
          ),

          // List of daily forecast rows with hourly data
          ...List.generate(_dailyForecasts.length, (index) {
            final forecast = _dailyForecasts[index];
            final isToday =
                forecast.date.year == today.year &&
                forecast.date.month == today.month &&
                forecast.date.day == today.day;

            return ExpandableDailyForecastRowWithHourly(
              forecast: forecast,
              minFlowBound: _flowBounds['min']!,
              maxFlowBound: _flowBounds['max']!,
              isToday: isToday,
              flowFormatter: widget.flowFormatter,
              returnPeriod: widget.returnPeriod,
              isExpanded: _expandedIndex == index,
              onExpandChanged: (expanded) => _toggleExpanded(index),
            );
          }),

          // Optional refresh button at bottom
          if (widget.onRefresh != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              child: Center(
                child: OutlinedButton.icon(
                  onPressed: widget.onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh Forecast'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
