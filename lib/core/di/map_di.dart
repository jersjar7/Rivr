// lib/core/di/map_di.dart

import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;

import '../../features/map/data/datasources/map_station_local_datasource.dart';
import '../../features/map/data/datasources/mapbox_remote_datasource.dart';
import '../../features/map/data/repositories_impl/location_repository_impl.dart';
import '../../features/map/data/repositories_impl/map_stations_repository_impl.dart';
import '../../features/map/domain/repositories/location_repository.dart';
import '../../features/map/domain/repositories/map_station_repository.dart';
import '../../features/map/domain/usecases/get_nearest_stations.dart';
import '../../features/map/domain/usecases/get_sample_stations.dart';
import '../../features/map/domain/usecases/get_stations_in_region.dart';
import '../../features/map/domain/usecases/search_location.dart';
import '../../features/map/presentation/providers/map_provider.dart';
import '../../features/map/presentation/providers/station_provider.dart';
import '../network/network_info.dart';

/// Registers all map-related dependencies
void registerMapDependencies(GetIt sl) {
  // Data sources
  sl.registerLazySingleton<MapStationLocalDataSource>(
    () => MapStationLocalDataSourceImpl(databaseHelper: sl()),
  );

  sl.registerLazySingleton<MapboxRemoteDataSource>(
    () => MapboxRemoteDataSourceImpl(client: sl<http.Client>()),
  );

  // Repositories
  sl.registerLazySingleton<MapStationRepository>(
    () => MapStationsRepositoryImpl(
      localDataSource: sl<MapStationLocalDataSource>(),
      networkInfo: sl<NetworkInfo>(),
    ),
  );

  sl.registerLazySingleton<LocationRepository>(
    () => LocationRepositoryImpl(
      remoteDataSource: sl<MapboxRemoteDataSource>(),
      networkInfo: sl<NetworkInfo>(),
    ),
  );

  // Use cases
  sl.registerLazySingleton(
    () => GetStationsInRegion(sl<MapStationRepository>()),
  );
  sl.registerLazySingleton(() => GetSampleStations(sl<MapStationRepository>()));
  sl.registerLazySingleton(
    () => GetNearestStations(sl<MapStationRepository>()),
  );
  sl.registerLazySingleton(() => SearchLocation(sl<LocationRepository>()));

  // Providers
  sl.registerFactory(
    () => MapProvider(searchLocationUseCase: sl<SearchLocation>()),
  );

  sl.registerFactory(
    () => StationProvider(
      getStationsInRegion: sl<GetStationsInRegion>(),
      getSampleStations: sl<GetSampleStations>(),
      getNearestStations: sl<GetNearestStations>(),
    ),
  );
}
