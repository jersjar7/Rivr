// Update to lib/features/map/data/datasources/clustered_map_datasource_impl.dart

import 'dart:convert';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:rivr/core/constants/map_constants.dart';
import 'clustered_map_datasource.dart';
import '../../domain/entities/map_station.dart';

class ClusteredMapDataSourceImpl implements ClusteredMapDataSource {
  // Constants for clustering
  static const String _sourceId = 'stations-source';
  static const String _clustersLayerId = 'clusters';
  static const String _unclusteredCircleLayerId = 'unclustered-points-circle';
  static const String _unclusteredPointsLayerId = 'unclustered-points';
  static const String _clusterCountLayerId = 'cluster-count';
  static const String _selectedPointLayerId = 'selected-point';

  @override
  Future<void> initializeClusterLayers(MapboxMap mapboxMap) async {
    try {
      print("DEBUG: Initializing cluster layers");
      final style = mapboxMap.style;

      // Remove existing layers & source if present
      try {
        await style.removeStyleLayer(_selectedPointLayerId);
        await style.removeStyleLayer(_clusterCountLayerId);
        await style.removeStyleLayer(_unclusteredPointsLayerId);
        await style.removeStyleLayer(_unclusteredCircleLayerId);
        await style.removeStyleLayer(_clustersLayerId);
        await style.removeStyleSource(_sourceId);
        print("DEBUG: Removed existing clustering layers and source");
      } catch (e) {
        print("DEBUG: No existing clustering to remove: $e");
      }

      // Small delay to ensure cleanup
      await Future.delayed(const Duration(milliseconds: 100));

      // Add the GeoJSON source with clustering enabled
      final sourceJson = '''{
        "type": "geojson",
        "data": { "type": "FeatureCollection", "features": [] },
        "cluster": true,
        "clusterMaxZoom": 14,
        "clusterRadius": 50
      }''';
      await style.addStyleSource(_sourceId, sourceJson);
      print("DEBUG: Added GeoJSON source '$_sourceId'");

      // unified paint JSON fragment
      const bubblePaint = '''
        "paint": {
          "circle-color": "${MapConstants.defaultMarkerColor}", 
          "circle-radius": 20
        }
      ''';

      // 1) Cluster circles layer (always blue, radius=25)
      final clusterLayer = '''{
        "id": "$_clustersLayerId",
        "type": "circle",
        "source": "$_sourceId",
        "filter": ["has", "point_count"],
        $bubblePaint
        }''';
      await style.addStyleLayer(clusterLayer, null);
      print("DEBUG: Added cluster layer '$_clustersLayerId'");

      // Unclustered single‐point circles (always visible)
      final circleLayer = '''{
        "id": "$_unclusteredCircleLayerId",
        "type": "circle",
        "source": "$_sourceId",
        "filter": ["!", ["has", "point_count"]],
        "paint": {
          "circle-color": "#11b4da",
          "circle-radius": 6,
          "circle-stroke-width": 1,
          "circle-stroke-color": "#ffffff"
        }
      }''';
      await style.addStyleLayer(circleLayer, null);
      print(
        "DEBUG: Added unclustered-circle layer '$_unclusteredCircleLayerId'",
      );

      // Unclustered symbol layer on top of circles (for normal markers)
      final pointsLayer = '''{
        "id": "$_unclusteredPointsLayerId",
        "type": "symbol",
        "source": "$_sourceId",
        "filter": ["all", 
          ["!", ["has", "point_count"]], 
          ["!=", ["get", "isSelected"], true]
        ],
        "layout": {
          "icon-image": "marker-default",
          "icon-size": 0.05,
          "icon-allow-overlap": true,
          "text-field": ["get", "id"],
          "text-font": ["Open Sans Regular"],
          "text-offset": [0, 1.25],
          "text-anchor": "top",
          "text-size": 12
        },
        "paint": {
          "text-color": "#000000",
          "text-halo-color": "#ffffff",
          "text-halo-width": 1
        }
      }''';
      await style.addStyleLayer(pointsLayer, null);
      print(
        "DEBUG: Added unclustered-symbol layer '$_unclusteredPointsLayerId'",
      );

      // Selected point symbol layer (for selected marker with different icon)
      final selectedPointLayer = '''{
        "id": "$_selectedPointLayerId",
        "type": "symbol",
        "source": "$_sourceId",
        "filter": ["all", 
          ["!", ["has", "point_count"]], 
          ["==", ["get", "isSelected"], true]
        ],
        "layout": {
          "icon-image": "marker-selected",
          "icon-size": 0.08,
          "icon-allow-overlap": true,
          "text-field": ["get", "name"],
          "text-font": ["Open Sans Bold"],
          "text-offset": [0, 1.5],
          "text-anchor": "top",
          "text-size": 14
        },
        "paint": {
          "text-color": "#000000",
          "text-halo-color": "#ffffff",
          "text-halo-width": 2
        }
      }''';
      await style.addStyleLayer(selectedPointLayer, null);
      print("DEBUG: Added selected-point layer '$_selectedPointLayerId'");

      // Cluster count labels
      final countLayer = '''{
        "id": "$_clusterCountLayerId",
        "type": "symbol",
        "source": "$_sourceId",
        "filter": ["has", "point_count"],
        "layout": {
          "text-field": [
            "step",
            ["get", "point_count"],
            ["to-string", ["get", "point_count_abbreviated"]],
            1000, "1000+"
          ],
          "text-font": ["DIN Offc Pro Medium","Arial Unicode MS Bold"],
          "text-size": 12
        },
        "paint": {
          "text-color": "#ffffff"
        }
      }''';
      await style.addStyleLayer(countLayer, null);

      print("DEBUG: Added cluster-count layer '$_clusterCountLayerId'");
      print("DEBUG: Cluster layers initialized successfully");
    } catch (e) {
      print("ERROR: Error initializing cluster layers: $e");
      rethrow;
    }
  }

