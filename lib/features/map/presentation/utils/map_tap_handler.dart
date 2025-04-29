// lib/features/map/presentation/utils/map_tap_handler.dart

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
      // Safely extract properties from the feature
      final Map<String, dynamic> properties = {};

      // Extract properties from the feature
      final queryFeature = feature.queriedFeature.feature;
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

      // Handle station tap - check for 'id' or 'properties.id'
      String? stationId;
      if (properties.containsKey('id')) {
        stationId = properties['id'].toString();
      } else if (properties.containsKey('properties') &&
          properties['properties'] is Map &&
          (properties['properties'] as Map).containsKey('id')) {
        stationId = properties['properties']['id'].toString();
      }

      if (stationId != null) {
        await handleStationTap(
          stationId,
          mapCoord,
          properties,
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
    String stationId,
    Point mapCoord,
    Map<String, dynamic> properties,
    EnhancedClusteredMapProvider clusteredMapProvider,
    StationProvider stationProvider,
    MapProvider mapProvider,
  ) async {
    print("Tapped on station with ID: $stationId");
    print(
      "Attempting to find station with ID: $stationId in ${stationProvider.stations.length} stations",
    );

    try {
      // Try to parse the station ID as an integer
      final int stationIdInt = int.parse(stationId);

      // Variables for station information
      MapStation? tappedStation;
      String? stationName;

      // Extract station name from properties if available
      if (properties.containsKey('name')) {
        stationName = properties['name'].toString();
      } else if (properties.containsKey('properties') &&
          properties['properties'] is Map &&
          (properties['properties'] as Map).containsKey('name')) {
        stationName = properties['properties']['name'].toString();
      } else {
        stationName = "Station $stationId";
      }

      print("Station name from properties: $stationName");

      // Try to find the station in the provider's list
      try {
        tappedStation = stationProvider.stations.firstWhere(
          (station) => station.stationId == stationIdInt,
        );
        print(
          "Found matching station in provider: ${tappedStation.stationId}, name: ${tappedStation.name}",
        );
      } catch (e) {
        // Station not found in provider's list, create a temporary one
        print("Station not found in provider, creating temporary station");
        tappedStation = MapStation(
          stationId: stationIdInt,
          lat: mapCoord.coordinates.lat.toDouble(),
          lon: mapCoord.coordinates.lng.toDouble(),
          name: stationName,
          // Set other properties as needed
        );
      }

      // Set this station as selected in the provider
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
      print("Showing info panel for station: ${tappedStation.stationId}");
      _showInfoPanel(
        tappedStation,
        clusteredMapProvider,
        stationProvider,
        mapProvider,
      );
    } catch (e) {
      print("Error handling station tap: $e");
    }
  }

  /// Show the stream info panel for the selected station
  void _showInfoPanel(
    MapStation station,
    EnhancedClusteredMapProvider clusteredMapProvider,
    StationProvider stationProvider,
    MapProvider mapProvider,
  ) {
    try {
      // Remove existing panel first
      _removeInfoPanel();

      print("Creating info panel for station: ${station.stationId}");

      // Find the overlay to add our widget to
      final overlay = Overlay.of(context);

      // Create a new info panel
      _currentInfoPanel = StreamInfoPanel(
        station: station,
        onClose: () {
          // When closed, deselect the station and remove the panel
          print("Closing info panel");
          clusteredMapProvider.deselectStation();
          _removeInfoPanel();
        },
        onAddToFavorites: (station) async {
          // Handle adding to favorites
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
      print("Info panel inserted into overlay");
    } catch (e) {
      print("Error showing info panel: $e");
    }
  }

  /// Remove the current info panel if it exists
  void _removeInfoPanel() {
    if (_overlayEntry != null) {
      try {
        _overlayEntry!.remove();
        print("Info panel removed from overlay");
      } catch (e) {
        print("Error removing info panel: $e");
      } finally {
        _overlayEntry = null;
        _currentInfoPanel = null;
      }
    }
  }

  /// Clean up resources when map is disposed
  void dispose() {
    _removeInfoPanel();
  }
}
