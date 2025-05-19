// lib/features/forecast/presentation/widgets/medium_range/9_day_flow_forecast_widget/hourly_slider_widget/hourly_flow_display.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rivr/core/formatters/flow_value_formatter.dart';
import 'package:rivr/core/services/flow_units_service.dart';
import 'package:rivr/features/forecast/domain/entities/return_period.dart';
import 'package:rivr/features/forecast/presentation/widgets/medium_range/9_day_flow_forecast_widget/forecast_data_processor.dart';
import 'package:rivr/features/forecast/presentation/widgets/medium_range/9_day_flow_forecast_widget/hourly_slider_widget/flow_value_indicator.dart';
import 'package:rivr/features/forecast/presentation/widgets/medium_range/9_day_flow_forecast_widget/hourly_slider_widget/micro_bar_chart.dart';
import 'package:rivr/features/forecast/presentation/widgets/medium_range/9_day_flow_forecast_widget/hourly_slider_widget/time_slider.dart';

/// A widget that displays hourly flow data for a selected day
class HourlyFlowDisplay extends StatefulWidget {
  final DailyFlowForecast forecast;
  final ReturnPeriod? returnPeriod;
  final NumberFormat? flowFormatter; // Keep for backward compatibility
  final FlowValueFormatter?
  flowValueFormatter; // Add support for FlowValueFormatter

  const HourlyFlowDisplay({
    super.key,
    required this.forecast,
    this.returnPeriod,
    this.flowFormatter,
    this.flowValueFormatter,
  });

  @override
  State<HourlyFlowDisplay> createState() => _HourlyFlowDisplayState();
}

class _HourlyFlowDisplayState extends State<HourlyFlowDisplay> {
  late FlowValueFormatter _flowValueFormatter;
  late FlowUnitsService _flowUnitsService;
  late int _selectedHourIndex;
  late List<MapEntry<DateTime, double>> _sortedHourlyData;

  // Value range for the chart
  double _minFlow = 0;
  double _maxFlow = 100;

  // Currently selected flow data
  DateTime? _selectedTime;
  double? _selectedFlow;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();

    // Initialize flow services
    _flowValueFormatter =
        widget.flowValueFormatter ??
        Provider.of<FlowValueFormatter>(context, listen: false);
    _flowUnitsService = Provider.of<FlowUnitsService>(context, listen: false);

    // Listen for unit changes
    _flowUnitsService.addListener(_onUnitChanged);

    // Process the hourly data
    _processHourlyData();

