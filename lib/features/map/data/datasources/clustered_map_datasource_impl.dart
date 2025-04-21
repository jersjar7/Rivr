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
      print("DEBUG: Added GeoJSON source with ID: $_sourceId");

      // DEBUG: Check if source exists
      try {
        final sourceExists = await style.styleSourceExists(_sourceId);
        print("DEBUG: Source $_sourceId exists check: $sourceExists");
      } catch (e) {
        print("DEBUG: Error checking source existence: $e");
      }

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
      print("DEBUG: Added cluster layer with ID: $_clustersLayerId");

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
      print(
        "DEBUG: Added unclustered points layer with ID: $_unclusteredPointsLayerId",
      );

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
      print("DEBUG: Added cluster count layer with ID: $_clusterCountLayerId");

      // DEBUG: Check if layers exist
      try {
        final clusterLayerExists = await style.styleLayerExists(
          _clustersLayerId,
        );
        final pointsLayerExists = await style.styleLayerExists(
          _unclusteredPointsLayerId,
        );
        final countLayerExists = await style.styleLayerExists(
          _clusterCountLayerId,
        );
        print(
          "DEBUG: Layers exist checks - clusters: $clusterLayerExists, points: $pointsLayerExists, count: $countLayerExists",
        );
      } catch (e) {
        print("DEBUG: Error checking layer existence: $e");
      }

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

      // Debug first feature
      if (features.isNotEmpty) {
        print("DEBUG: First feature: ${features.first}");
      }

      // Update the source data
      final style = mapboxMap.style;
      final sourceProperty = jsonEncode({"data": geojsonData});

      // Check if source exists before updating
      try {
        final sourceExists = await style.styleSourceExists(_sourceId);
        print(
          "DEBUG: Source $_sourceId exists check before update: $sourceExists",
        );

        if (!sourceExists) {
          print("ERROR: Cannot update non-existent source $_sourceId");
          // Try to recreate the source if it doesn't exist
          final sourceJson = '''{
          "type": "geojson",
          "data": ${jsonEncode(geojsonData)},
          "cluster": true,
          "clusterMaxZoom": 14,
          "clusterRadius": 50
        }''';
          await style.addStyleSource(_sourceId, sourceJson);
          print("DEBUG: Recreated missing source $_sourceId");
          return;
        }
      } catch (e) {
        print("DEBUG: Error checking source existence: $e");
      }

      try {
        await style.setStyleSourceProperty(_sourceId, "data", sourceProperty);
        print("DEBUG: Updated source data property successfully");
      } catch (e) {
        print("ERROR: Failed to update source data: $e");
        rethrow;
      }

      // Check layer visibility
      try {
        // Use getStyleLayerProperty correctly - it returns a StylePropertyValue
        final clusterLayerVisible = await style.getStyleLayerProperty(
          _clustersLayerId,
          "visibility",
        );
        final pointsLayerVisible = await style.getStyleLayerProperty(
          _unclusteredPointsLayerId,
          "visibility",
        );
        final countLayerVisible = await style.getStyleLayerProperty(
          _clusterCountLayerId,
          "visibility",
        );

        // Debug layer visibility value details
        print(
          "DEBUG: Layer visibility details - clusters: ${clusterLayerVisible.kind}, points: ${pointsLayerVisible.kind}, count: ${countLayerVisible.kind}",
        );

        // The correct way to check visibility is to use the value property of StylePropertyValue
        final clusterIsVisible = clusterLayerVisible.value == "visible";
        final pointsAreVisible = pointsLayerVisible.value == "visible";
        final countIsVisible = countLayerVisible.value == "visible";

        print(
          "DEBUG: Layer visibility checks - clusters: $clusterIsVisible, points: $pointsAreVisible, count: $countIsVisible",
        );

        // Force visibility properly - needs to be a simple value, not a function
        if (!clusterIsVisible) {
          await style.setStyleLayerProperty(
            _clustersLayerId,
            "visibility",
            '"visible"',
          );
          print("DEBUG: Forced clusters layer visibility to visible");
        }

        if (!pointsAreVisible) {
          await style.setStyleLayerProperty(
            _unclusteredPointsLayerId,
            "visibility",
            '"visible"',
          );
          print("DEBUG: Forced points layer visibility to visible");
        }

        if (!countIsVisible) {
          await style.setStyleLayerProperty(
            _clusterCountLayerId,
            "visibility",
            '"visible"',
          );
          print("DEBUG: Forced count layer visibility to visible");
        }
      } catch (e) {
        print("DEBUG: Error checking/setting layer visibility: $e");
      }

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
