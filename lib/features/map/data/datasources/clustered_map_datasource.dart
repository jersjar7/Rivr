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

      // Create an empty GeoJSON feature collection
      final emptyFeatureCollection = {
        "type": "FeatureCollection",
        "features": [],
      };

      // Add the GeoJSON source with clustering enabled
      final geoJsonSource = GeoJsonSource(
        id: _sourceId,
        data: json.encode(emptyFeatureCollection),
        cluster: true,
        clusterMaxZoom: 14,
        clusterRadius: 50,
      );

      await style.addSource(geoJsonSource);

      // Add layer for clusters
      final clusterLayer = CircleLayer(
        id: _clusterLayerId,
        sourceId: _sourceId,
        filter: ["has", "point_count"],
        circleColor: [
          "step",
          ["get", "point_count"],
          "#51bbd6",
          20,
          "#2389DA",
          100,
          "#f1f075",
          750,
          "#f28cb1",
        ],
        circleRadius: [
          "step",
          ["get", "point_count"],
          15,
          20,
          20,
          100,
          25,
          750,
          30,
        ],
        circleStrokeWidth: 1,
        circleStrokeColor: "#ffffff",
      );

      await style.addLayer(clusterLayer);

      // Add layer for cluster counts
      final clusterCountLayer = SymbolLayer(
        id: _clusterCountLayerId,
        sourceId: _sourceId,
        filter: ["has", "point_count"],
        textField: "{point_count_abbreviated}",
        textSize: 12,
        textFont: ["Open Sans Bold"],
        textAllowOverlap: true,
        textColor: "#ffffff",
      );

      await style.addLayer(clusterCountLayer);

      // Add layer for individual points
      final pointLayer = CircleLayer(
        id: _unclusteredPointLayerId,
        sourceId: _sourceId,
        filter: [
          "!",
          ["has", "point_count"],
        ],
        circleColor: ["get", "color"],
        circleRadius: 8,
        circleStrokeWidth: 1,
        circleStrokeColor: "#ffffff",
      );

      await style.addLayer(pointLayer);

      // Add layer for individual point labels
      final labelLayer = SymbolLayer(
        id: _unclusteredLabelLayerId,
        sourceId: _sourceId,
        filter: [
          "!",
          ["has", "point_count"],
        ],
        textField: ["get", "name"],
        textSize: 11,
        textOffset: [0, 1.5],
        textAnchor: TextAnchor.TOP,
        textAllowOverlap: false,
        textIgnorePlacement: false,
        textColor: "#333333",
        textHaloColor: "#ffffff",
        textHaloWidth: 1,
      );

      await style.addLayer(labelLayer);

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
      // Note: MapWidget has the onTapListener, not MapboxMap
      mapboxMap.onMapTap = (coordinate) async {
        print('Map tapped at: ${coordinate.x}, ${coordinate.y}');

        // Convert screen point to map coordinate
        var point = await mapboxMap.coordinateForPixel(
          ScreenCoordinate(x: coordinate.x, y: coordinate.y),
        );

        // Create a small query rectangle around the tap point
        final double tapBuffer = 10.0; // pixels

        // Query for features within the rectangle
        try {
          final featureQueryOptions = RenderedQueryOptions(
            layerIds: [_clusterLayerId, _unclusteredPointLayerId],
            filter: null,
          );

          // Create a query geometry from the screen coordinate
          final queryGeometry = RenderedQueryGeometry.fromScreenCoordinate(
            ScreenCoordinate(x: coordinate.x, y: coordinate.y),
          );

          final features = await mapboxMap.queryRenderedFeatures(
            queryGeometry,
            featureQueryOptions,
          );

          if (features.isNotEmpty) {
            final feature = features.first!;

            // Check if it's a cluster
            final properties = feature.feature.properties;
            if (properties != null &&
                properties.containsKey('cluster') &&
                properties['cluster'] == true) {
              // Handle cluster tap
              print('Cluster tapped: ${properties['point_count']} points');

              // Create a mapbox Point from the tap coordinates
              final clusterPoint = Point(
                coordinates: Position(point.longitude, point.latitude),
              );

              // Use the current stations list to find stations in this area
              final List<MapStation> stationsParam = stations ?? [];
              final clusteredStations = _getApproximateClusterStations(
                stationsParam,
                point.latitude,
                point.longitude,
                // Use cluster radius as a reference for finding stations
                50.0 / (await mapboxMap.getCameraState()).zoom,
              );

              if (clusteredStations.isNotEmpty) {
                onClusterTapped(clusterPoint, clusteredStations);
              }
            } else {
              // Handle individual station tap
              final stationId = properties?['id'];
              if (stationId != null) {
                final List<MapStation> stationsParam = stations ?? [];
                // Find the station in our list
                try {
                  final stationData = stationsParam.firstWhere(
                    (station) =>
                        station.stationId.toString() == stationId.toString(),
                  );
                  onStationTapped(stationData);
                } catch (e) {
                  print('Station not found: $e');
                }
              }
            }
          }
        } catch (e) {
          print('Error querying features: $e');
        }

        return true;
      };
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
