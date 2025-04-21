// lib/features/map/domain/usecases/get_sample_stations.dart

import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/map_station.dart';
import '../repositories/map_station_repository.dart';

class GetSampleStations {
  final MapStationRepository repository;

  GetSampleStations(this.repository);

  Future<Either<Failure, List<MapStation>>> call({int limit = 10}) {
    print("DEBUG: GetSampleStations use case called with limit: $limit");
    final result = repository.getSampleStations(limit: limit);
    result.then((value) {
      print(
        "DEBUG: Use case result: ${value.fold((failure) => "Error: ${failure.message}", (stations) => "Success: ${stations.length} stations")}",
      );
    });
    return result;
  }
}
