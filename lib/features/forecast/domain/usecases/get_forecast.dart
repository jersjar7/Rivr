// lib/features/forecast/domain/usecases/get_forecast.dart

import 'package:dartz/dartz.dart';
import 'package:rivr/core/error/failures.dart';
import 'package:rivr/features/forecast/domain/entities/forecast.dart';
import 'package:rivr/features/forecast/domain/entities/forecast_types.dart';
import 'package:rivr/features/forecast/domain/repositories/forecast_repository.dart';

class GetForecast {
  final ForecastRepository repository;

  GetForecast(this.repository);

  Future<Either<Failure, ForecastCollection>> call(
    String reachId,
    ForecastType forecastType, {
    bool forceRefresh = false,
  }) {
    return repository.getForecast(
      reachId,
      forecastType,
      forceRefresh: forceRefresh,
    );
  }
}

class GetShortRangeForecast {
  final ForecastRepository repository;

  GetShortRangeForecast(this.repository);

  Future<Either<Failure, ForecastCollection>> call(
    String reachId, {
    bool forceRefresh = false,
  }) {
    return repository.getForecast(
      reachId,
      ForecastType.shortRange,
      forceRefresh: forceRefresh,
    );
  }
}

class GetMediumRangeForecast {
  final ForecastRepository repository;

  GetMediumRangeForecast(this.repository);

  Future<Either<Failure, ForecastCollection>> call(
    String reachId, {
    bool forceRefresh = false,
  }) {
    return repository.getForecast(
      reachId,
      ForecastType.mediumRange,
      forceRefresh: forceRefresh,
    );
  }
}

class GetLongRangeForecast {
  final ForecastRepository repository;

  GetLongRangeForecast(this.repository);

  Future<Either<Failure, ForecastCollection>> call(
    String reachId, {
    bool forceRefresh = false,
  }) {
    return repository.getForecast(
      reachId,
      ForecastType.longRange,
      forceRefresh: forceRefresh,
    );
  }
}

class GetAllForecasts {
  final ForecastRepository repository;

  GetAllForecasts(this.repository);

  Future<Either<Failure, Map<ForecastType, ForecastCollection>>> call(
    String reachId, {
    bool forceRefresh = false,
  }) {
    return repository.getAllForecasts(reachId, forceRefresh: forceRefresh);
  }
}

class GetLatestFlow {
  final ForecastRepository repository;

  GetLatestFlow(this.repository);

  Future<Either<Failure, Forecast?>> call(String reachId) {
    return repository.getLatestFlow(reachId);
  }
}
