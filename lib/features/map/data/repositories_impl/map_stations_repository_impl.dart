// lib/features/map/data/repositories_impl/map_stations_repository_impl.dart

import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/map_station.dart';
import '../../domain/repositories/map_station_repository.dart';
import '../datasources/map_station_local_datasource.dart';

class MapStationsRepositoryImpl implements MapStationRepository {
  final MapStationLocalDataSource localDataSource;
  final NetworkInfo?
  networkInfo; // Optional since we're primarily using local data

  MapStationsRepositoryImpl({required this.localDataSource, this.networkInfo});

  @override
  Future<Either<Failure, List<MapStation>>> getStationsInRegion(
    double minLat,
    double maxLat,
    double minLon,
    double maxLon, {
    int limit = 1000,
  }) async {
    try {
      final stations = await localDataSource.getStationsInRegion(
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
      final stations = await localDataSource.getSampleStations(limit: limit);
      return Right(stations);
    } on DatabaseException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, int>> getStationCount() async {
    try {
      final count = await localDataSource.getStationCount();
      return Right(count);
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
      final stations = await localDataSource.getNearestStations(
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
