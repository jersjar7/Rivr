// lib/features/forecast/presentation/widgets/short_range/horizontal_flow_timeline.dart

import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rivr/core/formatters/flow_value_formatter.dart';
import 'package:rivr/core/models/flow_unit.dart';
import 'package:rivr/core/services/flow_units_service.dart';
import 'package:rivr/features/forecast/domain/entities/forecast.dart';
import 'package:rivr/features/forecast/domain/entities/return_period.dart';
import 'package:rivr/features/forecast/presentation/widgets/card_flow_value.dart';
import 'package:rivr/features/forecast/utils/flow_thresholds.dart';

enum TimelineViewType { hourCards, flowWave }

class HorizontalFlowTimeline extends StatefulWidget {
  final List<Forecast> forecasts;
  final ReturnPeriod? returnPeriod;
  final TimelineViewType initialViewType;
  final int hoursToShow;
  final FlowUnit sourceUnit; // Add source unit parameter

  const HorizontalFlowTimeline({
    super.key,
    required this.forecasts,
    this.returnPeriod,
    this.initialViewType = TimelineViewType.hourCards,
    this.hoursToShow = 18,
    this.sourceUnit = FlowUnit.cfs, // Default to CFS as source unit
  });

  @override
  State<HorizontalFlowTimeline> createState() => _HorizontalFlowTimelineState();
}

class _HorizontalFlowTimelineState extends State<HorizontalFlowTimeline> {
  late TimelineViewType _currentViewType;
  late List<Forecast> _sortedForecasts;
  late ScrollController _scrollController;

  // Flow unit services
  late final FlowUnitsService _flowUnitsService;
  late final FlowValueFormatter _flowValueFormatter;

  @override
  void initState() {
    super.initState();
    _currentViewType = widget.initialViewType;
    _scrollController = ScrollController();

    // Initialize flow services
    _flowUnitsService = Provider.of<FlowUnitsService>(context, listen: false);
    _flowValueFormatter = Provider.of<FlowValueFormatter>(
      context,
      listen: false,
    );

    // Listen for unit changes
    _flowUnitsService.addListener(_onUnitChanged);

    _processForecasts();
  }

  // Handle unit changes
  void _onUnitChanged() {
    // Force a rebuild when units change
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(HorizontalFlowTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.forecasts != widget.forecasts) {
      _processForecasts();
    }
  }