  @override
  Future<void> updateClusterData(
    MapboxMap mapboxMap,
    List<MapStation> stations, {
    MapStation? selectedStation,
  }) async {
    try {
      print("DEBUG: Updating cluster data with ${stations.length} stations");
      if (stations.isEmpty) {
        print("WARNING: No stations to display");
        return;
      }

      // Convert stations to GeoJSON
      final features =
          stations.map((station) {
            // Check if this is the selected station
            final bool isSelected =
                selectedStation?.stationId == station.stationId;

            return {
              "type": "Feature",
              "properties": {
                "id": station.stationId.toString(),
                "name": station.name ?? "Station ${station.stationId}",
                "type": station.type ?? "unknown",
                "color": station.color ?? "#2389DA",
                "isSelected": isSelected, // Add selected flag
              },
              "geometry": {
                "type": "Point",
                "coordinates": [station.lon, station.lat],
              },
            };
          }).toList();

      final geojsonData = {"type": "FeatureCollection", "features": features};

      final style = mapboxMap.style;

      // Ensure source exists
      final exists = await style.styleSourceExists(_sourceId);
      if (!exists) {
        print("DEBUG: Source '$_sourceId' missing, recreating");
        final sourceJson = jsonEncode({
          "type": "geojson",
          "data": geojsonData,
          "cluster": true,
          "clusterMaxZoom": 14,
          "clusterRadius": 50,
        });
        await style.addStyleSource(_sourceId, sourceJson);
      }

      // Use the GeoJSON update API for reliability and performance
      await style.setStyleSourceProperty(
        _sourceId,
        "data",
        geojsonData, // your Map<String, dynamic> or List of features
      );
      print("DEBUG: GeoJSON source data updated via setGeoJsonSourceData");
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
    // Handled externally via MapWidget.onTapListener
    print("DEBUG: Tap handling is configured in the MapWidget layer");
  }

  @override
  Future<void> dispose(MapboxMap mapboxMap) async {
    try {
      print("DEBUG: Disposing cluster resources");
      final style = mapboxMap.style;
      try {
        await style.removeStyleLayer(_selectedPointLayerId);
        await style.removeStyleLayer(_clusterCountLayerId);
        await style.removeStyleLayer(_unclusteredPointsLayerId);
        await style.removeStyleLayer(_unclusteredCircleLayerId);
        await style.removeStyleLayer(_clustersLayerId);
        await style.removeStyleSource(_sourceId);
        print("DEBUG: Cluster resources removed");
      } catch (e) {
        print("WARNING: Error removing clustering resources: $e");
      }
    } catch (e) {
      print("ERROR: Error disposing cluster resources: $e");
    }
  }
}
