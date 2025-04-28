// lib/features/map/presentation/widgets/map_components/map_controls.dart

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'style_selector_sheet.dart';

/// A widget that provides map control buttons (style selector, terrain toggle, zoom)
class MapControls extends StatelessWidget {
  final bool is3DMode;
  final String currentStyle;
  final Function(String) onStyleChanged;
  final Function(bool) onToggle3D;
  final VoidCallback onRefresh;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const MapControls({
    super.key,
    required this.is3DMode,
    required this.currentStyle,
    required this.onStyleChanged,
    required this.onToggle3D,
    required this.onRefresh,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Control buttons at top-right
        Positioned(
          top: 26,
          right: 16,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Refresh button
                _buildControlButton(
                  context: context,
                  icon: Icons.refresh,
                  tooltip: 'Refresh stations',
                  onPressed: onRefresh,
                ),

                const SizedBox(height: 12),

                // Map style button
                _buildControlButton(
                  context: context,
                  icon: Icons.layers,
                  tooltip: 'Map style: ${_getStyleName(currentStyle)}',
                  onPressed: () => _showStyleSelector(context),
                  badge: _getStyleName(currentStyle).characters.first,
                ),

                const SizedBox(height: 12),

                // 3D/2D toggle button
                _build3DToggleButton(context),
              ],
            ),
          ),
        ),

        // Zoom controls at bottom-right
        Positioned(right: 16, bottom: 150, child: _buildZoomControls(context)),
      ],
    );
  }

  String _getStyleName(String styleUri) {
    switch (styleUri) {
      case MapboxStyles.MAPBOX_STREETS:
        return 'Streets';
      case MapboxStyles.OUTDOORS:
        return 'Outdoors';
      case MapboxStyles.LIGHT:
        return 'Light';
      case MapboxStyles.DARK:
        return 'Dark';
      case MapboxStyles.SATELLITE_STREETS:
        return 'Satellite';
      case MapboxStyles.STANDARD:
        return 'Standard';
      default:
        return 'Custom';
    }
  }

  Widget _buildControlButton({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    String? badge,
  }) {
    final Color activeColor = Theme.of(context).primaryColor;

    return Tooltip(
      message: tooltip,
      child: Container(
        height: 48,
        width: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(26),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Center(child: Icon(icon, color: Colors.black87, size: 24)),
                if (badge != null)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: activeColor,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          badge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _build3DToggleButton(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onToggle3D(!is3DMode),
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: Icon(
              is3DMode ? Icons.view_in_ar : Icons.map,
              color: is3DMode ? theme.primaryColor : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildZoomControls(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Zoom in button
          SizedBox(
            height: 48,
            width: 48,
            child: _buildZoomButton(
              icon: Icons.add,
              tooltip: 'Zoom in',
              onPressed: onZoomIn,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
          ),

          // Divider
          Container(height: 1, width: 36, color: Colors.grey.withAlpha(77)),

          // Zoom out button
          SizedBox(
            height: 48,
            width: 48,
            child: _buildZoomButton(
              icon: Icons.remove,
              tooltip: 'Zoom out',
              onPressed: onZoomOut,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoomButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required BorderRadius borderRadius,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: borderRadius,
          child: Center(child: Icon(icon)),
        ),
      ),
    );
  }

  void _showStyleSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => StyleSelectorSheet(
            currentStyle: currentStyle,
            onStyleSelected: (style) {
              onStyleChanged(style);
              Navigator.pop(context);
            },
          ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    );
  }
}
