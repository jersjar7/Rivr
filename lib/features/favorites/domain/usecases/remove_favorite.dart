// lib/features/favorites/domain/usecases/remove_favorite.dart

import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/favorites_repository.dart';

class RemoveFavorite {
  final FavoritesRepository repository;

  RemoveFavorite(this.repository);

  Future<Either<Failure, void>> call(String userId, String stationId) {
    return repository.removeFavorite(userId, stationId);
  }
}