  @override
  void dispose() {
    // Remove listener when disposed
    _flowUnitsService.removeListener(_onUnitChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _processForecasts() {
    // Sort forecasts by time
    _sortedForecasts = List<Forecast>.from(widget.forecasts)
      ..sort((a, b) => a.validDateTime.compareTo(b.validDateTime));

    // Filter out past forecasts BUT KEEP THE CURRENT HOUR
    final now = DateTime.now();
    final currentHour = now.hour;

    _sortedForecasts =
        _sortedForecasts.where((forecast) {
          final forecastTime = forecast.validDateTime.toLocal();
          // Keep if it's in the future OR if it's in the current hour
          return forecastTime.isAfter(now) || forecastTime.hour == currentHour;
        }).toList();

    // If all forecasts are in the past, keep the most recent one
    if (_sortedForecasts.isEmpty && widget.forecasts.isNotEmpty) {
      widget.forecasts.sort(
        (a, b) => b.validDateTime.compareTo(a.validDateTime),
      );
      _sortedForecasts = [widget.forecasts.first];
    }

    // Limit to the next X hours
    if (_sortedForecasts.length > widget.hoursToShow) {
      _sortedForecasts = _sortedForecasts.sublist(0, widget.hoursToShow);
    }

    // Print flow values and return periods to terminal for debugging
    _printDebugInfo();
  }

  void _printDebugInfo() {
    print('\n===== HOURLY FLOW FORECAST DEBUG INFO =====');
    print('Number of forecasts: ${_sortedForecasts.length}');

    if (widget.returnPeriod != null) {
      print('\nRETURN PERIOD THRESHOLDS:');
      for (final year in [2, 5, 10, 25, 50, 100]) {
        final threshold = widget.returnPeriod!.getFlowForYear(year);
        if (threshold != null) {
          print(
            '$year-year return period: ${_flowValueFormatter.formatNumberOnly(threshold)} ${_flowUnitsService.unitLabel}',
          );
        }
      }
    } else {
      print('\nNo return period data available.');
    }

    print('\nHOURLY FORECAST DATA:');
    for (int i = 0; i < _sortedForecasts.length; i++) {
      final forecast = _sortedForecasts[i];
      final time = DateFormat(
        'MMM d, h:mm a',
      ).format(forecast.validDateTimeLocal);

      // Convert flow to preferred unit if needed
      double flowValue = forecast.flow;
      if (widget.sourceUnit != _flowUnitsService.preferredUnit) {
        flowValue = _flowUnitsService.convertToPreferredUnit(
          flowValue,
          widget.sourceUnit,
        );
      }

      final flow = _flowValueFormatter.formatNumberOnly(flowValue);

      String category = 'Unknown';
      if (widget.returnPeriod != null) {
        // Pass the source unit for accurate category determination
        category = widget.returnPeriod!.getFlowCategory(
          forecast.flow,
          fromUnit: widget.sourceUnit,
        );
        if (category == 'Catastrophic') {
          category = 'Exceptional';
        }
      }

      // Calculate trend (if not first forecast)
      String trend = '';
      if (i > 0) {
        // Get converted flow values for both forecasts
        double currentFlow = forecast.flow;
        double prevFlow = _sortedForecasts[i - 1].flow;

        if (widget.sourceUnit != _flowUnitsService.preferredUnit) {
          currentFlow = _flowUnitsService.convertToPreferredUnit(
            currentFlow,
            widget.sourceUnit,
          );
          prevFlow = _flowUnitsService.convertToPreferredUnit(
            prevFlow,
            widget.sourceUnit,
          );
        }

        final diff = currentFlow - prevFlow;
        final percentChange =
            prevFlow > 0 ? (diff / prevFlow * 100).toStringAsFixed(1) : 'N/A';
        trend =
            diff > 0
                ? "↑ +$percentChange%"
                : (diff < 0 ? "↓ $percentChange%" : "→ 0%");
      }

      print(
        '$time: $flow ${_flowUnitsService.unitLabel} | Category: $category | Trend: $trend',
      );
    }
    print('============================================\n');
  }

  void _toggleViewType() {
    setState(() {
      _currentViewType =
          _currentViewType == TimelineViewType.hourCards
              ? TimelineViewType.flowWave
              : TimelineViewType.hourCards;
    });
  }

  String _getFlowCategory(double flow) {
    if (widget.returnPeriod == null) return 'Unknown';

    // Pass the source unit for accurate category determination
    return widget.returnPeriod!.getFlowCategory(
      flow,
      fromUnit: widget.sourceUnit,
    );
  }

  Color _getCategoryColor(double flow) {
    final category = _getFlowCategory(flow);
    return FlowThresholds.getColorForCategory(category);
  }

  IconData _getTrendIcon(int index) {
    if (index <= 0 || index >= _sortedForecasts.length) return Icons.remove;

    // Get converted flow values
    double currentFlow = _sortedForecasts[index].flow;
    double prevFlow = _sortedForecasts[index - 1].flow;

    if (widget.sourceUnit != _flowUnitsService.preferredUnit) {
      currentFlow = _flowUnitsService.convertToPreferredUnit(
        currentFlow,
        widget.sourceUnit,
      );
      prevFlow = _flowUnitsService.convertToPreferredUnit(
        prevFlow,
        widget.sourceUnit,
      );
    }

    if (currentFlow > prevFlow) {
      return Icons.arrow_upward;
    } else if (currentFlow < prevFlow) {
      return Icons.arrow_downward;
    } else {
      return Icons.remove;
    }
  }

  Color _getTrendColor(int index) {
    if (index <= 0 || index >= _sortedForecasts.length) {
      return Theme.of(
        context,
      ).colorScheme.onSurfaceVariant; // Use theme-appropriate grey
    }

    // Get converted flow values
    double currentFlow = _sortedForecasts[index].flow;
    double prevFlow = _sortedForecasts[index - 1].flow;

    if (widget.sourceUnit != _flowUnitsService.preferredUnit) {
      currentFlow = _flowUnitsService.convertToPreferredUnit(
        currentFlow,
        widget.sourceUnit,
      );
      prevFlow = _flowUnitsService.convertToPreferredUnit(
        prevFlow,
        widget.sourceUnit,
      );
    }

    if (currentFlow > prevFlow) {
      return Theme.of(
        context,
      ).colorScheme.error; // Use theme's error color for increase
    } else if (currentFlow < prevFlow) {
      return Colors
          .green; // Keep green for decrease as it's a universal indicator
    } else {
      return Theme.of(
        context,
      ).colorScheme.onSurfaceVariant; // Use theme-appropriate grey
    }
  }

  double _getTrendPercentage(int index) {
    if (index <= 0 || index >= _sortedForecasts.length) return 0.0;

    // Get converted flow values
    double currentFlow = _sortedForecasts[index].flow;
    double prevFlow = _sortedForecasts[index - 1].flow;

    if (widget.sourceUnit != _flowUnitsService.preferredUnit) {
      currentFlow = _flowUnitsService.convertToPreferredUnit(
        currentFlow,
        widget.sourceUnit,
      );
      prevFlow = _flowUnitsService.convertToPreferredUnit(
        prevFlow,
        widget.sourceUnit,
      );
    }

    if (prevFlow == 0) return 0.0;
    return ((currentFlow - prevFlow) / prevFlow) * 100;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    if (_sortedForecasts.isEmpty) {
      return Center(
        child: Text(
          'No hourly forecast data available',
          style: textTheme.bodyMedium,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with toggle button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Hourly Flow', style: textTheme.titleMedium),
              // Toggle button
              TextButton.icon(
                onPressed: _toggleViewType,
                icon: Icon(
                  _currentViewType == TimelineViewType.hourCards
                      ? Icons.waves
                      : Icons.view_module,
                ),
                label: Text(
                  _currentViewType == TimelineViewType.hourCards
                      ? 'Wave View'
                      : 'Card View',
                ),
              ),
            ],
          ),
        ),

        // Main content based on selected view type
        if (_currentViewType == TimelineViewType.hourCards)
          _buildHourCardsView()
        else
          _buildFlowWaveView(),
      ],
    );
  }

