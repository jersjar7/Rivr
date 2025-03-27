// lib/features/forecast/domain/repositories/forecast_repository.dart

import 'package:dartz/dartz.dart';
import 'package:rivr/core/error/failures.dart';
import 'package:rivr/features/forecast/domain/entities/forecast.dart';
import 'package:rivr/features/forecast/domain/entities/forecast_types.dart';

abstract class ForecastRepository {
  /// Get forecast data for a reach
  Future<Either<Failure, ForecastCollection>> getForecast(
    String reachId,
    ForecastType forecastType, {
    bool forceRefresh = false,
  });

  /// Get all forecast types for a reach
  Future<Either<Failure, Map<ForecastType, ForecastCollection>>>
  getAllForecasts(String reachId, {bool forceRefresh = false});

  /// Get the latest flow for a reach
  Future<Either<Failure, Forecast?>> getLatestFlow(String reachId);

  /// Clear cached forecasts older than their TTL
  Future<void> clearStaleCachedForecasts();
}
