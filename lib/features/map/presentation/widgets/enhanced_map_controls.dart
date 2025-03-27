// lib/features/map/presentation/widgets/enhanced_map_controls.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:rivr/core/theme/app_theme.dart';

class EnhancedMapControls extends StatefulWidget {
  final MapController mapController;
  final LatLng? currentLocation;
  final Function(bool) onLayerToggle;
  final Function(String) onBaseMapChanged;
  final String currentBaseMap;
  final bool satelliteMode;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;
  final VoidCallback? onRecenter;

  const EnhancedMapControls({
    super.key,
    required this.mapController,
    this.currentLocation,
    required this.onLayerToggle,
    required this.onBaseMapChanged,
    required this.currentBaseMap,
    this.satelliteMode = false,
    this.onZoomIn,
    this.onZoomOut,
    this.onRecenter,
  });

  @override
  State<EnhancedMapControls> createState() => _EnhancedMapControlsState();
}

class _EnhancedMapControlsState extends State<EnhancedMapControls>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main Controls
        Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Main control buttons (always visible)
                _buildControlButton(
                  icon: Icons.layers,
                  tooltip: 'Map Layers',
                  onPressed: _toggleMenu,
                  isHighlighted: _isExpanded,
                ),
                const SizedBox(height: 8),
                _buildControlButton(
                  icon: Icons.add,
                  tooltip: 'Zoom In',
                  onPressed: () {
                    final newZoom = widget.mapController.camera.zoom + 1;
                    widget.mapController.move(
                      widget.mapController.camera.center,
                      newZoom.clamp(4.0, 18.0),
                    );
                    if (widget.onZoomIn != null) widget.onZoomIn!();
                  },
                ),
                const SizedBox(height: 8),
                _buildControlButton(
                  icon: Icons.remove,
                  tooltip: 'Zoom Out',
                  onPressed: () {
                    final newZoom = widget.mapController.camera.zoom - 1;
                    widget.mapController.move(
                      widget.mapController.camera.center,
                      newZoom.clamp(4.0, 18.0),
                    );
                    if (widget.onZoomOut != null) widget.onZoomOut!();
                  },
                ),
                const SizedBox(height: 8),
                _buildControlButton(
                  icon: Icons.my_location,
                  tooltip: 'My Location',
                  onPressed:
                      widget.currentLocation != null
                          ? () {
                            widget.mapController.move(
                              widget.currentLocation!,
                              14.0,
                            );
                            if (widget.onRecenter != null) widget.onRecenter!();
                          }
                          : null,
                ),
              ],
            ),
          ),
        ),

        // Expandable Layer Options
        AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            return SizeTransition(
              sizeFactor: CurvedAnimation(
                parent: _animController,
                curve: Curves.easeOut,
              ),
              child: child,
            );
          },
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Container(
                width: 200,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Base Map',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildBaseMapOption(
                        'Standard',
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      ),
                      _buildBaseMapOption(
                        'Cycle Map',
                        'https://tile.thunderforest.com/cycle/{z}/{x}/{y}.png',
                      ),
                      _buildBaseMapOption(
                        'Topo Map',
                        'https://tile.thunderforest.com/landscape/{z}/{x}/{y}.png',
                      ),
                      const Divider(),
                      const Text(
                        'Overlays',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        title: const Text('Satellite'),
                        value: widget.satelliteMode,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (value) {
                          widget.onLayerToggle(value);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    bool isHighlighted = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
      child: FloatingActionButton.small(
        heroTag: tooltip,
        backgroundColor:
            isHighlighted ? AppColors.secondaryColor : AppColors.primaryColor,
        onPressed: onPressed,
        tooltip: tooltip,
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  Widget _buildBaseMapOption(String title, String urlTemplate) {
    final isSelected = widget.currentBaseMap == urlTemplate;

    return InkWell(
      onTap: () {
        widget.onBaseMapChanged(urlTemplate);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primaryColor : Colors.transparent,
                border: Border.all(color: AppColors.primaryColor, width: 2),
              ),
              child:
                  isSelected
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
