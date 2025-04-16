// lib/features/map/domain/usecases/dispose_clustering.dart

import 'package:dartz/dartz.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../../core/error/failures.dart';
import '../repositories/clustered_map_repository.dart';

class DisposeClustering {
  final ClusteredMapRepository repository;

  DisposeClustering(this.repository);

  Future<Either<Failure, void>> call(MapboxMap mapboxMap) {
    return repository.disposeClustering(mapboxMap);
  }
}
