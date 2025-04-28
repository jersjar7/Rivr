// lib/features/map/presentation/utils/map_tap_handler.dart

import 'dart:math' as Math;
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:rivr/features/map/presentation/providers/enhanced_clustered_map_provider.dart';
import 'package:rivr/features/map/presentation/providers/station_provider.dart';

import '../providers/map_provider.dart';
import '../../../../core/constants/map_constants.dart';

/// Handles tap events on the map, including marker and cluster taps
class MapTapHandler {
  final MapboxMap mapboxMap;
  final BuildContext context;

  const MapTapHandler({required this.mapboxMap, required this.context});

  /// Set up the tap handlers for the map
  Future<void> setupTapHandlers() async {
    print("MapTapHandler: Setting up tap handlers");
    // The actual tap handling will be done through the MapWidget's onTapListener
    // which should be set up in the MapWidget creation.
    // This class will handle the business logic when taps occur.
  }

  /// Handle tap events from the map
  Future<void> handleMapTap(MapContentGestureContext tapContext) async {
    try {
      // Get tap coordinates
      final screenCoord = tapContext.touchPosition;
      final mapCoord = tapContext.point;
      final clusteredMapProvider = Provider.of<EnhancedClusteredMapProvider>(
        context,
        listen: false,
      );

      print(
        "Map tapped at screen coord: $screenCoord, map coord: ${mapCoord.coordinates.lat}, ${mapCoord.coordinates.lng}",
      );

      // Query for features at the tap location
      final features = await queryFeaturesAtPoint(screenCoord);

      // If no features found, deselect current station
      if (features.isEmpty) {
        clusteredMapProvider.deselectStation();
        return;
      }

      // Process the tap based on the features found
      await processFeatures(features, mapCoord);
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
  ) async {
    if (features.isEmpty) return;

    // Get the first feature that is not null
    final feature = features.firstWhere((f) => f != null, orElse: () => null);
    if (feature == null) return;

    // Check if the feature is a cluster
    final properties = feature.queriedFeature.feature as Map<String, dynamic>;

    // Handle cluster tap
    if (properties.containsKey('cluster') && properties['cluster'] == true) {
      await handleClusterTap(properties, mapCoord);
    }
    // Handle station tap
    else if (properties.containsKey('id')) {
      await handleStationTap(properties, mapCoord);
    }
  }

  /// Handle tap on a cluster
  Future<void> handleClusterTap(
    Map<String, dynamic> properties,
    Point mapCoord,
  ) async {
    final mapProvider = Provider.of<MapProvider>(context, listen: false);

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
  ) async {
    final stationProvider = Provider.of<StationProvider>(
      context,
      listen: false,
    );
    final clusteredMapProvider = Provider.of<EnhancedClusteredMapProvider>(
      context,
      listen: false,
    );

    final stationId = properties['id'].toString();

    print("Tapped on station with ID: $stationId");

    // Find matching station in our list
    try {
      final stations = stationProvider.stations;
      final tappedStation = stations.firstWhere(
        (station) => station.stationId.toString() == stationId,
      );

      // Select this station
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
          zoom: Math.max(13.0, currentZoom),
        ),
        MapAnimationOptions(
          duration: MapConstants.mapAnimationDurationMs,
          startDelay: MapConstants.mapAnimationDelayMs,
        ),
      );
    } catch (e) {
      print("Error finding station with ID $stationId: $e");
    }
  }

  /// Clean up resources
  void dispose() {
    // No need to unsubscribe from anything, as the MapWidget tap listeners
    // will be disposed when the widget is disposed
    print("MapTapHandler disposed");
  }
}
