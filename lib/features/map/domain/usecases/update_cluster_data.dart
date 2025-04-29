// lib/features/map/domain/usecases/update_cluster_data.dart

import 'package:dartz/dartz.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../../core/error/failures.dart';
import '../entities/map_station.dart';
import '../repositories/clustered_map_repository.dart';

class UpdateClusterData {
  final ClusteredMapRepository repository;

  UpdateClusterData(this.repository);

  Future<Either<Failure, void>> call(
    MapboxMap mapboxMap,
    List<MapStation> stations, {
    MapStation? selectedStation,
  }) {
    return repository.updateClusterData(
      mapboxMap,
      stations,
      selectedStation: selectedStation,
    );
  }
}
