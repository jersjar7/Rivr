// lib/features/map/domain/usecases/setup_cluster_tap_handling.dart

import 'package:dartz/dartz.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../../core/error/failures.dart';
import '../entities/map_station.dart';
import '../repositories/clustered_map_repository.dart';

class SetupClusterTapHandling {
  final ClusteredMapRepository repository;

  SetupClusterTapHandling(this.repository);

  Future<Either<Failure, void>> call(
    MapboxMap mapboxMap,
    Function(MapStation) onStationTapped,
    Function(Point, List<MapStation>) onClusterTapped,
  ) {
    return repository.setupClusterTapHandling(
      mapboxMap,
      onStationTapped,
      onClusterTapped,
    );
  }
}
