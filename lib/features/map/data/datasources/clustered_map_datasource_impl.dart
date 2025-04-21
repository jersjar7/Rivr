// lib/features/map/data/datasources/clustered_map_datasource_impl.dart

import 'dart:convert';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'clustered_map_datasource.dart';
import '../../domain/entities/map_station.dart';

class ClusteredMapDataSourceImpl implements ClusteredMapDataSource {
  // Constants for clustering
  static const String _sourceId = 'stations-source';
  static const String _clustersLayerId = 'clusters';
  static const String _unclusteredPointsLayerId = 'unclustered-points';
  static const String _clusterCountLayerId = 'cluster-count';

  @override
  Future<void> initializeClusterLayers(MapboxMap mapboxMap) async {
    try {
      print("DEBUG: Initializing cluster layers");
      final style = mapboxMap.style;

      // Add the GeoJSON source with clustering enabled
      final sourceJson = '''{
        "type": "geojson",
        "data": { "type": "FeatureCollection", "features": [] },
        "cluster": true,
        "clusterMaxZoom": 14,
        "clusterRadius": 50
      }''';

      // Try to remove existing source if it exists
      try {
        // Remove all layers first (in correct order)
        await style.removeStyleLayer(_clusterCountLayerId);
        await style.removeStyleLayer(_unclusteredPointsLayerId);
        await style.removeStyleLayer(_clustersLayerId);
        await style.removeStyleSource(_sourceId);
        print("DEBUG: Removed existing clustering layers and source");
      } catch (e) {
        print("DEBUG: Some layers or source didn't exist: $e");
        // Continue - this is expected in first initialization
      }

      // Add a small delay to ensure cleanup completes
      await Future.delayed(const Duration(milliseconds: 100));

      // Add the source
      await style.addStyleSource(_sourceId, sourceJson);
      print("DEBUG: Added GeoJSON source");

      // Add a layer for clustered points
      final clusterLayer = '''{
        "id": "$_clustersLayerId",
        "type": "circle",
        "source": "$_sourceId",
        "filter": ["has", "point_count"],
        "paint": {
          "circle-color": [
            "step",
            ["get", "point_count"],
            "#51bbd6",
            10,
            "#f1f075",
            30,
            "#f28cb1"
          ],
          "circle-radius": [
            "step",
            ["get", "point_count"],
            20,
            10,
            25,
            30,
            30
          ]
        }
      }''';

      try {
        await style.removeStyleLayer(_clustersLayerId);
      } catch (e) {
        // Layer might not exist yet
      }
      await style.addStyleLayer(clusterLayer, null);
      print("DEBUG: Added cluster layer");

      // Add a layer for unclustered points
      final pointsLayer = '''{
        "id": "$_unclusteredPointsLayerId",
        "type": "circle",
        "source": "$_sourceId",
        "filter": ["!", ["has", "point_count"]],
        "paint": {
          "circle-color": ["get", "color"],
          "circle-radius": 8,
          "circle-stroke-width": 1,
          "circle-stroke-color": "#ffffff"
        }
      }''';

      try {
        await style.removeStyleLayer(_unclusteredPointsLayerId);
      } catch (e) {
        // Layer might not exist yet
      }
      await style.addStyleLayer(pointsLayer, null);
      print("DEBUG: Added unclustered points layer");

      // Add a layer for cluster counts
      final countLayer = '''{
        "id": "$_clusterCountLayerId",
        "type": "symbol",
        "source": "$_sourceId",
        "filter": ["has", "point_count"],
        "layout": {
          "text-field": "{point_count_abbreviated}",
          "text-font": ["DIN Offc Pro Medium", "Arial Unicode MS Bold"],
          "text-size": 12
        },
        "paint": {
          "text-color": "#ffffff"
        }
      }''';

      try {
        await style.removeStyleLayer(_clusterCountLayerId);
      } catch (e) {
        // Layer might not exist yet
      }
      await style.addStyleLayer(countLayer, null);
      print("DEBUG: Added cluster count layer");

      print("DEBUG: Cluster layers initialized successfully");
    } catch (e) {
      print("ERROR: Error initializing cluster layers: $e");
      rethrow;
    }
  }

  @override
  Future<void> updateClusterData(
    MapboxMap mapboxMap,
    List<MapStation> stations,
  ) async {
    try {
      print("DEBUG: Updating cluster data with ${stations.length} stations");

      if (stations.isEmpty) {
        print("WARNING: No stations to display");
        return;
      }

      // Convert stations to GeoJSON format
      final features =
          stations.map((station) {
            return {
              "type": "Feature",
              "properties": {
                "id": station.stationId.toString(),
                "name": station.name ?? "Station ${station.stationId}",
                "type": station.type ?? "unknown",
                "color": station.color ?? "#2389DA",
              },
              "geometry": {
                "type": "Point",
                "coordinates": [station.lon, station.lat],
              },
            };
          }).toList();

      final geojsonData = {"type": "FeatureCollection", "features": features};

      // Update the source data
      final style = mapboxMap.style;
      final sourceProperty = jsonEncode({"data": geojsonData});

      await style.setStyleSourceProperty(_sourceId, "data", sourceProperty);

      print("DEBUG: Updated cluster data with ${stations.length} stations");
    } catch (e) {
      print("ERROR: Error updating cluster data: $e");
      rethrow;
    }
  }

  @override
  Future<void> setupTapHandling(
    MapboxMap mapboxMap,
    Function(MapStation) onStationTapped,
    Function(Point, List<MapStation>) onClusterTapped,
  ) async {
    // This is implemented through the MapWidget.onTapListener property
    print("DEBUG: Tap handling will be set up through MapWidget.onTapListener");
  }

  @override
  Future<void> dispose(MapboxMap mapboxMap) async {
    try {
      print("DEBUG: Disposing cluster resources");
      final style = mapboxMap.style;

      try {
        await style.removeStyleLayer(_clusterCountLayerId);
        await style.removeStyleLayer(_unclusteredPointsLayerId);
        await style.removeStyleLayer(_clustersLayerId);
        await style.removeStyleSource(_sourceId);
      } catch (e) {
        print("WARNING: Error removing layers/source: $e");
      }

      print("DEBUG: Cluster resources disposed");
    } catch (e) {
      print("ERROR: Error disposing cluster resources: $e");
    }
  }
}