  Widget _buildHourCardsView() {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final now = DateTime.now();

    // Get the current hour (e.g., for 3:47 PM, this will be 15)
    final currentHour = now.hour;

    return SizedBox(
      height: 180,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: _sortedForecasts.length,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemBuilder: (context, index) {
          final forecast = _sortedForecasts[index];
          final flow = forecast.flow;
          final category = _getFlowCategory(flow);
          final color = _getCategoryColor(flow);

          // Format time - show "Now" if the forecast hour matches the current hour
          final forecastHour = forecast.validDateTimeLocal.hour;
          final timeFormat =
              forecastHour == currentHour
                  ? 'Now'
                  : DateFormat('h a').format(forecast.validDateTimeLocal);

          // Get trend data
          final trendIcon = _getTrendIcon(index);
          final trendColor = _getTrendColor(index);
          final trendPercentage = _getTrendPercentage(index);

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(right: 8.0, bottom: 8.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: color.withValues(alpha: 0.5), width: 2),
            ),
            child: Container(
              width: 100,
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Time
                  Text(
                    timeFormat,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Flow indicator with circular decoration and compact format
                  FlowValueDisplay(
                    flow: flow,
                    color: color, // Pass the category color here
                    containerWidth: 60,
                    containerHeight: 60,
                    flowUnitsService:
                        _flowUnitsService, // Pass the unit service
                    flowFormatter: _flowValueFormatter, // Pass the formatter
                    fromUnit: widget.sourceUnit, // Indicate the source unit
                  ),

                  const SizedBox(height: 8),

                  // Category
                  Text(
                    category,
                    style: textTheme.bodySmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  // Trend indicator (if not first hour)
                  if (index > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(trendIcon, size: 12, color: trendColor),
                        const SizedBox(width: 2),
                        Text(
                          '${trendPercentage.abs().toStringAsFixed(1)}%',
                          style: textTheme.bodySmall?.copyWith(
                            color: trendColor,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFlowWaveView() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Theme-aware colors for markers
    final markerLineColor =
        isDark ? colorScheme.surfaceContainerHighest : Colors.grey[400];
    final markerTextColor =
        isDark ? Colors.black.withValues(alpha: 0.7) : Colors.grey[700];

    return SizedBox(
      height: 240,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        child: Container(
          width:
              _sortedForecasts.length * 70.0 +
              40.0, // Each hour takes 70 logical pixels
          height: 200,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
          child: Stack(
            clipBehavior: Clip.none, // Allow content to overflow the Stack
            children: [
              // Flow wave (in its own ClipPath, but not clipping the whole Stack)
              Positioned.fill(
                child: ClipPath(
                  clipper: FlowWaveClipper(
                    _sortedForecasts,
                    widget.sourceUnit,
                    _flowUnitsService,
                  ),
                  child: CustomPaint(
                    painter: FlowWavePainter(
                      forecasts: _sortedForecasts,
                      returnPeriod: widget.returnPeriod,
                      isDarkMode: isDark,
                      sourceUnit: widget.sourceUnit, // Pass source unit
                      flowUnitsService: _flowUnitsService, // Pass unit service
                    ),
                  ),
                ),
              ),

              // Time markers
              ..._buildTimeMarkers(markerLineColor, markerTextColor),

              // Flow values
              ..._buildFlowMarkers(isDark, colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTimeMarkers([Color? lineColor, Color? textColor]) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Default colors if not provided
    lineColor ??= isDark ? Colors.grey[600] : Colors.grey[400];
    textColor ??=
        isDark ? Colors.black.withValues(alpha: 0.7) : Colors.grey[700];

    final markers = <Widget>[];
    final double hourWidth = 70.0;

    for (int i = 0; i < _sortedForecasts.length; i++) {
      final forecast = _sortedForecasts[i];
      final timeStr =
          i == 0
              ? 'Now'
              : DateFormat('h a').format(forecast.validDateTimeLocal);

      markers.add(
        Positioned(
          left: i * hourWidth + (hourWidth / 2) - 20,
          bottom: 0,
          child: SizedBox(
            width: 40,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(height: 12, width: 1, color: lineColor),
                const SizedBox(height: 4),
                Text(
                  timeStr,
                  style: theme.textTheme.bodySmall?.copyWith(color: textColor),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return markers;
  }

  List<Widget> _buildFlowMarkers(bool isDark, ColorScheme colorScheme) {
    final theme = Theme.of(context);
    final markers = <Widget>[];
    final double hourWidth = 70.0;
    final double maxHeight = 160.0; // Max height for the wave

    // Calculate min and max flow for normalization
    // Convert to preferred unit if needed
    List<double> flowValues =
        _sortedForecasts.map((f) {
          double flow = f.flow;
          if (widget.sourceUnit != _flowUnitsService.preferredUnit) {
            flow = _flowUnitsService.convertToPreferredUnit(
              flow,
              widget.sourceUnit,
            );
          }
          return flow;
        }).toList();

    final minFlow = flowValues.reduce(min);
    final maxFlow = flowValues.reduce(max);
    final flowRange = maxFlow - minFlow;

    for (int i = 0; i < _sortedForecasts.length; i++) {
      final forecast = _sortedForecasts[i];
      // Get flow in preferred unit
      double flow = forecast.flow;
      if (widget.sourceUnit != _flowUnitsService.preferredUnit) {
        flow = _flowUnitsService.convertToPreferredUnit(
          flow,
          widget.sourceUnit,
        );
      }

      final normalizedHeight =
          flowRange > 0 ? ((flow - minFlow) / flowRange) * maxHeight : 0.0;
      final y = maxHeight - normalizedHeight;

      markers.add(
        Positioned(
          left: i * hourWidth + (hourWidth / 2) - 15,
          top: y - 10,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color:
                  isDark ? colorScheme.surfaceContainerHighest : Colors.white,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color:
                      isDark
                          ? Colors.black.withValues(alpha: 0.3)
                          : Colors.black.withValues(alpha: 0.1),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              // Format flow value using FlowValueFormatter for proper unit formatting
              _flowValueFormatter.formatNumberOnly(flow),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }

    return markers;
  }
}

class FlowWaveClipper extends CustomClipper<Path> {
  final List<Forecast> forecasts;
  final FlowUnit sourceUnit; // Add source unit
  final FlowUnitsService? flowUnitsService; // Add unit service

  FlowWaveClipper(this.forecasts, this.sourceUnit, this.flowUnitsService);

  @override
  Path getClip(Size size) {
    final path = Path();
    if (forecasts.isEmpty) return path;

    final double hourWidth = size.width / forecasts.length;
    final double maxHeight = size.height - 40; // Reserve space for time markers

    // Calculate min and max flow with unit conversion if needed
    List<double> flowValues =
        forecasts.map((f) {
          double flow = f.flow;
          if (sourceUnit != flowUnitsService?.preferredUnit &&
              flowUnitsService != null) {
            flow = flowUnitsService!.convertToPreferredUnit(flow, sourceUnit);
          }
          return flow;
        }).toList();

    final minFlow = flowValues.reduce(min);
    final maxFlow = flowValues.reduce(max);
    final flowRange = maxFlow - minFlow;

    // Start path at the bottom-left corner
    path.moveTo(0, size.height);

    // Create points for the wave
    for (int i = 0; i < forecasts.length; i++) {
      // Get flow in preferred unit
      double flow = forecasts[i].flow;
      if (sourceUnit != flowUnitsService?.preferredUnit &&
          flowUnitsService != null) {
        flow = flowUnitsService!.convertToPreferredUnit(flow, sourceUnit);
      }

      final normalizedHeight =
          flowRange > 0 ? ((flow - minFlow) / flowRange) * maxHeight : 0.0;
      final y = maxHeight - normalizedHeight;
      final x = i * hourWidth;

      if (i == 0) {
        path.lineTo(x, y);
      } else {
        // Create curved path between points
        final prevX = (i - 1) * hourWidth;
        final controlX = (x + prevX) / 2;

        path.quadraticBezierTo(controlX, y, x, y);
      }
    }

    // Complete the path back to bottom-right and bottom-left
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}

class FlowWavePainter extends CustomPainter {
  final List<Forecast> forecasts;
  final ReturnPeriod? returnPeriod;
  final bool isDarkMode;
  final FlowUnit sourceUnit; // Add source unit
  final FlowUnitsService? flowUnitsService; // Add unit service

  FlowWavePainter({
    required this.forecasts,
    this.returnPeriod,
    this.isDarkMode = false,
    required this.sourceUnit, // Required source unit
    this.flowUnitsService, // Optional unit service
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (forecasts.isEmpty) return;

    final double maxHeight = size.height - 40; // Reserve space for time markers

    // Calculate min and max flow with unit conversion if needed
    List<double> flowValues =
        forecasts.map((f) {
          double flow = f.flow;
          if (sourceUnit != flowUnitsService?.preferredUnit &&
              flowUnitsService != null) {
            flow = flowUnitsService!.convertToPreferredUnit(flow, sourceUnit);
          }
          return flow;
        }).toList();

    final minFlow = flowValues.reduce(min);
    final maxFlow = flowValues.reduce(max);
    final flowRange = maxFlow - minFlow;

    // Create gradient based on flow categories
    final List<Color> gradientColors = [];
    final List<double> gradientStops = [];

    if (returnPeriod != null) {
      // Create color stops for different flow categories
      final categories = [
        'Low',
        'Normal',
        'Moderate',
        'Elevated',
        'High',
        'Very High',
        'Extreme',
      ];

      for (int i = 0; i < categories.length; i++) {
        final category = categories[i];
        final color = FlowThresholds.getColorForCategory(category);
        gradientColors.add(color);
        gradientStops.add(i / (categories.length - 1));
      }
    } else {
      // Default gradient if no return period data
      gradientColors.add(Colors.blue);
      gradientColors.add(Colors.green);
      gradientColors.add(Colors.yellow);
      gradientColors.add(Colors.orange);
      gradientColors.add(Colors.red);

      gradientStops.add(0.0);
      gradientStops.add(0.25);
      gradientStops.add(0.5);
      gradientStops.add(0.75);
      gradientStops.add(1.0);
    }

    final gradient = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: gradientColors,
      stops: gradientStops,
    );

    final paint =
        Paint()
          ..shader = gradient.createShader(
            Rect.fromLTWH(0, 0, size.width, maxHeight),
          )
          ..style = PaintingStyle.fill;

    // Draw path for the wave fill
    final path = Path();
    final double hourWidth = size.width / forecasts.length;

    // Start path at the bottom-left corner
    path.moveTo(0, size.height);

    // Create points for the wave
    for (int i = 0; i < forecasts.length; i++) {
      // Get flow in preferred unit
      double flow = forecasts[i].flow;
      if (sourceUnit != flowUnitsService?.preferredUnit &&
          flowUnitsService != null) {
        flow = flowUnitsService!.convertToPreferredUnit(flow, sourceUnit);
      }

      final normalizedHeight =
          flowRange > 0 ? ((flow - minFlow) / flowRange) * maxHeight : 0.0;
      final y = maxHeight - normalizedHeight;
      final x = i * hourWidth;

      if (i == 0) {
        path.lineTo(x, y);
      } else {
        // Create curved path between points
        final prevX = (i - 1) * hourWidth;
        final controlX = (x + prevX) / 2;

        path.quadraticBezierTo(controlX, y, x, y);
      }
    }

    // Complete the path back to bottom-right and bottom-left
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    // Draw the wave fill
    canvas.drawPath(path, paint);

    // Draw the wave line on top - adapt to dark mode
    final lineColor =
        isDarkMode
            ? Colors.white.withValues(alpha: 0.5)
            : Colors.white.withValues(alpha: 0.7);

    final linePaint =
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

    final linePath = Path();

    for (int i = 0; i < forecasts.length; i++) {
      // Get flow in preferred unit
      double flow = forecasts[i].flow;
      if (sourceUnit != flowUnitsService?.preferredUnit &&
          flowUnitsService != null) {
        flow = flowUnitsService!.convertToPreferredUnit(flow, sourceUnit);
      }

      final normalizedHeight =
          flowRange > 0 ? ((flow - minFlow) / flowRange) * maxHeight : 0.0;
      final y = maxHeight - normalizedHeight;
      final x = i * hourWidth;

      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        // Create curved path between points
        final prevX = (i - 1) * hourWidth;
        final controlX = (x + prevX) / 2;

        linePath.quadraticBezierTo(controlX, y, x, y);
      }
    }

    canvas.drawPath(linePath, linePaint);

    // Draw return period reference lines if available
    if (returnPeriod != null) {
      _drawReturnPeriodLines(
        canvas,
        size,
        minFlow,
        maxFlow,
        flowRange,
        maxHeight,
      );
    }
  }

  void _drawReturnPeriodLines(
    Canvas canvas,
    Size size,
    double minFlow,
    double maxFlow,
    double flowRange,
    double maxHeight,
  ) {
    // Draw reference lines for return periods
    for (final year in [2, 5, 10, 25]) {
      // Get threshold in preferred unit (returnPeriod is already in the correct unit)
      final threshold = returnPeriod!.getFlowForYear(year);
      if (threshold == null) continue;

      // Only draw if the threshold is within our visualization range
      if (threshold >= minFlow && threshold <= maxFlow) {
        final normalizedHeight =
            flowRange > 0
                ? ((threshold - minFlow) / flowRange) * maxHeight
                : 0.0;
        final y = maxHeight - normalizedHeight;

        // Theme-aware colors
        final lineColor =
            isDarkMode
                ? Colors.white.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.6);

        final paint =
            Paint()
              ..color = lineColor
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0
              ..strokeCap = StrokeCap.round;

        // Draw dashed line
        final dashWidth = 5.0;
        final dashSpace = 3.0;
        double startX = 0;

        while (startX < size.width) {
          canvas.drawLine(
            Offset(startX, y),
            Offset(startX + dashWidth, y),
            paint,
          );
          startX += dashWidth + dashSpace;
        }

        // Draw label with theme-aware colors
        final bgColor = isDarkMode ? Colors.black38 : Colors.black54;
        final textColor = Colors.white;

        final textSpan = TextSpan(
          text: '$year-yr',
          style: TextStyle(
            color: textColor,
            fontSize: 10,
            backgroundColor: bgColor,
          ),
        );

        final textPainter = TextPainter(
          text: textSpan,
          textDirection: ui.TextDirection.ltr,
        );

        textPainter.layout();
        textPainter.paint(canvas, Offset(5, y - textPainter.height - 2));
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldPainter) => true;
}
