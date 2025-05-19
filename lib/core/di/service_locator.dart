// lib/core/di/service_locator.dart

import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart'
    hide AuthProvider; // Hide Firebase's AuthProvider
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:rivr/core/di/map_di.dart';
import 'package:rivr/core/formatters/flow_value_formatter.dart';
import 'package:rivr/core/network/connection_monitor.dart';
import 'package:rivr/core/services/flow_units_service.dart';
import 'package:rivr/core/services/geocoding_service.dart';
import 'package:rivr/core/services/stream_name_service.dart';
import 'package:rivr/features/map/data/datasources/map_station_local_datasource.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Core
import '../network/network_info.dart';
import '../storage/app_database.dart';
import '../storage/secure_storage.dart';
import '../network/api_client.dart';
import '../cache/storage/cache_database.dart';
import '../cache/services/cache_service.dart';
import '../services/offline_manager_service.dart';
import '../services/mapbox_offline_service.dart';
import '../config/api_config.dart';

// Features
import '../../common/data/local/database_helper.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/datasources/auth_storage_service.dart';
import '../../features/auth/data/datasources/user_profile_service.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/login.dart';
import '../../features/auth/domain/usecases/register.dart';
import '../../features/auth/domain/usecases/get_current_user.dart';
import '../../features/auth/domain/usecases/send_password_reset_email.dart';
import '../../features/auth/domain/usecases/sign_out.dart';
import '../../features/auth/domain/usecases/update_user_profile.dart';
import '../../features/auth/presentation/providers/auth_provider.dart' as app;
import '../../features/auth/data/datasources/biometric_auth_service.dart';

import '../../features/favorites/data/datasources/favorites_local_datasource.dart';
import '../../features/favorites/data/repositories/favorites_repository_impl.dart';
import '../../features/favorites/domain/repositories/favorites_repository.dart';
import '../../features/favorites/domain/usecases/add_favorite.dart';
import '../../features/favorites/domain/usecases/get_favorites.dart';
import '../../features/favorites/domain/usecases/is_favorite.dart';
import '../../features/favorites/domain/usecases/remove_favorite.dart';
import '../../features/favorites/domain/usecases/update_favorite_position.dart';
import '../../features/favorites/presentation/providers/favorites_provider.dart';

import '../../features/forecast/data/datasources/forecast_local_datasource.dart';
import '../../features/forecast/data/datasources/forecast_remote_datasource.dart';
import '../../features/forecast/data/repositories/forecast_repository_impl.dart';
import '../../features/forecast/data/repositories/return_period_repository_impl.dart';
import '../../features/forecast/domain/repositories/forecast_repository.dart';
import '../../features/forecast/domain/repositories/return_period_repository.dart';
import '../../features/forecast/domain/usecases/get_forecast.dart';
import '../../features/forecast/domain/usecases/get_return_periods.dart';
import '../../features/forecast/presentation/providers/forecast_provider.dart';
import '../../features/forecast/presentation/providers/return_period_provider.dart';

final sl = GetIt.instance;

