// lib/features/map/data/datasources/clustered_map_datasource.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../models/geojson_models.dart';
import '../../domain/entities/map_station.dart';
import '../../../../core/error/exceptions.dart';

abstract class ClusteredMapDataSource {
  /// Initialize cluster sources and layers on the map
  Future<void> initializeClusterLayers(MapboxMap mapboxMap);

  /// Update station data in the cluster source
  Future<void> updateClusterData(
    MapboxMap mapboxMap,
    List<MapStation> stations,
  );

  /// Clean up resources
  Future<void> dispose(MapboxMap mapboxMap);

  /// Setup tap handling for clusters and individual points
  Future<void> setupTapHandling(
    MapboxMap mapboxMap,
    Function(MapStation) onStationTapped,
    Function(Point, List<MapStation>) onClusterTapped,
  );
}

class ClusteredMapDataSourceImpl implements ClusteredMapDataSource {
  static const String _sourceId = 'stations-source';
  static const String _clusterLayerId = 'clusters-layer';
  static const String _clusterCountLayerId = 'cluster-count-layer';
  static const String _unclusteredPointLayerId = 'unclustered-point-layer';
  static const String _unclusteredLabelLayerId = 'unclustered-label-layer';

  bool _isInitialized = false;

  @override
  Future<void> initializeClusterLayers(MapboxMap mapboxMap) async {
    if (_isInitialized) return;

    try {
      final style = mapboxMap.style;

      // Check if source already exists and remove it if necessary
      await _safelyRemoveExistingLayers(style);

      // Add the GeoJSON source with clustering enabled
      final sourceProperties = '''
        {
          "type": "geojson",
          "data": {"type": "FeatureCollection", "features": []},
          "cluster": true,
          "clusterMaxZoom": 14,
          "clusterRadius": 50
        }
      ''';

      await style.addSource(_sourceId, sourceProperties);

      // Add layer for clusters
      final clusterLayerProperties = '''
        {
          "id": "$_clusterLayerId",
          "type": "circle",
          "source": "$_sourceId",
          "filter": ["has", "point_count"],
          "paint": {
            "circle-color": [
              "step",
              ["get", "point_count"],
              "#51bbd6",
              20,
              "#2389DA",
              100,
              "#f1f075",
              750,
              "#f28cb1"
            ],
            "circle-radius": [
              "step",
              ["get", "point_count"],
              15,
              20,
              20,
              100,
              25,
              750,
              30
            ],
            "circle-stroke-width": 1,
            "circle-stroke-color": "#ffffff"
          }
        }
      ''';

      await style.addLayer(clusterLayerProperties);

      // Add layer for cluster counts
      final clusterCountLayerProperties = '''
        {
          "id": "$_clusterCountLayerId",
          "type": "symbol",
          "source": "$_sourceId",
          "filter": ["has", "point_count"],
          "layout": {
            "text-field": "{point_count_abbreviated}",
            "text-size": 12,
            "text-font": ["Open Sans Bold"],
            "text-allow-overlap": true
          },
          "paint": {
            "text-color": "#ffffff"
          }
        }
      ''';

      await style.addLayer(clusterCountLayerProperties);

      // Add layer for individual points
      final pointLayerProperties = '''
        {
          "id": "$_unclusteredPointLayerId",
          "type": "circle",
          "source": "$_sourceId",
          "filter": ["!", ["has", "point_count"]],
          "paint": {
            "circle-color": ["get", "color"],
            "circle-radius": 8,
            "circle-stroke-width": 1,
            "circle-stroke-color": "#ffffff"
          }
        }
      ''';

      await style.addLayer(pointLayerProperties);

      // Add layer for individual point labels
      final labelLayerProperties = '''
        {
          "id": "$_unclusteredLabelLayerId",
          "type": "symbol",
          "source": "$_sourceId",
          "filter": ["!", ["has", "point_count"]],
          "layout": {
            "text-field": ["get", "name"],
            "text-size": 11,
            "text-offset": [0, 1.5],
            "text-anchor": "top",
            "text-allow-overlap": false,
            "text-ignore-placement": false
          },
          "paint": {
            "text-color": "#333333",
            "text-halo-color": "#ffffff",
            "text-halo-width": 1
          }
        }
      ''';

      await style.addLayer(labelLayerProperties);

      _isInitialized = true;
    } catch (e) {
      print('Error initializing cluster layers: $e');
      throw ServerException(message: 'Failed to initialize cluster layers: $e');
    }
  }

  @override
  Future<void> updateClusterData(
    MapboxMap mapboxMap,
    List<MapStation> stations,
  ) async {
    if (!_isInitialized) {
      await initializeClusterLayers(mapboxMap);
    }

    try {
      final featureCollection = stations.toGeoJsonFeatureCollection();
      final geojson = jsonEncode(featureCollection.toJson());

      // Update the source data using the source property approach
      await mapboxMap.style.setStyleSourceProperty(_sourceId, 'data', geojson);
    } catch (e) {
      print('Error updating cluster data: $e');
      throw ServerException(message: 'Failed to update cluster data: $e');
    }
  }

