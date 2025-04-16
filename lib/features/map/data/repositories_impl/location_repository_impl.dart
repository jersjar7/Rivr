// lib/features/map/data/repositories_impl/location_repository_impl.dart

import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/search_result.dart';
import '../../domain/repositories/location_repository.dart';
import '../datasources/mapbox_remote_datasource.dart';

class LocationRepositoryImpl implements LocationRepository {
  final MapboxRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;
  String? _cachedToken;

  LocationRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, List<SearchResult>>> searchLocation(
    String query,
  ) async {
    if (await networkInfo.isConnected) {
      try {
        final results = await remoteDataSource.searchLocation(query);
        return Right(results);
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message));
      } catch (e) {
        return Left(ServerFailure(message: e.toString()));
      }
    } else {
      return Left(NetworkFailure(message: 'No internet connection available'));
    }
  }

  @override
  Future<Either<Failure, String>> getAccessToken() async {
    // If we have a cached token, return it immediately
    if (_cachedToken != null && _cachedToken!.isNotEmpty) {
      return Right(_cachedToken!);
    }

    try {
      final token = await remoteDataSource.getAccessToken();
      _cachedToken = token; // Cache the token for future use
      return Right(token);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
