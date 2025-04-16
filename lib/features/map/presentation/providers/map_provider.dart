// lib/features/map/presentation/providers/map_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../../core/constants/map_constants.dart';
import '../../domain/entities/search_result.dart';
import '../../domain/usecases/search_location.dart';

class MapProvider with ChangeNotifier {
  // Map controller
  MapboxMap? _mapboxMap;
  MapboxMap? get mapboxMap => _mapboxMap;

  // Map settings
  String _currentStyle = MapConstants.defaultMapStyle;
  String get currentStyle => _currentStyle;

  bool _is3DMode = true;
  bool get is3DMode => _is3DMode;

  double _currentZoom = MapConstants.defaultZoom;
  double get currentZoom => _currentZoom;

  CoordinateBounds? _visibleRegion;
  CoordinateBounds? get visibleRegion => _visibleRegion;

  bool _showZoomMessage = true;
  bool get showZoomMessage => _showZoomMessage;

  bool _isMapInitialized = false;
  bool get isMapInitialized => _isMapInitialized;

  // Points manager
  PointAnnotationManager? _pointAnnotationManager;
  PointAnnotationManager? get pointAnnotationManager => _pointAnnotationManager;

  // Loading state
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Error state
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Debounce timer
  Timer? _debounceTimer;

  // Search use case
  final SearchLocation searchLocationUseCase;

  MapProvider({required this.searchLocationUseCase});

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  // Called when the map is created
  void onMapCreated(MapboxMap mapboxMap) {
    print("MAP PROVIDER: Map created, initializing map");
    _mapboxMap = mapboxMap;
    _isMapInitialized = true;

    // Log the current style
    print("MAP PROVIDER: Using map style: $_currentStyle");

    // Create point annotation manager
    _createAnnotationManager();

    // Enable 3D terrain if 3D mode is enabled
    if (_is3DMode) {
      _enableTerrain();
    }

    // Initial update of the visible region
    updateVisibleRegion();

    print("MAP PROVIDER: Map initialization complete");
    notifyListeners();
  }

