// lib/features/map/presentation/providers/map_provider.dart

import 'dart:async';
import 'dart:math' as Math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geolocator;

import '../../../../core/constants/map_constants.dart';
import '../../../../core/services/location_service.dart';
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

  // Location state
  bool _userLocationEnabled = true;
  bool get userLocationEnabled => _userLocationEnabled;

  bool _isGettingLocation = false;
  bool get isGettingLocation => _isGettingLocation;

  geolocator.Position? _currentUserLocation;
  geolocator.Position? get currentUserLocation => _currentUserLocation;

  // Debounce timer
  Timer? _debounceTimer;

  // Search use case
  final SearchLocation searchLocationUseCase;

  // Location service
  final LocationService _locationService = LocationService.instance;

  // Add a boolean to track disposal state
  bool _isDisposed = false;

  MapProvider({required this.searchLocationUseCase});

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  // Called when the map is created
  void onMapCreated(MapboxMap mapboxMap) {
    print("MAP PROVIDER: Map created, initializing map");

    // If already initialized, don't reinitialize
    if (_isMapInitialized) {
      print("MAP PROVIDER: Map already initialized, skipping");
      return;
    }

    _mapboxMap = mapboxMap;
    _isMapInitialized = true;

    // Log the current style
    print("MAP PROVIDER: Using map style: $_currentStyle");

    // Create point annotation manager
    _createAnnotationManager();

    // Enable 3D terrain if 3D mode is enabled - with proper error handling
    if (_is3DMode) {
      _enableTerrain().catchError((e) {
        print('Error enabling terrain: $e');
        // Don't throw, just log the error
      });
    }

    // Initial update of the visible region
    updateVisibleRegion().catchError((e) {
      print('Error updating visible region: $e');
      // Don't throw, just log the error
    });

    print("MAP PROVIDER: Map initialization complete");
    notifyListeners();
  }

  /// Updates the current style without triggering a rebuild
  /// This is used for theme-driven style changes
  void setCurrentStyleWithoutRebuild(String styleUri) {
    if (_currentStyle != styleUri) {
      _currentStyle = styleUri;
      // Don't call notifyListeners() to avoid a rebuild cycle
      // The style will be applied directly to the MapWidget

      // Optionally save the style preference if you store it
      // For example:
      // _preferencesService.saveMapStyle(styleUri);

      print("MapProvider: Style updated to $styleUri without rebuild");
    }
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
    if (_isDisposed || _mapboxMap == null) return;

    try {
      // Add a delay to ensure the style has loaded
      await Future.delayed(const Duration(milliseconds: 500));

      var styleObj = _mapboxMap!.style;

      try {
        await styleObj.removeStyleSource('mapbox-dem');
        print("MAP PROVIDER: Removed existing mapbox-dem source");
      } catch (e) {
        // Source might not exist yet, which is fine
        print("MAP PROVIDER: No existing mapbox-dem source to remove: $e");
      }

      final demSource = '''{
      "type": "raster-dem",
      "url": "mapbox://mapbox.mapbox-terrain-dem-v1",
      "tileSize": 512,
      "maxzoom": 14.0
    }''';

      try {
        await styleObj.addStyleSource('mapbox-dem', demSource);
        print("MAP PROVIDER: Added mapbox-dem source");

        final terrain = '''{
        "source": "mapbox-dem",
        "exaggeration": ${MapConstants.terrainExaggeration}
      }''';

        await styleObj.setStyleTerrain(terrain);
        print("MAP PROVIDER: 3D terrain enabled successfully");
      } catch (e) {
        print('MAP PROVIDER: Error setting terrain data: $e');
      }
    } catch (e) {
      print('MAP PROVIDER: Error in _enableTerrain: $e');
      // Don't throw, just log the error
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

  // —— UPDATED: only call notify when zoom or zoom-message change —— ///
  // Update visible region
  Future<void> updateVisibleRegion() async {
    if (_mapboxMap == null) return;

    try {
      // Get current camera info
      CameraState cameraState = await _mapboxMap!.getCameraState();
      final newZoom = cameraState.zoom;
      final newShowZoomMessage = newZoom < MapConstants.minZoomForMarkers;

      // Build camera options for bounds calculation
      CameraOptions cameraOptions = CameraOptions(
        center: cameraState.center,
        zoom: newZoom,
        bearing: cameraState.bearing,
        pitch: cameraState.pitch,
      );

      // Compute new visible bounds
      final newBounds = await _mapboxMap!.coordinateBoundsForCamera(
        cameraOptions,
      );

      // Only rebuild the UI if zoom level or zoom‐hint flag actually changed
      if (newZoom != _currentZoom || newShowZoomMessage != _showZoomMessage) {
        _currentZoom = newZoom;
        _showZoomMessage = newShowZoomMessage;
        _visibleRegion = newBounds;
        notifyListeners();
      } else {
        // Still update bounds internally for clustering etc.
        _visibleRegion = newBounds;
      }
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
  void goToLocation(Point point, {double? zoom}) {
    if (_mapboxMap == null) return;

    try {
      // Get the zoom level to use - either the provided one or a default close-up zoom
      final zoomLevel =
          zoom ?? Math.max(MapConstants.minZoomForMarkers + 4.0, _currentZoom);

      _mapboxMap!.flyTo(
        CameraOptions(
          center: point,
          zoom: zoomLevel, // Use the calculated zoom level
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

  // LOCATION METHODS

  /// Toggle user location marker visibility
  void toggleUserLocationEnabled() {
    print(
      "MAP PROVIDER: Toggling user location enabled: $_userLocationEnabled -> ${!_userLocationEnabled}",
    );
    _userLocationEnabled = !_userLocationEnabled;
    notifyListeners();
  }

  /// Get current user location and center map on it
  Future<bool> goToCurrentLocation() async {
    if (_mapboxMap == null) return false;

    print("MAP PROVIDER: Getting current location");
    _isGettingLocation = true;
    notifyListeners();

    try {
      final position = await _locationService.getCurrentPosition(
        timeout: const Duration(seconds: 10),
      );

      if (position != null) {
        _currentUserLocation = position;

        // Create map point
        final point = Point(
          coordinates: Position(position.longitude, position.latitude),
        );

        // Center map respecting current zoom (don't force a specific zoom)
        goToLocation(point, zoom: _currentZoom);

        print(
          "MAP PROVIDER: Successfully centered on current location: ${position.latitude}, ${position.longitude}",
        );

        _isGettingLocation = false;
        notifyListeners();
        return true;
      } else {
        print("MAP PROVIDER: Could not get current location");
        _setError('Could not get current location');
        _isGettingLocation = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      print("MAP PROVIDER: Error getting current location: $e");
      _setError('Error getting location: ${e.toString()}');
      _isGettingLocation = false;
      notifyListeners();
      return false;
    }
  }

  /// Update current user location (for marker updates)
  Future<void> updateCurrentUserLocation() async {
    if (!_userLocationEnabled) return;

    try {
      final position = await _locationService.getCurrentPosition(
        timeout: const Duration(seconds: 5),
      );

      if (position != null) {
        _currentUserLocation = position;
        print(
          "MAP PROVIDER: Updated current user location: ${position.latitude}, ${position.longitude}",
        );
        notifyListeners();
      }
    } catch (e) {
      print("MAP PROVIDER: Error updating user location: $e");
      // Don't show error for background updates
    }
  }

  // Change map style with explicit error handling
  void changeMapStyle(String style, VoidCallback onStyleChanged) {
    print("MAP PROVIDER: Changing style to $style");
    _currentStyle = style;
    notifyListeners();

    if (_mapboxMap == null) return;

    try {
      // Load the new style with explicit error handling
      _mapboxMap!
          .loadStyleURI(style)
          .then((_) {
            print("MAP PROVIDER: Style changed successfully");

            // Re-enable terrain if 3D mode is on
            if (_is3DMode) {
              _enableTerrain();
            }

            // Call the callback to notify that the style has changed
            onStyleChanged();
          })
          .catchError((error) {
            print("MAP PROVIDER: Error changing style: $error");
            _setError('Failed to change map style: $error');
          });
    } catch (e) {
      print("MAP PROVIDER: Exception changing style: $e");
      _setError('Failed to change map style: $e');
    }
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

  // In lib/features/map/presentation/providers/map_provider.dart
  void disposeMap() {
    // Mark as disposed first
    _isDisposed = true;

    // Cleanup but don't notify
    _mapboxMap = null;
    _isMapInitialized = false;

    // No calls to notifyListeners()
  }

  // Set the current map style
  void setCurrentStyle(String style) {
    _currentStyle = style;
    notifyListeners();
  }
}