Future<void> setupServiceLocator() async {
  // Firebase
  sl.registerLazySingleton(() => FirebaseAuth.instance);
  sl.registerLazySingleton(() => FirebaseFirestore.instance);

  // External
  sl.registerLazySingleton(() => http.Client());
  sl.registerLazySingleton(() => Connectivity());

  // Core
  sl.registerLazySingleton<NetworkInfo>(
    () => NetworkInfoImpl(connectivity: sl<Connectivity>()),
  );
  sl.registerLazySingleton<AppDatabase>(() => AppDatabaseImpl());
  sl.registerLazySingleton<SecureStorage>(() => SecureStorageImpl());

  // Caching infrastructure
  sl.registerLazySingleton(() => CacheDatabase());
  sl.registerLazySingleton<CacheService>(
    () => CacheService(cacheDatabase: sl<CacheDatabase>()),
  );

  // Add StreamNameService registration here
  sl.registerLazySingleton<StreamNameService>(
    () => StreamNameService(
      appDatabase: sl<AppDatabase>(),
      cacheService: sl<CacheService>(),
    ),
  );

  // API Client with caching
  sl.registerLazySingleton<ApiClient>(
    () => ApiClient(
      innerClient: sl<http.Client>(),
      networkInfo: sl<NetworkInfo>(),
      cacheDatabase: sl<CacheDatabase>(),
    ),
  );

  // Offline manager service
  sl.registerLazySingleton<OfflineManagerService>(
    () => OfflineManagerService(
      cacheService: sl<CacheService>(),
      apiClient: sl<ApiClient>(),
      networkInfo: sl<NetworkInfo>(),
    ),
  );

  // Mapbox offline service
  sl.registerLazySingleton<MapboxOfflineService>(() => MapboxOfflineService());

  // Legacy Database Helper
  sl.registerLazySingleton(() => DatabaseHelper());

  // Validate API configuration during startup
  if (!ApiConfig.validateConfig()) {
    print(
      'WARNING: API configuration validation failed. Some features may not work correctly.',
    );
  }

  // Register feature-specific dependencies
  _registerAuthDependencies();
  _registerFavoritesDependencies();
  _registerForecastDependencies(); // Forecast dependencies
  registerMapDependencies(sl); // Register map dependencies
  _registerProviders(); // Register all providers

  // Register geocoding service
  registerGeocodingService(sl);

  // Biometric Authentication
  sl.registerLazySingleton<BiometricAuthService>(
    () => BiometricAuthService(secureStorage: sl()),
  );

  // Add this to the setupServiceLocator function
  sl.registerLazySingleton<ConnectionMonitor>(
    () => ConnectionMonitor(networkInfo: sl<NetworkInfo>()),
  );

  // Register SharedPreferences instance
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton<SharedPreferences>(() => sharedPreferences);

  // Register FlowUnitsService
  sl.registerLazySingleton<FlowUnitsService>(
    () => FlowUnitsService(preferences: sl<SharedPreferences>()),
  );

  // Register FlowValueFormatter
  sl.registerLazySingleton<FlowValueFormatter>(
    () => FlowValueFormatter(unitsService: sl<FlowUnitsService>()),
  );
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

void _registerFavoritesDependencies() {
  // Data sources
  sl.registerLazySingleton<FavoritesLocalDataSource>(
    () => FavoritesLocalDataSourceImpl(databaseHelper: sl()),
  );

  // Repositories
  sl.registerLazySingleton<FavoritesRepository>(
    () => FavoritesRepositoryImpl(localDataSource: sl()),
  );

  // Use cases
  sl.registerLazySingleton(() => GetFavorites(sl()));
  sl.registerLazySingleton(() => AddFavorite(sl()));
  sl.registerLazySingleton(() => RemoveFavorite(sl()));
  sl.registerLazySingleton(() => UpdateFavoritePosition(sl()));
  sl.registerLazySingleton(() => IsFavorite(sl()));
}

void _registerForecastDependencies() {
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
      flowUnitsService: sl<FlowUnitsService>(),
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
      biometricAuthService: sl(),
    ),
  );

  // Favorites provider
  sl.registerFactory(
    () => FavoritesProvider(
      getFavorites: sl(),
      addFavorite: sl(),
      removeFavorite: sl(),
      updateFavoritePosition: sl(),
      isFavorite: sl(),
      offlineManager: sl<OfflineManagerService>(),
      networkInfo: sl<NetworkInfo>(),
    ),
  );

  // Return period provider
  sl.registerFactory(
    () => ReturnPeriodProvider(
      getReturnPeriods: sl<GetReturnPeriods>(),
      getFlowCategory: sl<GetFlowCategory>(),
      checkFlowExceedsThreshold: sl<CheckFlowExceedsThreshold>(),
      forecastProvider:
          sl<ForecastProvider>(), // This will be replaced by ProxyProvider
      flowUnitsService:
          sl<FlowUnitsService>(), // Add FlowUnitsService dependency
      flowFormatter:
          sl<FlowValueFormatter>(), // Add FlowValueFormatter dependency
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
      mapStationDataSource: sl<MapStationLocalDataSource>(),
      databaseHelper: sl<DatabaseHelper>(),
      flowUnitsService:
          sl<FlowUnitsService>(), // Add FlowUnitsService dependency
      flowFormatter:
          sl<FlowValueFormatter>(), // Add FlowValueFormatter dependency
    ),
  );
}

/// Update service locator with geocoding service registration
void registerGeocodingService(GetIt sl) {
  // Geocoding service
  sl.registerLazySingleton<GeocodingService>(
    () => GeocodingService(
      httpClient: sl<http.Client>(),
      cacheService: sl<CacheService>(),
      networkInfo: sl<NetworkInfo>(),
    ),
  );
}
