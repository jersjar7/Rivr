// lib/features/forecast/data/repositories/return_period_repository_impl.dart

import 'package:dartz/dartz.dart';
import 'package:rivr/core/error/exceptions.dart';
import 'package:rivr/core/error/failures.dart';
import 'package:rivr/core/models/flow_unit.dart';
import 'package:rivr/core/network/network_info.dart';
import 'package:rivr/core/services/flow_units_service.dart';
import 'package:rivr/features/forecast/data/datasources/forecast_local_datasource.dart';
import 'package:rivr/features/forecast/data/datasources/forecast_remote_datasource.dart';
import 'package:rivr/features/forecast/domain/entities/return_period.dart';
import 'package:rivr/features/forecast/domain/repositories/return_period_repository.dart';

class ReturnPeriodRepositoryImpl implements ReturnPeriodRepository {
  final ForecastRemoteDataSource remoteDataSource;
  final ForecastLocalDataSource localDataSource;
  final NetworkInfo networkInfo;
  final FlowUnitsService flowUnitsService; // Non-nullable FlowUnitsService

  ReturnPeriodRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
    required this.flowUnitsService, // Make required to ensure it's never null
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
          // Get the current preferred unit
          final preferredUnit = flowUnitsService.preferredUnit;

          // Create ReturnPeriod model, specifying source and target units
          final returnPeriod = ReturnPeriodModel.fromJson(
            cachedData,
            reachId,
            sourceUnit: FlowUnit.cms, // API values are stored in CMS
            targetUnit: preferredUnit, // Convert to user preferred unit
            flowUnitsService: flowUnitsService, // Pass service for conversion
          );

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

        // Get the current preferred unit
        final preferredUnit = flowUnitsService.preferredUnit;

        // Create ReturnPeriod model, specifying source and target units
        final returnPeriod = ReturnPeriodModel.fromJson(
          returnPeriodData,
          reachId,
          sourceUnit: FlowUnit.cms, // API values are in CMS
          targetUnit: preferredUnit, // Convert to user preferred unit
          flowUnitsService: flowUnitsService, // Pass service for conversion
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
          // Get the current preferred unit
          final preferredUnit = flowUnitsService.preferredUnit;

          // Create ReturnPeriod model with explicit unit conversion
          final returnPeriod = ReturnPeriodModel.fromJson(
            cachedData,
            reachId,
            sourceUnit: FlowUnit.cms, // Cached values are in CMS
            targetUnit: preferredUnit, // Convert to preferred unit
            flowUnitsService: flowUnitsService, // Service for conversion
          );

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
      // Pass the current preferred unit for proper comparison
      final fromUnit = flowUnitsService.preferredUnit;

      final category = returnPeriod.getFlowCategory(flow, fromUnit: fromUnit);
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
      // Get the current preferred unit for conversion
      final preferredUnit = flowUnitsService.preferredUnit;

      // Get threshold with explicit unit conversion
      final threshold = returnPeriod.getFlowForYear(
        returnPeriodYear,
        toUnit: preferredUnit,
      );

      if (threshold == null) {
        return Left(
          ServerFailure(
            message:
                'Return period data for $returnPeriodYear-year not available',
          ),
        );
      }

      // Compare flow with threshold in the same unit
      return Right(flow >= threshold);
    });
  }
}
