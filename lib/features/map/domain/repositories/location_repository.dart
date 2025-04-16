// lib/features/map/domain/repositories/location_repository.dart

import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/search_result.dart';

abstract class LocationRepository {
  /// Search for locations by query string
  Future<Either<Failure, List<SearchResult>>> searchLocation(String query);

  /// Get the Mapbox access token
  Future<Either<Failure, String>> getAccessToken();
}
