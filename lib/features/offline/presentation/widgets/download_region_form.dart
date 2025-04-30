// lib/features/offline/presentation/widgets/download_region_form.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/offline_manager_provider.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class DownloadRegionForm extends StatefulWidget {
  final MapboxMap mapboxMap;
  final String regionType;

  const DownloadRegionForm({
    super.key,
    required this.mapboxMap,
    required this.regionType,
  });

  @override
  State<DownloadRegionForm> createState() => _DownloadRegionFormState();
}

class _DownloadRegionFormState extends State<DownloadRegionForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  double _minZoom = 10.0;
  double _maxZoom = 15.0;
  int _estimatedSizeMb = 0;
  bool _isCalculating = false;

  @override
  void initState() {
    super.initState();

    // Set a default name based on region type
    if (widget.regionType == 'current') {
      _nameController.text = 'Current Map View';
    } else if (widget.regionType == 'favorites') {
      _nameController.text = 'My Favorites';
    } else {
      _nameController.text = 'Custom Region';
    }

    // Calculate estimated size
    _calculateEstimatedSize();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _calculateEstimatedSize() async {
    if (_isCalculating) return;

    setState(() {
      _isCalculating = true;
    });

    try {
      final provider = Provider.of<OfflineManagerProvider>(
        context,
        listen: false,
      );

      // Get visible region
      final cameraState = await widget.mapboxMap.getCameraState();
      final visibleRegion = await widget.mapboxMap.coordinateBoundsForCamera(
        CameraOptions(
          center: cameraState.center,
          zoom: cameraState.zoom,
          bearing: cameraState.bearing,
          pitch: cameraState.pitch,
        ),
      );

      // Calculate estimated size
      final sizeBytes = await provider.calculateDownloadSize(
        minLat: visibleRegion.southwest.coordinates.lat.toDouble(),
        maxLat: visibleRegion.northeast.coordinates.lat.toDouble(),
        minLon: visibleRegion.southwest.coordinates.lng.toDouble(),
        maxLon: visibleRegion.northeast.coordinates.lng.toDouble(),
        minZoom: _minZoom,
        maxZoom: _maxZoom,
      );

      setState(() {
        _estimatedSizeMb = (sizeBytes / (1024 * 1024)).ceil();
        _isCalculating = false;
      });
    } catch (e) {
      setState(() {
        _estimatedSizeMb = 0;
        _isCalculating = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error calculating size: $e')));
    }
  }

  // Helper method to get the current map style URI
  Future<String> _getMapStyle(MapboxMap mapboxMap) async {
    // In newer versions of Mapbox SDK, we access style differently
    try {
      // Try to access style directly
      final style = mapboxMap.style;
      return await style.getStyleURI();
    } catch (e) {
      // Fallback to default style if we can't get the current one
      print('Error getting map style: $e');
      return MapboxStyles.STANDARD; // Use a default style
    }
  }

  Future<void> _downloadRegion() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = Provider.of<OfflineManagerProvider>(
      context,
      listen: false,
    );

    final name = _nameController.text;
    bool success = false;

    if (widget.regionType == 'current') {
      success = await provider.downloadCurrentMapRegion(
        mapboxMap: widget.mapboxMap,
        regionName: name,
        minZoom: _minZoom,
        maxZoom: _maxZoom,
      );
    } else if (widget.regionType == 'favorites') {
      success = await provider.downloadFavoriteAreas(
        mapboxMap: widget.mapboxMap,
        minZoom: _minZoom,
        maxZoom: _maxZoom,
      );
    } else {
      // For custom area, we would need to get the bounds from the user
      // This is simplified for this example
      final cameraState = await widget.mapboxMap.getCameraState();
      final visibleRegion = await widget.mapboxMap.coordinateBoundsForCamera(
        CameraOptions(
          center: cameraState.center,
          zoom: cameraState.zoom,
          bearing: cameraState.bearing,
          pitch: cameraState.pitch,
        ),
      );

      final styleUrl = await _getMapStyle(widget.mapboxMap);

      success = await provider.downloadCustomArea(
        areaName: name,
        minLat: visibleRegion.southwest.coordinates.lat.toDouble(),
        maxLat: visibleRegion.northeast.coordinates.lat.toDouble(),
        minLon: visibleRegion.southwest.coordinates.lng.toDouble(),
        maxLon: visibleRegion.northeast.coordinates.lng.toDouble(),
        styleUrl: styleUrl,
        minZoom: _minZoom,
        maxZoom: _maxZoom,
      );
    }

    if (success && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Region Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a name for this region';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            Text('Zoom Levels', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Higher zoom levels show more detail but use more storage.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Min Zoom: ${_minZoom.toStringAsFixed(1)}'),
                Text('Max Zoom: ${_maxZoom.toStringAsFixed(1)}'),
              ],
            ),
            const SizedBox(height: 8),
            RangeSlider(
              values: RangeValues(_minZoom, _maxZoom),
              min: 5.0,
              max: 20.0,
              divisions: 15,
              labels: RangeLabels(
                _minZoom.toStringAsFixed(1),
                _maxZoom.toStringAsFixed(1),
              ),
              onChanged: (values) {
                setState(() {
                  _minZoom = values.start;
                  _maxZoom = values.end;
                });
                // Recalculate size when zoom levels change
                _calculateEstimatedSize();
              },
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estimated Download Size',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _isCalculating
                      ? const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : Center(
                        child: Text(
                          '$_estimatedSizeMb MB',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  const SizedBox(height: 8),
                  if (_estimatedSizeMb > 200)
                    Text(
                      'Warning: Large download size may impact device storage.',
                      style: TextStyle(color: Colors.orange[800], fontSize: 12),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Consumer<OfflineManagerProvider>(
              builder: (context, provider, child) {
                return ElevatedButton(
                  onPressed: provider.isDownloading ? null : _downloadRegion,
                  child: const Text('Download Region'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
