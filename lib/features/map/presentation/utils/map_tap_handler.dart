// lib/features/map/presentation/utils/map_tap_handler.dart - Updated
import 'dart:math' as Math;
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:rivr/features/map/domain/entities/map_station.dart';

import '../providers/enhanced_clustered_map_provider.dart';
import '../providers/station_provider.dart';
import '../providers/map_provider.dart';
import '../widgets/stream_info_panel.dart';
import '../../../../core/constants/map_constants.dart';

class MapTapHandler {
  final MapboxMap mapboxMap;
  final BuildContext context;

  // Track the currently displayed info panel
  StreamInfoPanel? _currentInfoPanel;
  OverlayEntry? _overlayEntry;

  MapTapHandler({required this.mapboxMap, required this.context});

  /// Set up the tap handler
  Future<void> setupTapHandlers() async {
    print("MapTapHandler: Setting up tap handlers");
    // The actual handling will be done via the handleMapTap method
    // which is connected to the MapWidget's onTapListener in map_page.dart
  }

  /// Handle tap events from the map
  Future<void> handleMapTap(MapContentGestureContext tapContext) async {
    try {
      // Get providers
      final clusteredMapProvider = Provider.of<EnhancedClusteredMapProvider>(
        context,
        listen: false,
      );
      final stationProvider = Provider.of<StationProvider>(
        context,
        listen: false,
      );
      final mapProvider = Provider.of<MapProvider>(context, listen: false);

      // Get tap coordinates
      final screenCoord = tapContext.touchPosition;
      final mapCoord = tapContext.point;

      print(
        "Map tapped at screen coord: $screenCoord, map coord: ${mapCoord.coordinates.lat}, ${mapCoord.coordinates.lng}",
      );

      // Query for features at the tap location
      final features = await queryFeaturesAtPoint(screenCoord);

      // If no features found, deselect current station and remove info panel
      if (features.isEmpty) {
        print("No features found at tap location, deselecting station");
        clusteredMapProvider.deselectStation();
        _removeInfoPanel();
        return;
      }

      // Process the tap based on the features found
      await processFeatures(
        features,
        mapCoord,
        clusteredMapProvider,
        stationProvider,
        mapProvider,
      );
    } catch (e) {
      print("Error handling map tap: $e");
    }
  }

  /// Query for features at the given screen coordinate
  Future<List<QueriedRenderedFeature?>> queryFeaturesAtPoint(
    ScreenCoordinate point,
  ) async {
    try {
      // Create a rendered query geometry for the point
      final geometry = RenderedQueryGeometry.fromScreenCoordinate(point);

      // Query for rendered features at this point
      final options = RenderedQueryOptions(
        layerIds: [
          'clusters',
          'unclustered-points',
          'unclustered-points-circle',
        ],
        filter: null,
      );

      final features = await mapboxMap.queryRenderedFeatures(geometry, options);

      if (features.isNotEmpty) {
        print("Found ${features.length} features at tap location");
      }

      return features;
    } catch (e) {
      print("Error querying features: $e");
      return [];
    }
  }

  /// Process the features found at the tap location
  Future<void> processFeatures(
    List<QueriedRenderedFeature?> features,
    Point mapCoord,
    EnhancedClusteredMapProvider clusteredMapProvider,
    StationProvider stationProvider,
    MapProvider mapProvider,
  ) async {
    if (features.isEmpty) return;

    // Get the first feature that is not null
    final feature = features.firstWhere((f) => f != null, orElse: () => null);
    if (feature == null) return;

    try {
      // Safely cast the feature to Map<String, dynamic>
      final Map<String, dynamic> properties = {};

      // Get the feature safely
      final queryFeature = feature.queriedFeature.feature;
      // Convert all keys to strings
      queryFeature.forEach((key, value) {
        if (key is String) {
          properties[key] = value;
        }
      });

      print("Feature properties: $properties");

      // Handle cluster tap
      if (properties.containsKey('cluster') && properties['cluster'] == true) {
        await handleClusterTap(properties, mapCoord, mapProvider);
        // Remove info panel when zooming into a cluster
        _removeInfoPanel();
        return;
      }

      // Handle station tap
      if (properties.containsKey('id')) {
        await handleStationTap(
          properties,
          mapCoord,
          clusteredMapProvider,
          stationProvider,
          mapProvider,
        );
        return;
      }
    } catch (e) {
      print("Error processing features: $e");
    }
  }

