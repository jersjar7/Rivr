// lib/features/map/domain/usecases/initialize_clustering.dart

import 'package:dartz/dartz.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../../core/error/failures.dart';
import '../repositories/clustered_map_repository.dart';

class InitializeClustering {
  final ClusteredMapRepository repository;

  InitializeClustering(this.repository);

  Future<Either<Failure, void>> call(MapboxMap mapboxMap) {
    return repository.initializeClustering(mapboxMap);
  }
}
