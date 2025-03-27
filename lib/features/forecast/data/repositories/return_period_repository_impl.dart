// lib/features/forecast/data/repositories/return_period_repository_impl.dart

import 'package:dartz/dartz.dart';
import 'package:rivr/core/error/exceptions.dart';
import 'package:rivr/core/error/failures.dart';
import 'package:rivr/core/network/network_info.dart';
import 'package:rivr/features/forecast/data/datasources/forecast_local_datasource.dart';
import 'package:rivr/features/forecast/data/datasources/forecast_remote_datasource.dart';
import 'package:rivr/features/forecast/domain/entities/return_period.dart';
import 'package:rivr/features/forecast/domain/repositories/return_period_repository.dart';

class ReturnPeriodRepositoryImpl implements ReturnPeriodRepository {
  final ForecastRemoteDataSource remoteDataSource;
  final ForecastLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  ReturnPeriodRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, ReturnPeriod>> getReturnPeriods(
    String reachId, {
    bool forceRefresh = false,
  }) async {
    // Try to load from cache first, unless forced refresh
    if (!forceRefresh) {
      try {
        final cachedData = await localDataSource.getCachedReturnPeriods(
          reachId,
        );
        if (cachedData != null) {
          final returnPeriod = ReturnPeriodModel.fromJson(cachedData, reachId);

          // Check if cache is still fresh
          if (!returnPeriod.isStale()) {
            return Right(returnPeriod);
          }
        }
      } on CacheException {
        // Continue to fetch from remote if cache fails
      }
    }

    // Fetch from remote if needed
    if (await networkInfo.isConnected) {
      try {
        final returnPeriodData = await remoteDataSource.getReturnPeriods(
          reachId,
        );

        // Cache the data
        await localDataSource.cacheReturnPeriods(reachId, returnPeriodData);

        final returnPeriod = ReturnPeriodModel.fromJson(
          returnPeriodData,
          reachId,
        );
        return Right(returnPeriod);
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(message: e.message));
      }
    } else {
      // If no internet, try to use cached data even if stale
      try {
        final cachedData = await localDataSource.getCachedReturnPeriods(
          reachId,
        );
        if (cachedData != null) {
          final returnPeriod = ReturnPeriodModel.fromJson(cachedData, reachId);
          return Right(returnPeriod);
        } else {
          return Left(
            CacheFailure(
              message:
                  'No internet connection and no cached return period data available',
            ),
          );
        }
      } on CacheException {
        return Left(
          CacheFailure(
            message:
                'No internet connection and no cached return period data available',
          ),
        );
      }
    }
  }

  @override
  Future<Either<Failure, String>> getFlowCategory(
    String reachId,
    double flow,
  ) async {
    final returnPeriodResult = await getReturnPeriods(reachId);

    return returnPeriodResult.fold((failure) => Left(failure), (returnPeriod) {
      final category = returnPeriod.getFlowCategory(flow);
      return Right(category);
    });
  }

  @override
  Future<Either<Failure, bool>> exceedsReturnPeriod(
    String reachId,
    double flow,
    int returnPeriodYear,
  ) async {
    final returnPeriodResult = await getReturnPeriods(reachId);

    return returnPeriodResult.fold((failure) => Left(failure), (returnPeriod) {
      final threshold = returnPeriod.getFlowForYear(returnPeriodYear);
      if (threshold == null) {
        return Left(
          ServerFailure(
            message:
                'Return period data for $returnPeriodYear-year not available',
          ),
        );
      }

      return Right(flow >= threshold);
    });
  }
}
