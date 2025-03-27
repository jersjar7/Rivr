// lib/core/di/service_locator.dart
import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:rivr/common/data/local/database_helper.dart';
import 'package:rivr/core/di/forecast_di.dart';
import 'package:rivr/core/network/network_info.dart';
import 'package:rivr/core/storage/app_database.dart';
import 'package:rivr/core/storage/secure_storage.dart';
import 'package:rivr/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:rivr/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:rivr/features/auth/domain/repositories/auth_repository.dart';
import 'package:rivr/features/auth/domain/usecases/login.dart';
import 'package:rivr/features/auth/domain/usecases/register.dart';
import 'package:rivr/features/auth/domain/usecases/get_current_user.dart';
import 'package:rivr/features/auth/domain/usecases/send_password_reset_email.dart';
import 'package:rivr/features/auth/domain/usecases/sign_out.dart';
import 'package:rivr/features/auth/presentation/providers/auth_provider.dart'
    as app;
import 'package:rivr/features/forecast/domain/usecases/get_forecast.dart';
import 'package:rivr/features/forecast/domain/usecases/get_return_periods.dart';
import 'package:rivr/features/forecast/presentation/providers/forecast_provider.dart';
import 'package:rivr/features/forecast/presentation/providers/return_period_provider.dart';

final sl = GetIt.instance;

Future<void> setupServiceLocator() async {
  // Firebase
  sl.registerLazySingleton(() => FirebaseAuth.instance);
  sl.registerLazySingleton(() => FirebaseFirestore.instance);

  // External
  sl.registerLazySingleton(() => http.Client());

  // Core
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl());
  sl.registerLazySingleton<AppDatabase>(() => AppDatabaseImpl());
  sl.registerLazySingleton<SecureStorage>(() => SecureStorageImpl());
  sl.registerLazySingleton(() => DatabaseHelper());

  // Register feature-specific dependencies
  _registerAuthDependencies();
  _registerFavoritesDependencies();
  registerForecastDependencies(sl); // Forecast dependencies
  _registerProviders(); // Register all providers
}

void _registerAuthDependencies() {
  // Data sources
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(firebaseAuth: sl(), firestore: sl()),
  );

  // Repositories
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(remoteDataSource: sl(), networkInfo: sl()),
  );

  // Use cases
  sl.registerLazySingleton(() => Login(sl()));
  sl.registerLazySingleton(() => Register(sl()));
  sl.registerLazySingleton(() => GetCurrentUser(sl()));
  sl.registerLazySingleton(() => SendPasswordResetEmail(sl()));
  sl.registerLazySingleton(() => SignOut(sl()));

  // Auth provider is registered in _registerProviders()
}

// Register all providers
void _registerProviders() {
  // Auth provider
  sl.registerFactory(
    () => app.AuthProvider(
      login: sl(),
      register: sl(),
      getCurrentUser: sl(),
      sendPasswordResetEmail: sl(),
      signOut: sl(),
      secureStorage: sl(),
    ),
  );

  // Return period provider
  sl.registerFactory(
    () => ReturnPeriodProvider(
      getReturnPeriods: sl<GetReturnPeriods>(),
      getFlowCategory: sl<GetFlowCategory>(),
      checkFlowExceedsThreshold: sl<CheckFlowExceedsThreshold>(),
    ),
  );

  // Forecast provider
  sl.registerFactory(
    () => ForecastProvider(
      getForecast: sl<GetForecast>(),
      getShortRangeForecast: sl<GetShortRangeForecast>(),
      getMediumRangeForecast: sl<GetMediumRangeForecast>(),
      getLongRangeForecast: sl<GetLongRangeForecast>(),
      getAllForecasts: sl<GetAllForecasts>(),
      getLatestFlow: sl<GetLatestFlow>(),
    ),
  );
}

// Placeholder methods for other features
void _registerFavoritesDependencies() {
  // TODO: Implement favorites dependencies
}