  @override
  Future<void> dispose(MapboxMap mapboxMap) async {
    if (!_isInitialized) return;

    try {
      await _safelyRemoveExistingLayers(mapboxMap.style);
      _isInitialized = false;
    } catch (e) {
      print('Error disposing clustered map source: $e');
    }
  }

  @override
  Future<void> setupTapHandling(
    MapboxMap mapboxMap,
    Function(MapStation) onStationTapped,
    Function(Point, List<MapStation>) onClusterTapped,
  ) async {
    if (!_isInitialized) return;

    try {
      // Set up tap event handler
      mapboxMap.onTapListener.add(
        OnTapListener((point) async {
          print('Map tapped at: ${point.x}, ${point.y}');

          // Convert screen point to map coordinate
          final coordinate = mapboxMap.coordinateForPixel(
            ScreenCoordinate(x: point.x, y: point.y),
          );

          // Create a small query rectangle around the tap point
          final double tapBuffer = 10.0; // pixels
          final topLeft = mapboxMap.coordinateForPixel(
            ScreenCoordinate(x: point.x - tapBuffer, y: point.y - tapBuffer),
          );
          final bottomRight = mapboxMap.coordinateForPixel(
            ScreenCoordinate(x: point.x + tapBuffer, y: point.y + tapBuffer),
          );

          // Query for features within the rectangle
          try {
            final featureQueryOptions = RenderedQueryOptions(
              layerIds: [_clusterLayerId, _unclusteredPointLayerId],
              filter: null,
            );

            // Create a query geometry from the screen rectangle
            final queryGeometry = RenderedQueryGeometry.fromScreenBox(
              min: ScreenBox(
                min: ScreenCoordinate(
                  x: point.x - tapBuffer,
                  y: point.y - tapBuffer,
                ),
                max: ScreenCoordinate(
                  x: point.x + tapBuffer,
                  y: point.y + tapBuffer,
                ),
              ),
            );

            final features = await mapboxMap.queryRenderedFeatures(
              queryGeometry,
              featureQueryOptions,
            );

            if (features.isNotEmpty) {
              final feature = features.first;

              // Check if it's a cluster
              final properties = feature.feature.properties;
              if (properties != null &&
                  properties.containsKey('cluster') &&
                  properties['cluster'] == true) {
                // Handle cluster tap
                print('Cluster tapped: ${properties['point_count']} points');

                // For getting stations in the cluster, we'll need to use a different approach
                // Since Mapbox Maps Flutter doesn't directly expose cluster expansion,
                // we'll use a zoom-in approach or query the source data

                // Create a mapbox Point from the tap coordinates
                final clusterPoint = Point(
                  coordinates: Position(
                    coordinate.longitude,
                    coordinate.latitude,
                  ),
                );

                // Use the current stations list to find stations in this area
                // This is a simplified approach - for a real implementation,
                // you may want to filter based on distance or use Mapbox's GeoJSON query
                final clusteredStations = _getApproximateClusterStations(
                  stations,
                  coordinate.latitude,
                  coordinate.longitude,
                  // Use cluster radius as a reference for finding stations
                  50.0 / mapboxMap.cameraState.zoom,
                );

                if (clusteredStations.isNotEmpty) {
                  onClusterTapped(clusterPoint, clusteredStations);
                }
              } else {
                // Handle individual station tap
                final stationId = properties?['id'];
                if (stationId != null) {
                  // Find the station in our list
                  final stationData = stations.firstWhere(
                    (station) =>
                        station.stationId.toString() == stationId.toString(),
                    orElse: () => stations.first, // Fallback
                  );

                  onStationTapped(stationData);
                }
              }
            }
          } catch (e) {
            print('Error querying features: $e');
          }

          return true;
        }),
      );
    } catch (e) {
      print('Error setting up tap handling: $e');
    }
  }

  // Helper methods
  Future<void> _safelyRemoveExistingLayers(StyleManager style) async {
    // Check if source exists
    try {
      await style.getStyleSourceProperty(_sourceId, 'type');

      // Source exists, remove layers first
      final layerIds = [
        _clusterLayerId,
        _clusterCountLayerId,
        _unclusteredPointLayerId,
        _unclusteredLabelLayerId,
      ];

      for (final layerId in layerIds) {
        try {
          await style.removeStyleLayer(layerId);
        } catch (e) {
          // Layer might not exist, which is fine
          print('Layer $layerId might not exist: $e');
        }
      }

      // Then remove the source
      await style.removeStyleSource(_sourceId);
    } catch (e) {
      // Source doesn't exist, which is fine
      print('Source $_sourceId might not exist: $e');
    }
  }

  // A simplified method to find stations that would be in a cluster
  // This is an approximation since we don't have direct access to Mapbox's
  // internal clustering algorithm
  List<MapStation> _getApproximateClusterStations(
    List<MapStation> allStations,
    double centerLat,
    double centerLon,
    double approxRadiusDegrees,
  ) {
    return allStations.where((station) {
      final latDiff = (station.lat - centerLat).abs();
      final lonDiff = (station.lon - centerLon).abs();

      // Simple approximation using a square rather than a circle
      return latDiff < approxRadiusDegrees && lonDiff < approxRadiusDegrees;
    }).toList();
  }
}
