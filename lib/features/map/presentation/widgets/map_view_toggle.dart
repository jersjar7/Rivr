// lib/features/map/presentation/widgets/map_view_toggle.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/map_provider.dart';

class MapViewToggle extends StatefulWidget {
  const MapViewToggle({super.key});

  @override
  State<MapViewToggle> createState() => _MapViewToggleState();
}

class _MapViewToggleState extends State<MapViewToggle>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _animationController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _selectViewMode(BuildContext context, bool is3D) {
    final mapProvider = Provider.of<MapProvider>(context, listen: false);

    // Only toggle if needed
    if (mapProvider.is3DMode != is3D) {
      mapProvider.toggle3DTerrain();
    }

    // Collapse the button after selection
    setState(() {
      _isExpanded = false;
      _animationController.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MapProvider>(
      builder: (context, mapProvider, _) {
        final is3DMode = mapProvider.is3DMode;

        if (_isExpanded) {
          // Expanded state - show both options
          return _buildExpandedToggle(context, is3DMode);
        } else {
          // Collapsed state - show just the current mode
          return _buildCollapsedToggle(context, is3DMode);
        }
      },
    );
  }

  Widget _buildCollapsedToggle(BuildContext context, bool is3DMode) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _toggleExpand,
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: Icon(
              is3DMode ? Icons.view_in_ar : Icons.map,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedToggle(BuildContext context, bool is3DMode) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 108,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            // 2D option (left side)
            Expanded(
              child: InkWell(
                onTap: () => _selectViewMode(context, false),
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(8),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color:
                        !is3DMode
                            ? theme.primaryColor.withOpacity(0.1)
                            : Colors.transparent,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(8),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.map,
                      color: !is3DMode ? theme.primaryColor : Colors.black87,
                    ),
                  ),
                ),
              ),
            ),

            // Divider
            Container(
              height: 24,
              width: 1,
              color: Colors.grey.withOpacity(0.5),
            ),

            // 3D option (right side)
            Expanded(
              child: InkWell(
                onTap: () => _selectViewMode(context, true),
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(8),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color:
                        is3DMode
                            ? theme.primaryColor.withOpacity(0.1)
                            : Colors.transparent,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(8),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.view_in_ar,
                      color: is3DMode ? theme.primaryColor : Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
