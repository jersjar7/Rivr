// lib/features/forecast/presentation/widgets/horizontal_flow_timeline.dart

import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rivr/features/forecast/domain/entities/forecast.dart';
import 'package:rivr/features/forecast/domain/entities/return_period.dart';
import 'package:rivr/features/forecast/utils/flow_thresholds.dart';

enum TimelineViewType { hourCards, flowWave }

class HorizontalFlowTimeline extends StatefulWidget {
  final List<Forecast> forecasts;
  final ReturnPeriod? returnPeriod;
  final TimelineViewType initialViewType;
  final int hoursToShow;

  const HorizontalFlowTimeline({
    super.key,
    required this.forecasts,
    this.returnPeriod,
    this.initialViewType = TimelineViewType.hourCards,
    this.hoursToShow = 18,
  });

  @override
  State<HorizontalFlowTimeline> createState() => _HorizontalFlowTimelineState();
}

class _HorizontalFlowTimelineState extends State<HorizontalFlowTimeline> {
  late TimelineViewType _currentViewType;
  late List<Forecast> _sortedForecasts;
  late ScrollController _scrollController;
  final NumberFormat _flowFormatter = NumberFormat('#,##0.0');

  @override
  void initState() {
    super.initState();
    _currentViewType = widget.initialViewType;
    _scrollController = ScrollController();
    _processForecasts();
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
    _scrollController.dispose();
    super.dispose();
  }

