// lib/features/map/presentation/utils/map_style_manager.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:rivr/features/map/data/datasources/enhanced_clustered_map_datasource.dart';
import '../../../../core/constants/map_constants.dart';

/// Class to handle Mapbox style changes and related operations
class MapStyleManager {
  /// The MapboxMap instance
  final MapboxMap mapboxMap;

  /// The clustered map provider to notify about style changes
  final EnhancedClusteredMapProvider clusterProvider;

  /// The current map style
  String _currentStyle;
  String get currentStyle => _currentStyle;

  /// Completer that resolves when a style load finishes
  Completer<bool>? _styleLoadCompleter;

  /// Constructor
  MapStyleManager({
    required this.mapboxMap,
    required this.clusterProvider,
    String initialStyle = MapConstants.defaultMapStyle,
  }) : _currentStyle = initialStyle {
    // We don't need to set up a separate listener as the MapWidget already has
    // a mechanism to detect style loading completion
  }

  /// Change the map style with proper error handling and callbacks
  Future<bool> changeMapStyle(
    String newStyle, {
    VoidCallback? onStyleChanged,
    VoidCallback? onStyleChangeFailed,
  }) async {
    if (_currentStyle == newStyle) {
      print('Style unchanged: $newStyle');
      return true;
    }

    print('Changing map style to: $newStyle');
    _currentStyle = newStyle;

    // Create a completer to track style load completion
    _styleLoadCompleter = Completer<bool>();

    try {
      // Load the new style
      await mapboxMap.loadStyleURI(newStyle);

      // Since we can't listen to style load events directly,
      // use a delayed future to wait for style to load
      // This is a workaround until proper event handling is available
      await Future.delayed(const Duration(milliseconds: 1000));

      // Notify the cluster provider that style has changed
      // (needs to happen after style loads)
      clusterProvider.handleMapStyleChanged(mapboxMap);

      onStyleChanged?.call();
      return true;
    } catch (e) {
      print('Error changing map style: $e');
      onStyleChangeFailed?.call();
      return false;
    }
  }

  /// Handle 3D terrain enablement
  Future<bool> enable3DTerrain({double exaggeration = 1.5}) async {
    try {
      var styleObj = mapboxMap.style;

      try {
        // Remove existing source if it exists
        await styleObj.removeStyleSource('mapbox-dem');
        print("Removed existing mapbox-dem source");
      } catch (e) {
        // Source might not exist yet, which is fine
      }

      // Add the DEM source
      final demSource = '''{
        "type": "raster-dem",
        "url": "mapbox://mapbox.mapbox-terrain-dem-v1",
        "tileSize": 512,
        "maxzoom": 14.0
      }''';

      await styleObj.addStyleSource('mapbox-dem', demSource);

      // Set up the terrain
      final terrain = '''{
        "source": "mapbox-dem",
        "exaggeration": $exaggeration
      }''';

      await styleObj.setStyleTerrain(terrain);
      print("3D terrain enabled successfully");
      return true;
    } catch (e) {
      print('Error enabling 3D terrain: $e');
      return false;
    }
  }

  /// Disable 3D terrain
  Future<bool> disable3DTerrain() async {
    try {
      var styleObj = mapboxMap.style;
      await styleObj.setStyleTerrain("{}");
      print("3D terrain disabled successfully");
      return true;
    } catch (e) {
      print('Error disabling 3D terrain: $e');
      return false;
    }
  }

  /// Set camera pitch (tilt)
  Future<bool> setCameraPitch(double pitch) async {
    try {
      var cameraState = await mapboxMap.getCameraState();
      var cameraOptions = CameraOptions(
        center: cameraState.center,
        zoom: cameraState.zoom,
        bearing: cameraState.bearing,
        pitch: pitch,
      );
      await mapboxMap.setCamera(cameraOptions);
      return true;
    } catch (e) {
      print('Error setting camera pitch: $e');
      return false;
    }
  }

  /// Toggle 3D terrain on/off
  Future<bool> toggle3DTerrain(bool enable) async {
    final terrainResult =
        enable ? await enable3DTerrain() : await disable3DTerrain();

    if (terrainResult) {
      // Set appropriate camera pitch based on terrain mode
      await setCameraPitch(enable ? MapConstants.defaultTilt : 0.0);
      return true;
    }

    return false;
  }
}
