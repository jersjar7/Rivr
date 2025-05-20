// lib/features/forecast/presentation/widgets/flow_indicator_bar.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rivr/core/formatters/flow_value_formatter.dart';
import 'package:rivr/core/models/flow_unit.dart'; // Import for FlowUnit
import 'package:rivr/features/forecast/domain/entities/return_period.dart';
import 'package:rivr/features/forecast/utils/flow_thresholds.dart';

class FlowIndicatorBar extends StatefulWidget {
  final double currentFlow;
  final ReturnPeriod? returnPeriod;
  final double height;
  final double width;
  final bool showLabels;
  final bool showMarkers;
  final bool showTooltips;
  final FlowUnit fromUnit; // Add parameter for source unit

  const FlowIndicatorBar({
    super.key,
    required this.currentFlow,
    this.returnPeriod,
    this.height = 24.0,
    this.width = 300.0,
    this.showLabels = true,
    this.showMarkers = true,
    this.showTooltips = false,
    this.fromUnit = FlowUnit.cfs, // Default to CFS as source unit
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

  // Flow units services
  late final FlowValueFormatter _flowValueFormatter;

  // Tooltip overlay entry
  OverlayEntry? _tooltipOverlay;

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

    // Initialize flow services
    _flowValueFormatter = Provider.of<FlowValueFormatter>(
      context,
      listen: false,
    );

    // Start the animation after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _removeTooltip();
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

  // Calculate the position of the flow marker on a linear scale
  // from 0 to 105% of the 100-year return period value
  double _calculateMarkerPosition() {
    if (widget.returnPeriod == null) {
      // Default middle position if no return period data
      return widget.width * 0.5;
    }

    // Get the 100-year return period flow value
    final flow100yr = widget.returnPeriod!.getFlowForYear(100);
    if (flow100yr == null) {
      return widget.width * 0.5;
    }

    // Define the scale: 0 to 105% of 100-year flow
    final double maxScale = flow100yr * 1.05;

    // Calculate normalized position on this scale
    double normalizedPosition = widget.currentFlow / maxScale;

    // Position based on percentage (clamped to be within the bar)
    return (normalizedPosition * widget.width).clamp(
      _markerSize / 2,
      widget.width - _markerSize / 2,
    );
  }

  // Get marker positions for return period lines using a linear scale
  // from 0 to 105% of the 100-year return period flow
  Map<int, double> _getReturnPeriodPositions() {
    if (widget.returnPeriod == null) {
      return {};
    }

    final Map<int, double> positions = {};

    // Get the 100-year return period flow value
    final flow100yr = widget.returnPeriod!.getFlowForYear(100);
    if (flow100yr == null) {
      return positions;
    }

    // Define the scale: 0 to 105% of 100-year flow
    final double maxScale = flow100yr * 1.05;

    // Calculate positions for each return period
    for (final year in _returnPeriodYears) {
      final flow = widget.returnPeriod!.getFlowForYear(year);
      if (flow != null) {
        // Position based on linear scale
        final double normalizedPosition = flow / maxScale;
        positions[year] = (normalizedPosition * widget.width).clamp(
          0.0,
          widget.width,
        );
      }
    }

    return positions;
  }

  // Show tooltip with flow information
  void _showTooltip(BuildContext context, double flow, Offset position) {
    _removeTooltip();

    final overlay = Overlay.of(context);

    _tooltipOverlay = OverlayEntry(
      builder:
          (context) => Positioned(
            left: position.dx,
            top: position.dy,
            child: Material(
              elevation: 4.0,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Current Flow',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      // Use the formatter that handles units correctly
                      _flowValueFormatter.formatWithUnit(flow, widget.fromUnit),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
    );

    overlay.insert(_tooltipOverlay!);
  }

  // Remove tooltip if showing
  void _removeTooltip() {
    _tooltipOverlay?.remove();
    _tooltipOverlay = null;
  }

  @override
  Widget build(BuildContext context) {
    final markerPosition = _calculateMarkerPosition();
    final returnPeriodPositions = _getReturnPeriodPositions();

    // Get category - passing fromUnit to ensure proper conversion
    final category =
        widget.returnPeriod?.getFlowCategory(
          widget.currentFlow,
          fromUnit: widget.fromUnit,
        ) ??
        'Unknown';

    final markerColor = FlowThresholds.getColorForCategory(category);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.width,
          height: widget.height,
          child: Stack(
            fit: StackFit.expand,
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
                  final flowValue = widget.returnPeriod!.getFlowForYear(
                    entry.key,
                  );

                  return Positioned(
                    left: entry.value,
                    top: 0,
                    bottom: 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap:
                          widget.showTooltips && flowValue != null
                              ? () {
                                final RenderBox box =
                                    context.findRenderObject() as RenderBox;
                                final Offset position = box.localToGlobal(
                                  Offset(entry.value, 0),
                                );
                                _showTooltip(
                                  context,
                                  flowValue,
                                  Offset(
                                    position.dx,
                                    position.dy + widget.height + 5,
                                  ),
                                );
                              }
                              : null,
                      child: Container(
                        width: 2,
                        color: Colors.white.withValues(alpha: 0.7),
                        child: widget.showLabels ? null : const SizedBox(),
                      ),
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
                    child: GestureDetector(
                      onTap:
                          widget.showTooltips
                              ? () {
                                final RenderBox box =
                                    context.findRenderObject() as RenderBox;
                                final Offset position = box.localToGlobal(
                                  Offset(markerPosition, 0),
                                );
                                _showTooltip(
                                  context,
                                  widget.currentFlow,
                                  Offset(
                                    position.dx,
                                    position.dy + widget.height + 5,
                                  ),
                                );
                              }
                              : null,
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
                                color: markerColor.withValues(alpha: 0.7),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
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
              height: 14,
              child: Stack(
                children:
                    returnPeriodPositions.entries.map((entry) {
                      final labelText = '${entry.key}y';
                      // Estimate the width of the text
                      final textWidth = labelText.length * 7.0;

                      // Center the label on the marker
                      double calculatedLeft = entry.value - (textWidth / 2);

                      // Ensure the label doesn't overflow
                      if (calculatedLeft + textWidth > widget.width) {
                        calculatedLeft = widget.width - textWidth;
                      }
                      if (calculatedLeft < 0) {
                        calculatedLeft = 0;
                      }

                      return Positioned(
                        left: calculatedLeft,
                        child: Text(
                          labelText,
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
