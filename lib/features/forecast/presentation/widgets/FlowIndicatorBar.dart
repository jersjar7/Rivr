// lib/features/forecast/presentation/widgets/FlowIndicatorBar.dart

import 'package:flutter/material.dart';
import 'package:rivr/features/forecast/domain/entities/return_period.dart';
import 'package:rivr/features/forecast/utils/flow_thresholds.dart';

class FlowIndicatorBar extends StatefulWidget {
  final double currentFlow;
  final ReturnPeriod? returnPeriod;
  final double height;
  final double width;
  final bool showLabels;
  final bool showMarkers;

  const FlowIndicatorBar({
    super.key,
    required this.currentFlow,
    this.returnPeriod,
    this.height = 24.0,
    this.width = 300.0,
    this.showLabels = true,
    this.showMarkers = true,
  });

  @override
  State<FlowIndicatorBar> createState() => _FlowIndicatorBarState();
}

class _FlowIndicatorBarState extends State<FlowIndicatorBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _markerPositionAnimation;

  // For the pulse effect around the marker
  late Animation<double> _pulseAnimation;

  final double _markerSize = 20.0;
  final List<int> _returnPeriodYears = [2, 5, 10, 25, 50, 100];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _markerPositionAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.25),
        weight: 1.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.25, end: 1.0),
        weight: 1.0,
      ),
    ]).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Start the animation after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(FlowIndicatorBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If the current flow changed, animate to the new position
    if (oldWidget.currentFlow != widget.currentFlow ||
        oldWidget.returnPeriod != widget.returnPeriod) {
      _animationController.reset();
      _animationController.forward();
    }
  }

  // Calculate the position of the flow marker based on return periods
  double _calculateMarkerPosition() {
    if (widget.returnPeriod == null) {
      // Default linear position if no return period data
      return widget.width * 0.5;
    }

    final percentage = FlowThresholds.calculateFlowPercentage(
      widget.currentFlow,
      widget.returnPeriod!,
    );

    // Position based on percentage (clamped to be within the bar)
    return (percentage / 100.0 * widget.width).clamp(
      _markerSize / 2,
      widget.width - _markerSize / 2,
    );
  }

  // Get marker positions for return period lines
  Map<int, double> _getReturnPeriodPositions() {
    if (widget.returnPeriod == null) {
      return {};
    }

    final Map<int, double> positions = {};

    for (final year in _returnPeriodYears) {
      final flow = widget.returnPeriod!.getFlowForYear(year);
      if (flow != null) {
        final percentage = FlowThresholds.calculateFlowPercentage(
          flow,
          widget.returnPeriod!,
        );

        positions[year] = (percentage / 100.0 * widget.width).clamp(
          0.0,
          widget.width,
        );
      }
    }

    return positions;
  }

  @override
  Widget build(BuildContext context) {
    final markerPosition = _calculateMarkerPosition();
    final returnPeriodPositions = _getReturnPeriodPositions();
    final category =
        widget.returnPeriod?.getFlowCategory(widget.currentFlow) ?? 'Unknown';
    final markerColor = FlowThresholds.getColorForCategory(category);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.width,
          height: widget.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Background gradient
              Container(
                width: widget.width,
                height: widget.height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.height / 2),
                  gradient: const LinearGradient(
                    colors: [
                      Colors.blue,
                      Colors.green,
                      Colors.yellow,
                      Colors.orange,
                      Colors.red,
                      Colors.purple,
                    ],
                  ),
                ),
              ),

              // Return period markers
              if (widget.showMarkers && widget.returnPeriod != null)
                ...returnPeriodPositions.entries.map((entry) {
                  return Positioned(
                    left: entry.value,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 2,
                      color: Colors.white.withOpacity(0.7),
                      child: widget.showLabels ? null : const SizedBox(),
                    ),
                  );
                }),

              // Animated flow marker
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Positioned(
                    left: _markerPositionAnimation.value * markerPosition,
                    top: (widget.height - _markerSize) / 2,
                    child: Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: _markerSize,
                        height: _markerSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: markerColor,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: markerColor.withOpacity(0.7),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // Return period labels
        if (widget.showLabels && widget.returnPeriod != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: SizedBox(
              width: widget.width,
              child: Stack(
                children:
                    returnPeriodPositions.entries.map((entry) {
                      return Positioned(
                        left: entry.value - 12,
                        child: Text(
                          '${entry.key}y',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ),
          ),

        // Flow category labels
        if (widget.showLabels)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Low',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                const Text(
                  'Moderate',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                const Text(
                  'High',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                const Text(
                  'Extreme',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