  /// Handle tap on a cluster
  Future<void> handleClusterTap(
    Map<String, dynamic> properties,
    Point mapCoord,
    MapProvider mapProvider,
  ) async {
    print("Tapped on cluster with ${properties['point_count']} points");

    // Zoom in to expand the cluster
    final newZoom = mapProvider.currentZoom + 2.0;

    mapboxMap.flyTo(
      CameraOptions(center: mapCoord, zoom: newZoom),
      MapAnimationOptions(
        duration: MapConstants.mapAnimationDurationMs,
        startDelay: MapConstants.mapAnimationDelayMs,
      ),
    );
  }

  /// Handle tap on an individual station
  Future<void> handleStationTap(
    Map<String, dynamic> properties,
    Point mapCoord,
    EnhancedClusteredMapProvider clusteredMapProvider,
    StationProvider stationProvider,
    MapProvider mapProvider,
  ) async {
    final stationId = properties['id'].toString();
    print("Tapped on station with ID: $stationId");

    // Find matching station in our list
    try {
      final stations = stationProvider.stations;

      // Convert stationId to int if necessary
      final int stationIdInt = int.parse(stationId);

      // Find the tapped station
      final tappedStation = stations.firstWhere(
        (station) => station.stationId == stationIdInt,
        orElse: () => throw Exception("Station not found in provider"),
      );

      print(
        "Found matching station: ${tappedStation.stationId}, name: ${tappedStation.name}",
      );

      // Select this station in the provider
      clusteredMapProvider.selectStation(tappedStation);

      // Center map on the selected station with a nice zoom level
      final currentZoom = await mapboxMap.getCameraState().then(
        (state) => state.zoom,
      );

      mapboxMap.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(tappedStation.lon, tappedStation.lat),
          ),
          zoom: Math.max(14.0, currentZoom), // Zoom in closer to the station
        ),
        MapAnimationOptions(
          duration: MapConstants.mapAnimationDurationMs,
          startDelay: MapConstants.mapAnimationDelayMs,
        ),
      );

      // Show the info panel for the selected station
      _showInfoPanel(
        tappedStation,
        clusteredMapProvider,
        stationProvider,
        mapProvider,
      );
    } catch (e) {
      print("Error finding station with ID $stationId: $e");
    }
  }

  /// Show the stream info panel for the selected station
  void _showInfoPanel(
    MapStation station,
    EnhancedClusteredMapProvider clusteredMapProvider,
    StationProvider stationProvider,
    MapProvider mapProvider,
  ) {
    // Remove existing panel first
    _removeInfoPanel();

    // Find the overlay to add our widget to
    final overlay = Overlay.of(context);

    // Create a new info panel
    _currentInfoPanel = StreamInfoPanel(
      station: station,
      onClose: () {
        // When closed, deselect the station and remove the panel
        clusteredMapProvider.deselectStation();
        _removeInfoPanel();
      },
      onAddToFavorites: (station) async {
        // Handle adding to favorites - you can implement this later
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added ${station.name ?? "Station ${station.stationId}"} to favorites',
            ),
          ),
        );
      },
      onViewForecast: (reachId, stationName) {
        // Navigate to the forecast page
        Navigator.pushNamed(
          context,
          '/forecast',
          arguments: {'reachId': reachId, 'stationName': stationName},
        );
      },
    );

    // Create an overlay entry to show the panel
    _overlayEntry = OverlayEntry(builder: (context) => _currentInfoPanel!);

    // Add the entry to the overlay
    overlay.insert(_overlayEntry!);
  }

  /// Remove the current info panel if it exists
  void _removeInfoPanel() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
      _currentInfoPanel = null;
    }
  }

  /// Clean up resources when map is disposed
  void dispose() {
    _removeInfoPanel();
  }
}
