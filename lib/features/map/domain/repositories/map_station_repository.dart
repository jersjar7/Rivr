// lib/features/map/domain/repositories/map_station_repository.dart

import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/map_station.dart';

abstract class MapStationRepository {
  /// Gets stations within a bounding box defined by latitude and longitude
  Future<Either<Failure, List<MapStation>>> getStationsInRegion(
    double minLat,
    double maxLat,
    double minLon,
    double maxLon, {
    int limit = 1000,
  });

  /// Gets a sample of stations (useful for low zoom levels)
  Future<Either<Failure, List<MapStation>>> getSampleStations({int limit = 10});

  /// Gets the total count of stations in the database
  Future<Either<Failure, int>> getStationCount();

  /// Gets the stations nearest to a specific location
  Future<Either<Failure, List<MapStation>>> getNearestStations(
    double lat,
    double lon, {
    int limit = 5,
    double radius = 50.0,
  });
}
