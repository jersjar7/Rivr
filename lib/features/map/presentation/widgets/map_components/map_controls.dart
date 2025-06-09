// lib/features/map/presentation/widgets/map_components/map_controls.dart

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:rivr/features/map/presentation/widgets/map_components/enhanced_map_style_selector.dart';

/// A widget that provides map control buttons (style selector, terrain toggle, zoom, location)
class MapControls extends StatelessWidget {
  final bool is3DMode;
  final String currentStyle;
  final Function(String) onStyleChanged;
  final Function(bool) onToggle3D;
  final VoidCallback onRefresh;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  // Location control properties
  final bool userLocationEnabled;
  final bool isGettingLocation;
  final VoidCallback onToggleUserLocation;
  final VoidCallback onGoToCurrentLocation;

  const MapControls({
    super.key,
    required this.is3DMode,
    required this.currentStyle,
    required this.onStyleChanged,
    required this.onToggle3D,
    required this.onRefresh,
    required this.onZoomIn,
    required this.onZoomOut,
    // Location control parameters
    required this.userLocationEnabled,
    required this.isGettingLocation,
    required this.onToggleUserLocation,
    required this.onGoToCurrentLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Control buttons at top-right
        Positioned(
          top: 60,
          right: 8,
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
                ),

                const SizedBox(height: 12),

                // 3D/2D toggle button
                _build3DToggleButton(context),

                const SizedBox(height: 12),

                // Location toggle button
                _buildLocationToggleButton(context),

                const SizedBox(height: 12),

                // My location button
                _buildMyLocationButton(context),
              ],
            ),
          ),
        ),

        // Zoom controls at bottom-right
        // Positioned(right: 16, bottom: 150, child: _buildZoomControls(context)),
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
    // String? badge, // Kept for compatibility, but won't be displayed
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final brightness = theme.brightness;

    // Use consistent styling for all buttons
    final Color bgColor = colors.surface;

    // Use secondary (teal) color for icon in dark mode
    final Color iconColor =
        brightness == Brightness.dark
            ? colors
                .secondary // Teal in dark mode
            : colors.onSurface; // Normal icon color in light mode

    return Tooltip(
      message: tooltip,
      child: Container(
        height: 48,
        width: 48,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: colors.shadow,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(8),
            child: Center(child: Icon(icon, color: iconColor, size: 24)),
          ),
        ),
      ),
    );
  }

  Widget _build3DToggleButton(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final brightness = theme.brightness;

    // Use the same background color as the control buttons
    final Color bgColor = colors.surface;

    // For icon color, use secondary in dark mode regardless of toggle state
    // In light mode, use onSurface
    final Color iconColor =
        brightness == Brightness.dark
            ? colors
                .secondary // Always teal in dark mode
            : (is3DMode
                ? colors.primary
                : colors.onSurface); // In light mode, highlight when active

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => onToggle3D(!is3DMode),
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: Icon(
              is3DMode ? Icons.view_in_ar : Icons.map,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationToggleButton(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final brightness = theme.brightness;

    // Use the same background color as the control buttons
    final Color bgColor = colors.surface;

    // For icon color, follow the same pattern as 3D toggle
    final Color iconColor =
        brightness == Brightness.dark
            ? colors
                .secondary // Always teal in dark mode
            : (userLocationEnabled
                ? colors.primary
                : colors.onSurface); // In light mode, highlight when active

    return Tooltip(
      message:
          userLocationEnabled ? 'Hide location marker' : 'Show location marker',
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: colors.shadow,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onToggleUserLocation,
            borderRadius: BorderRadius.circular(8),
            child: Center(
              child: Icon(
                userLocationEnabled ? Icons.location_on : Icons.location_off,
                color: iconColor,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMyLocationButton(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final brightness = theme.brightness;

    // Use the same background color as the control buttons
    final Color bgColor = colors.surface;

    // Use secondary (teal) color for icon in dark mode
    final Color iconColor =
        brightness == Brightness.dark
            ? colors
                .secondary // Teal in dark mode
            : colors.onSurface; // Normal icon color in light mode

    return Tooltip(
      message: 'Go to my location',
      child: Container(
        height: 48,
        width: 48,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: colors.shadow,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: isGettingLocation ? null : onGoToCurrentLocation,
            borderRadius: BorderRadius.circular(8),
            child: Center(
              child:
                  isGettingLocation
                      ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                        ),
                      )
                      : Icon(Icons.my_location, color: iconColor, size: 24),
            ),
          ),
        ),
      ),
    );
  }

  void _showStyleSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => EnhancedMapStyleSelector(
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
