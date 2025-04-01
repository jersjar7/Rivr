// lib/core/di/service_locator.dart
import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart'
    hide AuthProvider; // Hide Firebase's AuthProvider
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:rivr/common/data/local/database_helper.dart';
import 'package:rivr/core/di/forecast_di.dart';
import 'package:rivr/core/network/network_info.dart';
import 'package:rivr/core/storage/app_database.dart';
import 'package:rivr/core/storage/secure_storage.dart';
import 'package:rivr/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:rivr/features/auth/data/datasources/auth_storage_service.dart';
import 'package:rivr/features/auth/data/datasources/user_profile_service.dart';
import 'package:rivr/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:rivr/features/auth/domain/repositories/auth_repository.dart';
import 'package:rivr/features/auth/domain/usecases/login.dart';
import 'package:rivr/features/auth/domain/usecases/register.dart';
import 'package:rivr/features/auth/domain/usecases/get_current_user.dart';
import 'package:rivr/features/auth/domain/usecases/send_password_reset_email.dart';
import 'package:rivr/features/auth/domain/usecases/sign_out.dart';
import 'package:rivr/features/auth/domain/usecases/update_user_profile.dart';
import 'package:rivr/features/auth/presentation/providers/auth_provider.dart'
    as app; // Use alias for your AuthProvider
import 'package:rivr/features/forecast/domain/usecases/get_forecast.dart';
import 'package:rivr/features/forecast/domain/usecases/get_return_periods.dart';
import 'package:rivr/features/forecast/presentation/providers/forecast_provider.dart';
import 'package:rivr/features/forecast/presentation/providers/return_period_provider.dart';
import 'package:rivr/features/favorites/presentation/providers/favorites_provider.dart';
import 'package:rivr/features/map/presentation/providers/map_provider.dart';
import 'package:rivr/features/map/domain/repositories/map_stations_repository.dart';
import 'package:rivr/features/map/data/repositories_impl/map_stations_repository_impl.dart';

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
  _registerMapDependencies();
  registerForecastDependencies(sl); // Forecast dependencies
  _registerProviders(); // Register all providers
}

void _registerAuthDependencies() {
  // Data sources
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(firebaseAuth: sl(), firestore: sl()),
  );

  // Auth-related services
  sl.registerLazySingleton<AuthStorageService>(
    () => AuthStorageService(secureStorage: sl()),
  );

  sl.registerLazySingleton<UserProfileService>(
    () => UserProfileService(firestore: sl()),
  );

  // Repositories
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl(),
      networkInfo: sl(),
      userProfileService: sl(),
    ),
  );

  // Use cases
  sl.registerLazySingleton(() => Login(sl()));
  sl.registerLazySingleton(() => Register(sl()));
  sl.registerLazySingleton(() => GetCurrentUser(sl()));
  sl.registerLazySingleton(() => SendPasswordResetEmail(sl()));
  sl.registerLazySingleton(() => SignOut(sl()));
  sl.registerLazySingleton(() => UpdateUserProfile(sl()));
}

void _registerMapDependencies() {
  // Repositories
  sl.registerLazySingleton<MapStationsRepository>(
    () => MapStationsRepositoryImpl(databaseHelper: sl()),
  );
}

// Register all providers
void _registerProviders() {
  // Auth provider - use the aliased version
  sl.registerFactory(
    () => app.AuthProvider(
      login: sl(),
      register: sl(),
      getCurrentUser: sl(),
      sendPasswordResetEmail: sl(),
      signOut: sl(),
      authStorage: sl(),
      updateUserProfile: sl(),
    ),
  );

  // Favorites provider
  sl.registerFactory(() => FavoritesProvider());

  // Map provider
  sl.registerFactory(
    () => MapProvider(repository: sl<MapStationsRepository>()),
  );

  // Return period provider
  sl.registerFactory(
    () => ReturnPeriodProvider(
      getReturnPeriods: sl<GetReturnPeriods>(),
      getFlowCategory: sl<GetFlowCategory>(),
      checkFlowExceedsThreshold: sl<CheckFlowExceedsThreshold>(),
      forecastProvider:
          sl<ForecastProvider>(), // This will be replaced by ProxyProvider
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
      getReturnPeriods: sl<GetReturnPeriods>(),
    ),
  );
}

// Placeholder implementation for favorites dependencies
void _registerFavoritesDependencies() {
  // TODO: Implement favorites dependencies when needed
}
