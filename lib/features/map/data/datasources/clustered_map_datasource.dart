// lib/features/map/data/datasources/clustered_map_datasource.dart

import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../domain/entities/map_station.dart';

/// Interface for cluster map data source operations.
abstract class ClusteredMapDataSource {
  /// Initialize cluster sources and layers on the map
  Future<void> initializeClusterLayers(MapboxMap mapboxMap);

  /// Update station data in the cluster source
  Future<void> updateClusterData(
    MapboxMap mapboxMap,
    List<MapStation> stations, {
    MapStation? selectedStation,
  });

  /// Clean up resources
  Future<void> dispose(MapboxMap mapboxMap);

  /// Setup tap handling for clusters and individual points
  Future<void> setupTapHandling(
    MapboxMap mapboxMap,
    Function(MapStation) onStationTapped,
    Function(Point, List<MapStation>) onClusterTapped,
  );
}
