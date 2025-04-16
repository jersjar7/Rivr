// lib/features/map/domain/usecases/get_nearest_stations.dart

import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/map_station.dart';
import '../repositories/map_station_repository.dart';

class GetNearestStations {
  final MapStationRepository repository;

  GetNearestStations(this.repository);

  Future<Either<Failure, List<MapStation>>> call(
    double lat,
    double lon, {
    int limit = 5,
    double radius = 50.0,
  }) {
    return repository.getNearestStations(
      lat,
      lon,
      limit: limit,
      radius: radius,
    );
  }
}