    // Set initial position to either highest flow or current hour
    _setInitialPosition();
  }

  @override
  void dispose() {
    // Remove listener when disposed
    _flowUnitsService.removeListener(_onUnitChanged);
    super.dispose();
  }

  // Handle unit changes
  void _onUnitChanged() {
    // Force a rebuild when units change
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(HourlyFlowDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.forecast != widget.forecast) {
      _processHourlyData();
      _setInitialPosition();
    }

    // Update formatters if they changed
    if (widget.flowValueFormatter != null &&
        widget.flowValueFormatter != _flowValueFormatter) {
      _flowValueFormatter = widget.flowValueFormatter!;
    }
  }

  /// Processes the hourly data for display
  void _processHourlyData() {
    // Convert map to sorted list for easier access
    _sortedHourlyData =
        widget.forecast.hourlyData.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));

    // Calculate min and max flow values for the chart
    if (_sortedHourlyData.isNotEmpty) {
      _minFlow = _sortedHourlyData
          .map((e) => e.value)
          .reduce((a, b) => a < b ? a : b);
      _maxFlow = _sortedHourlyData
          .map((e) => e.value)
          .reduce((a, b) => a > b ? a : b);

      // Add a small buffer (5%) for visual clarity
      final range = _maxFlow - _minFlow;
      _minFlow = _minFlow - (range * 0.05).clamp(0, double.infinity);
      _maxFlow = _maxFlow + (range * 0.05);
    }
  }

  /// Sets the initial slider position
  void _setInitialPosition() {
    if (_sortedHourlyData.isEmpty) {
      _selectedHourIndex = 0;
      _selectedTime = null;
      _selectedFlow = null;
      _selectedCategory = null;
      return;
    }

    // Try to find the highest flow hour
    int highestFlowIndex = 0;
    double highestFlow = _sortedHourlyData[0].value;

    for (int i = 1; i < _sortedHourlyData.length; i++) {
      if (_sortedHourlyData[i].value > highestFlow) {
        highestFlow = _sortedHourlyData[i].value;
        highestFlowIndex = i;
      }
    }

    // Try to use current time if viewing today's forecast
    final now = DateTime.now();
    final isToday =
        widget.forecast.date.year == now.year &&
        widget.forecast.date.month == now.month &&
        widget.forecast.date.day == now.day;

    if (isToday) {
      // Find the closest hour to current time
      final currentHour = now.hour;
      int closestIndex = 0;
      int smallestDifference = 24;

      for (int i = 0; i < _sortedHourlyData.length; i++) {
        final hour = _sortedHourlyData[i].key.hour;
        final difference = (hour - currentHour).abs();

        if (difference < smallestDifference) {
          smallestDifference = difference;
          closestIndex = i;
        }
      }

      _selectedHourIndex = closestIndex;
    } else {
      // Use the highest flow hour
      _selectedHourIndex = highestFlowIndex;
    }

    // Update selected values
    _updateSelectedValues();
  }

  /// Updates the selected values based on the selected hour index
  void _updateSelectedValues() {
    if (_selectedHourIndex < 0 ||
        _selectedHourIndex >= _sortedHourlyData.length) {
      _selectedTime = null;
      _selectedFlow = null;
      _selectedCategory = null;
      return;
    }

    _selectedTime = _sortedHourlyData[_selectedHourIndex].key;
    _selectedFlow = _sortedHourlyData[_selectedHourIndex].value;

    if (widget.returnPeriod != null && _selectedFlow != null) {
      _selectedCategory = widget.returnPeriod!.getFlowCategory(_selectedFlow!);
    } else {
      _selectedCategory = null;
    }
  }

  /// Called when the slider value changes
  void _onSliderChanged(double value) {
    final newIndex = value.round();

    if (newIndex != _selectedHourIndex &&
        newIndex >= 0 &&
        newIndex < _sortedHourlyData.length) {
      setState(() {
        _selectedHourIndex = newIndex;
        _updateSelectedValues();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sortedHourlyData.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Center(child: Text('No hourly data available for this day')),
      );
    }

    // If we have only one data point, show a simplified view
    if (_sortedHourlyData.length == 1) {
      final entry = _sortedHourlyData.first;
      final time = entry.key;
      final flow = entry.value;
      String? category;

      if (widget.returnPeriod != null) {
        category = widget.returnPeriod!.getFlowCategory(flow);
      }

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
              child: Text(
                'Hourly Flow',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Center(
              child: FlowValueIndicator(
                flowValue: flow,
                time: time,
                flowCategory: category,
                returnPeriod: widget.returnPeriod,
                flowValueFormatter: _flowValueFormatter, // Pass the formatter
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Only one hour of data available',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
            child: Text(
              'Hourly Flow',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),

          // Bar chart and value indicator row
          SizedBox(
            height: 100,
            child: Row(
              children: [
                // Micro bar chart (takes most of the space)
                Expanded(
                  child: MicroBarChart(
                    hourlyData: _sortedHourlyData,
                    selectedIndex: _selectedHourIndex,
                    minValue: _minFlow,
                    maxValue: _maxFlow,
                    returnPeriod: widget.returnPeriod,
                  ),
                ),

                // Flow value indicator
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: FlowValueIndicator(
                    flowValue: _selectedFlow,
                    time: _selectedTime,
                    flowCategory: _selectedCategory,
                    returnPeriod: widget.returnPeriod,
                    flowValueFormatter:
                        _flowValueFormatter, // Pass the formatter
                  ),
                ),
              ],
            ),
          ),

          // Time slider
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: HourlyTimeSlider(
              hourCount: _sortedHourlyData.length,
              currentValue: _selectedHourIndex.toDouble(),
              onChanged: _onSliderChanged,
              hourLabels: _sortedHourlyData.map((e) => e.key).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
