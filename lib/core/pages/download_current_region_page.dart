// lib/core/pages/download_current_region_page.dart

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../constants/map_constants.dart';
import '../widgets/download_region_form.dart';

class DownloadCurrentRegionPage extends StatefulWidget {
  const DownloadCurrentRegionPage({super.key});

  @override
  State<DownloadCurrentRegionPage> createState() =>
      _DownloadCurrentRegionPageState();
}

class _DownloadCurrentRegionPageState extends State<DownloadCurrentRegionPage> {
  MapboxMap? _mapboxMap;
  bool _mapInitialized = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Download Current Region')),
      body: Column(
        children: [
          // Map preview (upper half)
          Expanded(child: _buildMapPreview()),
          // Download form (lower half)
          Expanded(
            child:
                _mapInitialized
                    ? DownloadRegionForm(
                      mapboxMap: _mapboxMap!,
                      regionType: 'current',
                    )
                    : const Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPreview() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!, width: 1.0),
        ),
      ),
      child: _buildMapboxMap(),
    );
  }

  Widget _buildMapboxMap() {
    return MapWidget(
      key: const ValueKey('mapPreview'),
      styleUri: MapConstants.defaultMapStyle,
      cameraOptions: CameraOptions(
        center: MapConstants.defaultCenter,
        zoom: MapConstants.defaultZoom,
      ),
      onMapCreated: _onMapCreated,
    );
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    try {
      // Enable gestures with the updated API
      await mapboxMap.gestures.updateSettings(
        GesturesSettings(
          scrollEnabled: true,
          rotateEnabled: true,
          pinchToZoomEnabled: true,
          doubleTapToZoomInEnabled: true,
          doubleTouchToZoomOutEnabled: true,
          quickZoomEnabled: true,
          pitchEnabled: false,
        ),
      );

      // Set attribution position to bottom-left with margins
      await mapboxMap.attribution.updateSettings(
        AttributionSettings(
          position: OrnamentPosition.BOTTOM_LEFT,
          marginLeft: 10,
          marginBottom: 10,
        ),
      );

      // Set compass position to top-right with margins
      await mapboxMap.compass.updateSettings(
        CompassSettings(
          position: OrnamentPosition.TOP_RIGHT,
          marginTop: 10,
          marginRight: 10,
        ),
      );

      // Wait a bit for the map to fully initialize
      await Future.delayed(const Duration(milliseconds: 300));

      setState(() {
        _mapInitialized = true;
      });
    } catch (e) {
      print('Error configuring map: $e');
      // Still mark as initialized to show the form
      setState(() {
        _mapInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    // Release any map resources
    _mapboxMap = null;
    super.dispose();
  }
}
