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
    _setupStyleLoadedListener();
  }

  /// Set up a listener for style loaded events
  void _setupStyleLoadedListener() {
    // Use the correct event listener approach for Mapbox
    mapboxMap.setOnStyleLoadedListener(() {
      print('Map style loaded: $_currentStyle');

      // Resolve any pending style load completion
      _styleLoadCompleter?.complete(true);
      _styleLoadCompleter = null;

      // Notify the cluster provider that style has changed
      clusterProvider.handleMapStyleChanged(mapboxMap);
    });
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

      // Wait for style to load completely
      final result = await _styleLoadCompleter!.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('Style load timeout - assuming success');
          return true;
        },
      );

      if (result) {
        print('Style change successful');
        onStyleChanged?.call();
        return true;
      } else {
        print('Style change indicated failure');
        onStyleChangeFailed?.call();
        return false;
      }
    } catch (e) {
      print('Error changing map style: $e');
      _styleLoadCompleter?.completeError(e);
      _styleLoadCompleter = null;
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
