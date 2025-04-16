// lib/features/map/presentation/widgets/map_controls.dart

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/map_provider.dart';
import '../providers/station_provider.dart';
import '../../../../core/constants/map_constants.dart';
import 'enhanced_map_style_selector.dart';
import 'map_view_toggle.dart';

class MapControls extends StatelessWidget {
  const MapControls({super.key});

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
                  onPressed: () => _refreshStations(context),
                ),

                const SizedBox(height: 12),

                // Map style button
                Consumer<MapProvider>(
                  builder: (context, mapProvider, _) {
                    // Determine which style is currently active
                    String styleName = _getStyleName(mapProvider.currentStyle);

                    return _buildControlButton(
                      context: context,
                      icon: Icons.layers,
                      tooltip: 'Map style: $styleName',
                      onPressed: () => _showStyleSelector(context),
                      badge: styleName.characters.first,
                    );
                  },
                ),

                const SizedBox(height: 12),

                // 3D/2D toggle button
                const MapViewToggle(),
              ],
            ),
          ),
        ),

        // Zoom controls at bottom-right
        Positioned(right: 16, bottom: 150, child: _buildZoomControls(context)),
      ],
    );
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
              color: Colors.black.withValues(alpha: 0.1),
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

  Widget _buildZoomControls(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
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
              onPressed: () => _zoomIn(context),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
          ),

          // Divider
          Container(
            height: 1,
            width: 36,
            color: Colors.grey.withValues(alpha: 0.3),
          ),

          // Zoom out button
          SizedBox(
            height: 48,
            width: 48,
            child: _buildZoomButton(
              icon: Icons.remove,
              tooltip: 'Zoom out',
              onPressed: () => _zoomOut(context),
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

  // Helper methods
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

  void _refreshStations(BuildContext context) {
    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    final stationProvider = Provider.of<StationProvider>(
      context,
      listen: false,
    );

    mapProvider.updateVisibleRegion().then((_) {
      if (mapProvider.currentZoom >= MapConstants.minZoomForMarkers) {
        stationProvider.loadStationsInRegion(mapProvider.visibleRegion!);
      } else {
        stationProvider.loadSampleStations();
      }
    });
  }

  void _zoomIn(BuildContext context) {
    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    final stationProvider = Provider.of<StationProvider>(
      context,
      listen: false,
    );

    mapProvider.zoomIn().then((_) {
      mapProvider.triggerDebounceTimer(() {
        if (mapProvider.currentZoom >= MapConstants.minZoomForMarkers) {
          stationProvider.loadStationsInRegion(mapProvider.visibleRegion!);
        } else if (stationProvider.stations.isNotEmpty) {
          stationProvider.loadSampleStations();
        }
      });
    });
  }

  void _zoomOut(BuildContext context) {
    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    final stationProvider = Provider.of<StationProvider>(
      context,
      listen: false,
    );

    mapProvider.zoomOut().then((_) {
      mapProvider.triggerDebounceTimer(() {
        if (mapProvider.currentZoom >= MapConstants.minZoomForMarkers) {
          stationProvider.loadStationsInRegion(mapProvider.visibleRegion!);
        } else if (stationProvider.stations.isNotEmpty) {
          stationProvider.clearStations();
          stationProvider.loadSampleStations();
        }
      });
    });
  }

  void _showStyleSelector(BuildContext context) {
    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    final stationProvider = Provider.of<StationProvider>(
      context,
      listen: false,
    );

    showModalBottomSheet(
      context: context,
      builder:
          (context) => EnhancedMapStyleSelector(
            currentStyle: mapProvider.currentStyle,
            onStyleSelected: (style) {
              mapProvider.changeMapStyle(style, () {
                if (stationProvider.stations.isNotEmpty) {
                  if (mapProvider.currentZoom >=
                          MapConstants.minZoomForMarkers &&
                      mapProvider.visibleRegion != null) {
                    stationProvider.loadStationsInRegion(
                      mapProvider.visibleRegion!,
                    );
                  } else {
                    stationProvider.loadSampleStations();
                  }
                }
              });
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
