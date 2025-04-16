// lib/features/map/domain/usecases/get_clustered_stations.dart

import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/map_station.dart';
import '../repositories/clustered_map_repository.dart';

class GetClusteredStationsInRegion {
  final ClusteredMapRepository repository;

  GetClusteredStationsInRegion(this.repository);

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
