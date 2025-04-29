// lib/features/map/domain/repositories/clustered_map_repository.dart

import 'package:dartz/dartz.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../../core/error/failures.dart';
import '../entities/map_station.dart';

abstract class ClusteredMapRepository {
  /// Initialize clustering on the map
  Future<Either<Failure, void>> initializeClustering(MapboxMap mapboxMap);

  /// Update the stations data in the clusters
  Future<Either<Failure, void>> updateClusterData(
    MapboxMap mapboxMap,
    List<MapStation> stations, {
    MapStation? selectedStation,
  });

  /// Set up tap handling for clusters and individual stations
  Future<Either<Failure, void>> setupClusterTapHandling(
    MapboxMap mapboxMap,
    Function(MapStation) onStationTapped,
    Function(Point, List<MapStation>) onClusterTapped,
  );

  /// Clean up resources when done
  Future<Either<Failure, void>> disposeClustering(MapboxMap mapboxMap);

  /// Get stations within the specified region
  Future<Either<Failure, List<MapStation>>> getStationsInRegion(
    double minLat,
    double maxLat,
    double minLon,
    double maxLon, {
    int limit = 1000,
  });

  /// Get a sample of stations (useful for low zoom levels)
  Future<Either<Failure, List<MapStation>>> getSampleStations({int limit = 10});

  /// Get stations nearest to a location
  Future<Either<Failure, List<MapStation>>> getNearestStations(
    double lat,
    double lon, {
    int limit = 5,
    double radius = 50.0,
  });
}
