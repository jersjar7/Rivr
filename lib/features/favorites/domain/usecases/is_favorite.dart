// lib/features/favorites/domain/usecases/is_favorite.dart

import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/favorites_repository.dart';

class IsFavorite {
  final FavoritesRepository repository;

  IsFavorite(this.repository);

  Future<Either<Failure, bool>> call(String userId, String stationId) {
    return repository.isFavorite(userId, stationId);
  }
}
