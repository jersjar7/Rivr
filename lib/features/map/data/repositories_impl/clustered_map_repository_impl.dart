// lib/features/map/data/repositories_impl/clustered_map_repository_impl.dart

import 'package:dartz/dartz.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/map_station.dart';
import '../../domain/repositories/clustered_map_repository.dart';
import '../datasources/clustered_map_datasource.dart'; // Updated import
import '../datasources/map_station_local_datasource.dart';

class ClusteredMapRepositoryImpl implements ClusteredMapRepository {
  final ClusteredMapDataSource clusterDataSource;
  final MapStationLocalDataSource stationDataSource;
  final NetworkInfo? networkInfo;

  ClusteredMapRepositoryImpl({
    required this.clusterDataSource,
    required this.stationDataSource,
    this.networkInfo,
  });

  @override
  Future<Either<Failure, void>> initializeClustering(
    MapboxMap mapboxMap,
  ) async {
    try {
      await clusterDataSource.initializeClusterLayers(mapboxMap);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateClusterData(
    MapboxMap mapboxMap,
    List<MapStation> stations,
  ) async {
    try {
      await clusterDataSource.updateClusterData(mapboxMap, stations);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> setupClusterTapHandling(
    MapboxMap mapboxMap,
    Function(MapStation) onStationTapped,
    Function(Point, List<MapStation>) onClusterTapped,
  ) async {
    try {
      await clusterDataSource.setupTapHandling(
        mapboxMap,
        onStationTapped,
        onClusterTapped,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> disposeClustering(MapboxMap mapboxMap) async {
    try {
      await clusterDataSource.dispose(mapboxMap);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<MapStation>>> getStationsInRegion(
    double minLat,
    double maxLat,
    double minLon,
    double maxLon, {
    int limit = 1000,
  }) async {
    try {
      final stations = await stationDataSource.getStationsInRegion(
        minLat,
        maxLat,
        minLon,
        maxLon,
        limit: limit,
      );
      return Right(stations);
    } on DatabaseException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<MapStation>>> getSampleStations({
    int limit = 10,
  }) async {
    try {
      final stations = await stationDataSource.getSampleStations(limit: limit);
      return Right(stations);
    } on DatabaseException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<MapStation>>> getNearestStations(
    double lat,
    double lon, {
    int limit = 5,
    double radius = 50.0,
  }) async {
    try {
      final stations = await stationDataSource.getNearestStations(
        lat,
        lon,
        limit: limit,
        radius: radius,
      );
      return Right(stations);
    } on DatabaseException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
