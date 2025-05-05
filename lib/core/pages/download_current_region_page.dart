// lib/core/pages/download_current_region_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../constants/map_constants.dart';
import '../services/offline_manager_service.dart';
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
          zoomEnabled: true,
          pitchEnabled: false,
        ),
      );

      // Set attribution position
      await mapboxMap.attribution.updateSettings(
        AttributionSettings(
          position: OrnamentPosition(
            top: null,
            left: 10,
            bottom: 10,
            right: null,
          ),
        ),
      );

      // Set compass position
      await mapboxMap.compass.updateSettings(
        CompassSettings(
          position: OrnamentPosition(
            top: 10,
            left: null,
            bottom: null,
            right: 10,
          ),
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
