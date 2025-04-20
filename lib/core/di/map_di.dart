// lib/core/di/map_di.dart

import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;

import '../../features/map/data/datasources/clustered_map_datasource_impl.dart';
import '../../features/map/data/datasources/map_station_local_datasource.dart';
import '../../features/map/data/datasources/mapbox_remote_datasource.dart';
import '../../features/map/data/repositories_impl/clustered_map_repository_impl.dart';
import '../../features/map/data/repositories_impl/location_repository_impl.dart';
import '../../features/map/data/repositories_impl/map_stations_repository_impl.dart';
import '../../features/map/domain/repositories/clustered_map_repository.dart';
import '../../features/map/domain/repositories/location_repository.dart';
import '../../features/map/domain/repositories/map_station_repository.dart';
import '../../features/map/domain/usecases/dispose_clustering.dart';
import '../../features/map/domain/usecases/get_nearest_stations.dart';
import '../../features/map/domain/usecases/get_sample_stations.dart';
import '../../features/map/domain/usecases/get_stations_in_region.dart';
import '../../features/map/domain/usecases/initialize_clustering.dart';
import '../../features/map/domain/usecases/search_location.dart';
import '../../features/map/domain/usecases/setup_cluster_tap_handling.dart';
import '../../features/map/domain/usecases/update_cluster_data.dart';
import '../../features/map/presentation/providers/enhanced_clustered_map_provider.dart';
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

  sl.registerLazySingleton<ClusteredMapDataSource>(
    () => ClusteredMapDataSourceImpl(),
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

  sl.registerLazySingleton<ClusteredMapRepository>(
    () => ClusteredMapRepositoryImpl(
      clusterDataSource: sl<ClusteredMapDataSource>(),
      stationDataSource: sl<MapStationLocalDataSource>(),
      networkInfo: sl<NetworkInfo>(),
    ),
  );

  // Use cases - Original map
  sl.registerLazySingleton(
    () => GetStationsInRegion(sl<MapStationRepository>()),
  );
  sl.registerLazySingleton(() => GetSampleStations(sl<MapStationRepository>()));
  sl.registerLazySingleton(
    () => GetNearestStations(sl<MapStationRepository>()),
  );
  sl.registerLazySingleton(() => SearchLocation(sl<LocationRepository>()));

  // Use cases - Clustered map
  sl.registerLazySingleton(
    () => InitializeClustering(sl<ClusteredMapRepository>()),
  );
  sl.registerLazySingleton(
    () => UpdateClusterData(sl<ClusteredMapRepository>()),
  );
  sl.registerLazySingleton(
    () => SetupClusterTapHandling(sl<ClusteredMapRepository>()),
  );
  sl.registerLazySingleton(
    () => DisposeClustering(sl<ClusteredMapRepository>()),
  );

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

  // Clustered map provider - Changed from EnhancedClusteredMapProvider to ClusteredMapProvider
  sl.registerFactory(
    () => ClusteredMapProvider(
      initializeClustering: sl<InitializeClustering>(),
      updateClusterData: sl<UpdateClusterData>(),
      setupClusterTapHandling: sl<SetupClusterTapHandling>(),
      disposeClustering: sl<DisposeClustering>(),
    ),
  );
}
