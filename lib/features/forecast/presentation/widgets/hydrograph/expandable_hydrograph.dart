// lib/features/forecast/presentation/widgets/hydrograph/expandable_hydrograph.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rivr/core/formatters/flow_value_formatter.dart';
import 'package:rivr/core/models/flow_unit.dart';
import 'package:rivr/core/services/flow_units_service.dart';
import 'package:rivr/features/forecast/domain/entities/forecast.dart';
import 'package:rivr/features/forecast/domain/entities/forecast_types.dart';
import 'package:rivr/features/forecast/domain/entities/return_period.dart';
import 'package:rivr/features/forecast/presentation/widgets/hydrograph/custom_zoomable_chart.dart';

/// An expandable hydrograph widget that shows a preview and expands to full view
class ExpandableHydrograph extends StatefulWidget {
  final String reachId;
  final ForecastType forecastType;
  final List<Forecast> forecasts;
  final ReturnPeriod? returnPeriod;
  final Map<DateTime, Map<String, double>>? dailyStats;
  final Map<String, Map<String, double>>? longRangeFlows;
  final double previewHeight;
  final FlowUnit sourceUnit; // Add source unit parameter

  const ExpandableHydrograph({
    super.key,
    required this.reachId,
    required this.forecastType,
    required this.forecasts,
    this.returnPeriod,
    this.dailyStats,
    this.longRangeFlows,
    this.previewHeight = 180,
    this.sourceUnit = FlowUnit.cfs, // Default to CFS as source unit
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

  // Global overlay entry
  OverlayEntry? _overlayEntry;

  // Flow unit services
  late final FlowUnitsService _flowUnitsService;
  late final FlowValueFormatter _flowFormatter;

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

    // Initialize flow unit services
    _flowUnitsService = Provider.of<FlowUnitsService>(context, listen: false);
    _flowFormatter = Provider.of<FlowValueFormatter>(context, listen: false);

    // Listen for unit changes
    _flowUnitsService.addListener(_onUnitChanged);
  }

  @override
  void dispose() {
    _removeOverlay();
    _animationController.dispose();
    _flowUnitsService.removeListener(_onUnitChanged);
    super.dispose();
  }

  // Handle unit changes
  void _onUnitChanged() {
    if (mounted) {
      setState(() {}); // Trigger a rebuild when unit changes
    }
  }

  // Toggle between expanded and collapsed states
  void _toggleExpanded() {
    if (_isExpanded) {
      // Collapse - start by reversing animation
      _animationController.reverse().then((_) {
        _removeOverlay();
        setState(() {
          _isExpanded = false;
        });
      });
    } else {
      // Expand - create and insert overlay
      setState(() {
        _isExpanded = true;
      });
      _createAndInsertOverlay();
      _animationController.forward();
    }
  }

  // Create and insert the overlay entry
  void _createAndInsertOverlay() {
    final overlay = Overlay.of(context);

    _overlayEntry = OverlayEntry(
      builder: (context) {
        // Get screen size for full-screen overlay
        final screenSize = MediaQuery.of(context).size;

        return AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Stack(
              children: [
                // Semi-transparent background
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _toggleExpanded, // Close when tapping background
                    child: Container(
                      color: Colors.black.withValues(
                        alpha: 0.5 * _opacityAnimation.value,
                      ),
                    ),
                  ),
                ),

                // Centered expanded chart container
                Positioned(
                  left: screenSize.width * 0.05, // 5% margin
                  top: screenSize.height * 0.1, // 10% from top
                  width: screenSize.width * 0.9, // 90% of screen width
                  height: screenSize.height * 0.8, // 80% of screen height
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: FadeTransition(
                      opacity: _opacityAnimation,
                      child: Material(
                        color: Theme.of(context).cardColor,
                        elevation: 8,
                        borderRadius: BorderRadius.circular(16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Column(
                            children: [
                              // Custom header instead of AppBar
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Theme.of(context).dividerColor,
                                      width: 0.5,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _getChartTitle(),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close),
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      onPressed: _toggleExpanded,
                                    ),
                                  ],
                                ),
                              ),

                              // Expanded hydrograph content
                              Expanded(child: _buildFullHydrograph()),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    overlay.insert(_overlayEntry!);
  }

  // Remove the overlay
  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleExpanded,
      child: _buildPreviewChart(context),
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
            color: Colors.black.withValues(alpha: 0.1),
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
                  color: colorScheme.primary.withValues(alpha: 0.7),
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

  // Simplified chart for preview mode with proper unit conversion
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

    // Create spots with proper unit conversion
    final spots = <FlSpot>[];
    List<double> flowValues = [];

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

      // Convert flow to preferred unit if needed
      double flowValue = forecast.flow;
      if (widget.sourceUnit != _flowUnitsService.preferredUnit) {
        flowValue = _flowUnitsService.convertToPreferredUnit(
          flowValue,
          widget.sourceUnit,
        );
      }

      spots.add(FlSpot(x, flowValue));
      flowValues.add(flowValue);
    }

    // Get min/max flow for y-axis scaling with converted values
    final minFlow =
        flowValues.isEmpty ? 0 : flowValues.reduce((a, b) => a < b ? a : b);
    final maxFlow =
        flowValues.isEmpty ? 100 : flowValues.reduce((a, b) => a > b ? a : b);

    // Calculate average in the correct unit
    final avgFlow =
        flowValues.isEmpty
            ? 0.0 // Use 0.0 explicitly for double
            : (flowValues.reduce((a, b) => a + b) / flowValues.length)
                .toDouble();

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
                        colorScheme.primary.withValues(alpha: 0.4),
                        colorScheme.secondary.withValues(alpha: 0.1),
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

        // Current flow value overlay with proper unit display
        Positioned(
          top: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.9),
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
                  '${_flowFormatter.formatNumberOnly(avgFlow)} ${_flowUnitsService.unitShortName}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  'avg flow',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Build the full hydrograph for the expanded view
  Widget _buildFullHydrograph() {
    // Use custom zoomable chart with proper source unit parameter
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CustomZoomableChart(
          reachId: widget.reachId,
          forecastType: widget.forecastType,
          forecasts: widget.forecasts,
          returnPeriod: widget.returnPeriod,
          dailyStats: widget.dailyStats,
          longRangeFlows: widget.longRangeFlows,
          sourceUnit: widget.sourceUnit, // Pass the source unit
        ),
      ),
    );
  }

  // Helper to get appropriate title based on forecast type
  String _getChartTitle() {
    switch (widget.forecastType) {
      case ForecastType.shortRange:
        return 'Hourly Hydrograph';
      case ForecastType.mediumRange:
        return 'Daily Hydrograph';
      case ForecastType.longRange:
        return 'Weekly Hydrograph';
    }
  }
}
