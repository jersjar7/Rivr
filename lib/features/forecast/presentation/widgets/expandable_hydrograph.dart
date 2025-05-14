// lib/features/forecast/presentation/widgets/expandable_hydrograph.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:rivr/features/forecast/domain/entities/forecast.dart';
import 'package:rivr/features/forecast/domain/entities/forecast_types.dart';
import 'package:rivr/features/forecast/domain/entities/return_period.dart';
import 'package:rivr/features/forecast/presentation/widgets/hydrograph/hydrograph_factory.dart';

/// An expandable hydrograph that shows a compact preview and expands to a full interactive chart
class ExpandableHydrograph extends StatefulWidget {
  final String reachId;
  final ForecastType forecastType;
  final List<Forecast> forecasts;
  final ReturnPeriod? returnPeriod;
  final Map<DateTime, Map<String, double>>? dailyStats;
  final Map<String, Map<String, double>>? longRangeFlows;

  // Size when in preview mode
  final double previewHeight;

  const ExpandableHydrograph({
    super.key,
    required this.reachId,
    required this.forecastType,
    required this.forecasts,
    this.returnPeriod,
    this.dailyStats,
    this.longRangeFlows,
    this.previewHeight = 180,
  });

  @override
  State<ExpandableHydrograph> createState() => _ExpandableHydrographState();
}

class _ExpandableHydrographState extends State<ExpandableHydrograph>
    with SingleTickerProviderStateMixin {
  // Track expanded state
  bool _isExpanded = false;

  // Animation controller for expansion/collapse
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  // Store the tap position for expansion origin
  Offset? _tapPosition;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Create animations
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.5, 1.0),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Toggle between expanded and collapsed states
  void _toggleExpanded() {
    if (_isExpanded) {
      // Collapse
      _animationController.reverse().then((_) {
        setState(() {
          _isExpanded = false;
          _tapPosition = null;
        });
      });
    } else {
      // Expand
      setState(() {
        _isExpanded = true;
      });
      _animationController.forward();
    }
  }

  // Track tap position for animation origin
  void _handleTap(TapDownDetails details) {
    setState(() {
      _tapPosition = details.globalPosition;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Preview chart (always visible)
        GestureDetector(
          onTapDown: _handleTap,
          onTap: _toggleExpanded,
          child: _buildPreviewChart(context),
        ),

        // Expanded overlay (conditionally visible)
        if (_isExpanded)
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return _buildExpandedOverlay();
            },
          ),
      ],
    );
  }

  // Build the compact preview chart
  Widget _buildPreviewChart(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: widget.previewHeight,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with title and expand hint
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _getChartTitle(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  Icons.open_in_full,
                  size: 18,
                  color: colorScheme.primary.withOpacity(0.7),
                ),
              ],
            ),
          ),

          // Divider
          const Divider(height: 1),

          // Chart preview
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _buildSimplifiedChart(),
            ),
          ),
        ],
      ),
    );
  }

  // Simplified chart for preview mode
  Widget _buildSimplifiedChart() {
    if (widget.forecasts.isEmpty) {
      return const Center(child: Text('No forecast data available'));
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Sort forecasts by time
    final sortedForecasts = List<Forecast>.from(widget.forecasts)
      ..sort((a, b) => a.validDateTime.compareTo(b.validDateTime));

    // Base time for x-axis normalization
    final baseTime = sortedForecasts.first.validDateTime;

    // Create spots based on forecast type
    final spots = <FlSpot>[];
    for (var forecast in sortedForecasts) {
      double x;
      switch (widget.forecastType) {
        case ForecastType.shortRange:
          x = forecast.validDateTime.difference(baseTime).inHours.toDouble();
          break;
        case ForecastType.mediumRange:
          x = forecast.validDateTime.difference(baseTime).inHours / 24;
          break;
        case ForecastType.longRange:
          x = forecast.validDateTime.difference(baseTime).inDays / 7;
          break;
      }
      spots.add(FlSpot(x, forecast.flow));
    }

    // Get min/max flow for y-axis scaling
    final minFlow = sortedForecasts
        .map((f) => f.flow)
        .reduce((a, b) => a < b ? a : b);
    final maxFlow = sortedForecasts
        .map((f) => f.flow)
        .reduce((a, b) => a > b ? a : b);

    // Calculate basic stats for labels
    final avgFlow =
        sortedForecasts.map((f) => f.flow).reduce((a, b) => a + b) /
        sortedForecasts.length;

    return Stack(
      children: [
        // Chart
        Positioned.fill(
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: false),
              titlesData: FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(enabled: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  barWidth: 2.5,
                  isStrokeCapRound: true,
                  gradient: LinearGradient(
                    colors: [colorScheme.primary, colorScheme.secondary],
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary.withOpacity(0.4),
                        colorScheme.secondary.withOpacity(0.1),
                      ],
                    ),
                  ),
                  dotData: FlDotData(show: false),
                ),
              ],
              minY: minFlow * 0.8,
              maxY: maxFlow * 1.1,
            ),
          ),
        ),

        // Current flow value overlay
        Positioned(
          top: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.9),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${avgFlow.toStringAsFixed(1)} ft³/s',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  'avg flow',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onPrimaryContainer.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Full expanded overlay
  Widget _buildExpandedOverlay() {
    final screenSize = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedOpacity(
      opacity: _opacityAnimation.value,
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap: () {}, // Intercept taps to prevent closing when touching chart
        child: Container(
          width: screenSize.width,
          height: screenSize.height,
          color: Colors.black.withOpacity(0.5 * _opacityAnimation.value),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              width: screenSize.width * 0.9,
              height: screenSize.height * 0.7,
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  children: [
                    // Header with close button
                    Container(
                      color: colorScheme.surface,
                      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _getChartTitle(),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: _toggleExpanded,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),

                    // Full interactive chart
                    Expanded(
                      child: HydrographFactory.createHydrograph(
                        reachId: widget.reachId,
                        forecastType: widget.forecastType,
                        forecasts: widget.forecasts,
                        returnPeriod: widget.returnPeriod,
                        dailyStats: widget.dailyStats,
                        longRangeFlows: widget.longRangeFlows,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper to get appropriate title based on forecast type
  String _getChartTitle() {
    switch (widget.forecastType) {
      case ForecastType.shortRange:
        return 'Hourly Forecast (3-Day)';
      case ForecastType.mediumRange:
        return 'Daily Forecast (10-Day)';
      case ForecastType.longRange:
        return 'Weekly Forecast (8-Week)';
    }
  }
}
