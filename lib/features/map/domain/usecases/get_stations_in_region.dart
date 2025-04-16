// lib/features/map/domain/usecases/get_stations_in_region.dart

import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/map_station.dart';
import '../repositories/map_station_repository.dart';

class GetStationsInRegion {
  final MapStationRepository repository;

  GetStationsInRegion(this.repository);

  Future<Either<Failure, List<MapStation>>> call(
    double minLat,
    double maxLat,
    double minLon,
    double maxLon, {
    int limit = 1000,
  }) {
    return repository.getStationsInRegion(
      minLat,
      maxLat,
      minLon,
      maxLon,
      limit: limit,
    );
  }
}
