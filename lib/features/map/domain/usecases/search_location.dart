// lib/features/map/domain/usecases/search_location.dart

import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/search_result.dart';
import '../repositories/location_repository.dart';

class SearchLocation {
  final LocationRepository repository;

  SearchLocation(this.repository);

  Future<Either<Failure, List<SearchResult>>> call(String query) {
    return repository.searchLocation(query);
  }
}