  // Helper method to trigger debounce
  void triggerDebounceTimer(VoidCallback callback) {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), callback);
  }

  // Create annotation manager for adding points
  Future<void> _createAnnotationManager() async {
    if (_mapboxMap == null) return;

    try {
      final annotationsManager = _mapboxMap!.annotations;
      _pointAnnotationManager =
          await annotationsManager.createPointAnnotationManager();
      notifyListeners();
    } catch (e) {
      print('Error creating annotation manager: $e');
      _setError('Failed to initialize map annotations');
    }
  }

  // Enable 3D terrain
  Future<void> _enableTerrain() async {
    if (_mapboxMap == null) return;

    try {
      var styleObj = _mapboxMap!.style;

      try {
        await styleObj.removeStyleSource('mapbox-dem');
      } catch (e) {
        // Source might not exist yet, which is fine
      }

      final demSource = '''{
        "type": "raster-dem",
        "url": "mapbox://mapbox.mapbox-terrain-dem-v1",
        "tileSize": 512,
        "maxzoom": 14.0
      }''';

      await styleObj.addStyleSource('mapbox-dem', demSource);

      final terrain = '''{
        "source": "mapbox-dem",
        "exaggeration": ${MapConstants.terrainExaggeration}
      }''';

      await styleObj.setStyleTerrain(terrain);
    } catch (e) {
      print('Error setting up terrain: $e');
      _setError('Failed to enable 3D terrain');
    }
  }

  // Disable 3D terrain
  Future<void> _disableTerrain() async {
    if (_mapboxMap == null) return;

    try {
      var styleObj = _mapboxMap!.style;
      await styleObj.setStyleTerrain("{}");
    } catch (e) {
      print('Error disabling terrain: $e');
      _setError('Failed to disable 3D terrain');
    }
  }

  // Update visible region
  Future<void> updateVisibleRegion() async {
    if (_mapboxMap == null) return;

    try {
      CameraState cameraState = await _mapboxMap!.getCameraState();
      _currentZoom = cameraState.zoom;

      _showZoomMessage = _currentZoom < MapConstants.minZoomForMarkers;

      CameraOptions cameraOptions = CameraOptions(
        center: cameraState.center,
        zoom: cameraState.zoom,
        bearing: cameraState.bearing,
        pitch: cameraState.pitch,
      );

      _visibleRegion = await _mapboxMap!.coordinateBoundsForCamera(
        cameraOptions,
      );

      notifyListeners();
    } catch (e) {
      print("Error getting visible region: $e");
      _setError('Failed to update map view');
    }
  }

  // Set camera pitch
  Future<void> setCameraPitch(double pitch) async {
    if (_mapboxMap == null) return;

    try {
      var cameraState = await _mapboxMap!.getCameraState();
      var cameraOptions = CameraOptions(
        center: cameraState.center,
        zoom: cameraState.zoom,
        bearing: cameraState.bearing,
        pitch: pitch,
      );
      await _mapboxMap!.setCamera(cameraOptions);
    } catch (e) {
      print('Error setting camera pitch: $e');
      _setError('Failed to adjust map view');
    }
  }

  // Toggle 3D terrain
  void toggle3DTerrain() {
    _is3DMode = !_is3DMode;

    if (_mapboxMap == null) {
      notifyListeners();
      return;
    }

    if (_is3DMode) {
      _enableTerrain();
      setCameraPitch(MapConstants.defaultTilt);
    } else {
      _disableTerrain();
      setCameraPitch(0);
    }

    notifyListeners();
  }

  // Go to location
  void goToLocation(Point point) {
    if (_mapboxMap == null) return;

    try {
      _mapboxMap!.flyTo(
        CameraOptions(
          center: point,
          zoom: MapConstants.minZoomForMarkers,
          pitch: _is3DMode ? MapConstants.defaultTilt : 0,
        ),
        MapAnimationOptions(
          duration: MapConstants.mapAnimationDurationMs,
          startDelay: MapConstants.mapAnimationDelayMs,
        ),
      );
    } catch (e) {
      print('Error going to location: $e');
      _setError('Failed to navigate to location');
    }
  }

  // Change map style
  void changeMapStyle(String style, VoidCallback onStyleChanged) {
    _currentStyle = style;
    notifyListeners();

    if (_mapboxMap == null) return;

    // Load the new style
    _mapboxMap!.loadStyleURI(style).then((_) {
      // Re-enable terrain if 3D mode is on
      if (_is3DMode) {
        _enableTerrain();
      }

      // Call the callback to notify that the style has changed
      onStyleChanged();
    });
  }

  // Zoom in
  Future<void> zoomIn() async {
    if (_mapboxMap == null) return;

    try {
      CameraState cameraState = await _mapboxMap!.getCameraState();
      await _mapboxMap!.setCamera(CameraOptions(zoom: cameraState.zoom + 1));
      await updateVisibleRegion();
    } catch (e) {
      print('Error zooming in: $e');
      _setError('Failed to zoom in');
    }
  }

  // Zoom out
  Future<void> zoomOut() async {
    if (_mapboxMap == null) return;

    try {
      CameraState cameraState = await _mapboxMap!.getCameraState();
      await _mapboxMap!.setCamera(CameraOptions(zoom: cameraState.zoom - 1));
      await updateVisibleRegion();
    } catch (e) {
      print('Error zooming out: $e');
      _setError('Failed to zoom out');
    }
  }

  // Search for location
  Future<List<SearchResult>> searchLocation(String query) async {
    if (query.isEmpty) return [];

    _setLoading(true);
    _clearError();

    try {
      final result = await searchLocationUseCase(query);

      _setLoading(false);

      return result.fold((failure) {
        _setError(failure.message);
        return [];
      }, (searchResults) => searchResults);
    } catch (e) {
      _setLoading(false);
      _setError('Error searching location: $e');
      return [];
    }
  }

  // Helper methods for state management
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void disposeMap() {
    print("MAP PROVIDER: disposeMap called");
    _mapboxMap = null;
    _pointAnnotationManager = null;
    _isMapInitialized = false;
    notifyListeners();
  }
}
