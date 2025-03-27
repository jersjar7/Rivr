// lib/core/di/forecast_di.dart

import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:rivr/common/data/local/database_helper.dart';
import 'package:rivr/core/network/network_info.dart';
import 'package:rivr/features/forecast/data/datasources/forecast_local_datasource.dart';
import 'package:rivr/features/forecast/data/datasources/forecast_remote_datasource.dart';
import 'package:rivr/features/forecast/data/repositories/forecast_repository_impl.dart';
import 'package:rivr/features/forecast/data/repositories/return_period_repository_impl.dart';
import 'package:rivr/features/forecast/domain/repositories/forecast_repository.dart';
import 'package:rivr/features/forecast/domain/repositories/return_period_repository.dart';
import 'package:rivr/features/forecast/domain/usecases/get_forecast.dart';
import 'package:rivr/features/forecast/domain/usecases/get_return_periods.dart';

/// Registers all forecast-related dependencies
void registerForecastDependencies(GetIt sl) {
  // Ensure database tables are created
  sl<DatabaseHelper>().ensureTablesExist();

  // Data sources
  sl.registerLazySingleton<ForecastRemoteDataSource>(
    () => ForecastRemoteDataSourceImpl(client: sl<http.Client>()),
  );
  sl.registerLazySingleton<ForecastLocalDataSource>(
    () => ForecastLocalDataSourceImpl(databaseHelper: sl<DatabaseHelper>()),
  );

  // Repositories
  sl.registerLazySingleton<ForecastRepository>(
    () => ForecastRepositoryImpl(
      remoteDataSource: sl<ForecastRemoteDataSource>(),
      localDataSource: sl<ForecastLocalDataSource>(),
      networkInfo: sl<NetworkInfo>(),
    ),
  );

  sl.registerLazySingleton<ReturnPeriodRepository>(
    () => ReturnPeriodRepositoryImpl(
      remoteDataSource: sl<ForecastRemoteDataSource>(),
      localDataSource: sl<ForecastLocalDataSource>(),
      networkInfo: sl<NetworkInfo>(),
    ),
  );

  // Forecast use cases
  sl.registerLazySingleton(() => GetForecast(sl<ForecastRepository>()));
  sl.registerLazySingleton(
    () => GetShortRangeForecast(sl<ForecastRepository>()),
  );
  sl.registerLazySingleton(
    () => GetMediumRangeForecast(sl<ForecastRepository>()),
  );
  sl.registerLazySingleton(
    () => GetLongRangeForecast(sl<ForecastRepository>()),
  );
  sl.registerLazySingleton(() => GetAllForecasts(sl<ForecastRepository>()));
  sl.registerLazySingleton(() => GetLatestFlow(sl<ForecastRepository>()));

  // Return period use cases
  sl.registerLazySingleton(
    () => GetReturnPeriods(sl<ReturnPeriodRepository>()),
  );
  sl.registerLazySingleton(() => GetFlowCategory(sl<ReturnPeriodRepository>()));
  sl.registerLazySingleton(
    () => CheckFlowExceedsThreshold(sl<ReturnPeriodRepository>()),
  );
}
