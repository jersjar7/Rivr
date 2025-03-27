// lib/features/forecast/data/repositories/forecast_repository_impl.dart

import 'package:dartz/dartz.dart';
import 'package:rivr/core/error/exceptions.dart';
import 'package:rivr/core/error/failures.dart';
import 'package:rivr/core/network/network_info.dart';
import 'package:rivr/features/forecast/data/datasources/forecast_local_datasource.dart';
import 'package:rivr/features/forecast/data/datasources/forecast_remote_datasource.dart';
import 'package:rivr/features/forecast/data/models/forecast_model.dart';
import 'package:rivr/features/forecast/domain/entities/forecast.dart';
import 'package:rivr/features/forecast/domain/entities/forecast_types.dart';
import 'package:rivr/features/forecast/domain/repositories/forecast_repository.dart';

class ForecastRepositoryImpl implements ForecastRepository {
  final ForecastRemoteDataSource remoteDataSource;
  final ForecastLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  ForecastRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, ForecastCollection>> getForecast(
    String reachId,
    ForecastType forecastType, {
    bool forceRefresh = false,
  }) async {
    // Check if we should load from cache
    final shouldLoadFromCache =
        !forceRefresh &&
        !await localDataSource.isCacheStale(reachId, forecastType);

    if (shouldLoadFromCache) {
      try {
        final cachedForecastData = await localDataSource.getCachedForecast(
          reachId,
          forecastType,
        );
        final forecastCollection =
            ForecastModel.fromJson(
              cachedForecastData,
              reachId,
              forecastType,
            ).toEntity();

        return Right(forecastCollection);
      } on CacheException {
        // If cache not found, continue to fetch from remote
      }
    }

    // Try to fetch from remote
    if (await networkInfo.isConnected) {
      try {
        final forecastData = await remoteDataSource.getForecast(
          reachId,
          forecastType,
        );

        // Cache the fresh data
        await localDataSource.cacheForecast(
          reachId,
          forecastType,
          forecastData,
        );

        final forecastCollection =
            ForecastModel.fromJson(
              forecastData,
              reachId,
              forecastType,
            ).toEntity();

        return Right(forecastCollection);
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(message: e.message));
      }
    } else {
      // If no internet, try to return cached data even if stale
      try {
        final cachedForecastData = await localDataSource.getCachedForecast(
          reachId,
          forecastType,
        );
        final forecastCollection =
            ForecastModel.fromJson(
              cachedForecastData,
              reachId,
              forecastType,
            ).toEntity();

        return Right(forecastCollection);
      } on CacheException {
        return Left(
          CacheFailure(
            message: 'No internet connection and no cached data available',
          ),
        );
      }
    }
  }

  @override
  Future<Either<Failure, Map<ForecastType, ForecastCollection>>>
  getAllForecasts(String reachId, {bool forceRefresh = false}) async {
    final results = <ForecastType, ForecastCollection>{};
    final failures = <Failure>[];

    // Fetch all forecast types
    for (final forecastType in ForecastType.values) {
      final result = await getForecast(
        reachId,
        forecastType,
        forceRefresh: forceRefresh,
      );

      result.fold(
        (failure) => failures.add(failure),
        (forecast) => results[forecastType] = forecast,
      );
    }

    // If at least one forecast type was fetched successfully, return the results
    if (results.isNotEmpty) {
      return Right(results);
    } else {
      // Return the first failure if all fetches failed
      return Left(failures.first);
    }
  }

  @override
  Future<Either<Failure, Forecast?>> getLatestFlow(String reachId) async {
    // Try to get the short range forecast first as it's the most recent
    final result = await getForecast(reachId, ForecastType.shortRange);

    return result.fold((failure) => Left(failure), (forecastCollection) {
      if (forecastCollection.forecasts.isEmpty) {
        return const Right(null);
      }

      // Find the forecast with the closest timestamp to now
      final now = DateTime.now();
      Forecast? closestForecast;
      Duration closestDifference = const Duration(
        days: 365,
      ); // Start with a large value

      for (final forecast in forecastCollection.forecasts) {
        final forecastTime = forecast.validDateTime;
        final difference = now.difference(forecastTime).abs();

        if (difference < closestDifference) {
          closestDifference = difference;
          closestForecast = forecast;
        }
      }

      return Right(closestForecast);
    });
  }

  @override
  Future<void> clearStaleCachedForecasts() async {
    await localDataSource.clearStaleCache();
  }
}