  void _processForecasts() {
    // Sort forecasts by time
    _sortedForecasts = List<Forecast>.from(widget.forecasts)
      ..sort((a, b) => a.validDateTime.compareTo(b.validDateTime));

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
            '$year-year return period: ${_flowFormatter.format(threshold)} ft³/s',
          );
        }
      }
    } else {
      print('\nNo return period data available.');
    }

    print('\nHOURLY FORECAST DATA:');
    for (int i = 0; i < _sortedForecasts.length; i++) {
      final forecast = _sortedForecasts[i];
      final time = DateFormat('MMM d, h:mm a').format(forecast.validDateTime);
      final flow = _flowFormatter.format(forecast.flow);

      String category = 'Unknown';
      if (widget.returnPeriod != null) {
        category = widget.returnPeriod!.getFlowCategory(forecast.flow);
        if (category == 'Catastrophic') {
          category = 'Exceptional';
        }
      }

      // Calculate trend (if not first forecast)
      String trend = '';
      if (i > 0) {
        final prevFlow = _sortedForecasts[i - 1].flow;
        final diff = forecast.flow - prevFlow;
        final percentChange =
            prevFlow > 0 ? (diff / prevFlow * 100).toStringAsFixed(1) : 'N/A';
        trend =
            diff > 0
                ? "↑ +$percentChange%"
                : (diff < 0 ? "↓ $percentChange%" : "→ 0%");
      }

      print('$time: $flow ft³/s | Category: $category | Trend: $trend');
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

    // Simply return the category without any replacement
    return widget.returnPeriod!.getFlowCategory(flow);
  }

  Color _getCategoryColor(double flow) {
    final category = _getFlowCategory(flow);
    return FlowThresholds.getColorForCategory(category);
  }

  IconData _getTrendIcon(int index) {
    if (index <= 0 || index >= _sortedForecasts.length) return Icons.remove;

    final currentFlow = _sortedForecasts[index].flow;
    final prevFlow = _sortedForecasts[index - 1].flow;

    if (currentFlow > prevFlow) {
      return Icons.arrow_upward;
    } else if (currentFlow < prevFlow) {
      return Icons.arrow_downward;
    } else {
      return Icons.remove;
    }
  }

  Color _getTrendColor(int index) {
    if (index <= 0 || index >= _sortedForecasts.length) return Colors.grey;

    final currentFlow = _sortedForecasts[index].flow;
    final prevFlow = _sortedForecasts[index - 1].flow;

    if (currentFlow > prevFlow) {
      return Colors.red;
    } else if (currentFlow < prevFlow) {
      return Colors.green;
    } else {
      return Colors.grey;
    }
  }

  double _getTrendPercentage(int index) {
    if (index <= 0 || index >= _sortedForecasts.length) return 0.0;

    final currentFlow = _sortedForecasts[index].flow;
    final prevFlow = _sortedForecasts[index - 1].flow;

    if (prevFlow == 0) return 0.0;
    return ((currentFlow - prevFlow) / prevFlow) * 100;
  }

  @override
  Widget build(BuildContext context) {
    if (_sortedForecasts.isEmpty) {
      return const Center(child: Text('No hourly forecast data available'));
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
              Text(
                'Hourly Flow Forecast',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
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

          // Format time
          final timeFormat =
              index == 0
                  ? 'Now'
                  : DateFormat('h a').format(forecast.validDateTime);
          final dateStr = DateFormat(
            'EEE, MMM d',
          ).format(forecast.validDateTime);

          // Get trend data
          final trendIcon = _getTrendIcon(index);
          final trendColor = _getTrendColor(index);
          final trendPercentage = _getTrendPercentage(index);

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(right: 8.0, bottom: 8.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: color.withOpacity(0.5), width: 2),
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    dateStr,
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),

                  // Flow indicator
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withOpacity(0.2),
                      border: Border.all(color: color, width: 2),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            flow.toInt().toString(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text('ft³/s', style: TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Category
                  Text(
                    category,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
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
                          style: TextStyle(fontSize: 10, color: trendColor),
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
    return SizedBox(
      height: 220,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        child: Container(
          width:
              _sortedForecasts.length *
              70.0, // Each hour takes 70 logical pixels
          height: 200,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Stack(
            clipBehavior: Clip.none, // Allow content to overflow the Stack
            children: [
              // Flow wave (in its own ClipPath, but not clipping the whole Stack)
              Positioned.fill(
                child: ClipPath(
                  clipper: FlowWaveClipper(_sortedForecasts),
                  child: CustomPaint(
                    painter: FlowWavePainter(
                      forecasts: _sortedForecasts,
                      returnPeriod: widget.returnPeriod,
                    ),
                  ),
                ),
              ),

              // Time markers
              ..._buildTimeMarkers(),

              // Flow values
              ..._buildFlowMarkers(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTimeMarkers() {
    final markers = <Widget>[];
    final double hourWidth = 70.0;

    for (int i = 0; i < _sortedForecasts.length; i++) {
      final forecast = _sortedForecasts[i];
      final timeStr =
          i == 0 ? 'Now' : DateFormat('h a').format(forecast.validDateTime);

      markers.add(
        Positioned(
          left: i * hourWidth + (hourWidth / 2) - 20,
          bottom: 0,
          child: SizedBox(
            width: 40,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(height: 12, width: 1, color: Colors.grey[400]),
                const SizedBox(height: 4),
                Text(
                  timeStr,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
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

  List<Widget> _buildFlowMarkers() {
    final markers = <Widget>[];
    final double hourWidth = 70.0;
    final double maxHeight = 160.0; // Max height for the wave

    // Calculate min and max flow for normalization
    final minFlow = _sortedForecasts.map((f) => f.flow).reduce(min);
    final maxFlow = _sortedForecasts.map((f) => f.flow).reduce(max);
    final flowRange = maxFlow - minFlow;

    for (int i = 0; i < _sortedForecasts.length; i++) {
      final forecast = _sortedForecasts[i];
      final flow = forecast.flow;
      final normalizedHeight =
          flowRange > 0 ? ((flow - minFlow) / flowRange) * maxHeight : 0.0;
      final y = maxHeight - normalizedHeight;

      markers.add(
        Positioned(
          left: i * hourWidth + (hourWidth / 2) - 15,
          top: y - 10,
          child: Container(
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              flow.toInt().toString(),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
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

  FlowWaveClipper(this.forecasts);

  @override
  Path getClip(Size size) {
    final path = Path();
    if (forecasts.isEmpty) return path;

    final double hourWidth = size.width / forecasts.length;
    final double maxHeight = size.height - 40; // Reserve space for time markers

    // Calculate min and max flow for normalization
    final minFlow = forecasts.map((f) => f.flow).reduce(min);
    final maxFlow = forecasts.map((f) => f.flow).reduce(max);
    final flowRange = maxFlow - minFlow;

    // Start path at the bottom-left corner
    path.moveTo(0, size.height);

    // Create points for the wave
    for (int i = 0; i < forecasts.length; i++) {
      final flow = forecasts[i].flow;
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

  FlowWavePainter({required this.forecasts, this.returnPeriod});

  @override
  void paint(Canvas canvas, Size size) {
    if (forecasts.isEmpty) return;

    final double maxHeight = size.height - 40; // Reserve space for time markers

    // Calculate min and max flow for normalization
    final minFlow = forecasts.map((f) => f.flow).reduce(min);
    final maxFlow = forecasts.map((f) => f.flow).reduce(max);
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
      final flow = forecasts[i].flow;
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

    // Draw the wave line on top
    final linePaint =
        Paint()
          ..color = Colors.white.withOpacity(0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

    final linePath = Path();

    for (int i = 0; i < forecasts.length; i++) {
      final flow = forecasts[i].flow;
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
      final threshold = returnPeriod!.getFlowForYear(year);
      if (threshold == null) continue;

      // Only draw if the threshold is within our visualization range
      if (threshold >= minFlow && threshold <= maxFlow) {
        final normalizedHeight =
            flowRange > 0
                ? ((threshold - minFlow) / flowRange) * maxHeight
                : 0.0;
        final y = maxHeight - normalizedHeight;

        final paint =
            Paint()
              ..color = Colors.white.withOpacity(0.6)
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

        // Draw label
        final textSpan = TextSpan(
          text: '$year-yr',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            backgroundColor: Colors.black54,
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
