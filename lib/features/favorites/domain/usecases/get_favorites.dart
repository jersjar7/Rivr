// lib/features/favorites/domain/usecases/get_favorites.dart

import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/favorite.dart';
import '../repositories/favorites_repository.dart';

class GetFavorites {
  final FavoritesRepository repository;

  GetFavorites(this.repository);

  Future<Either<Failure, List<Favorite>>> call(String userId) {
    return repository.getFavorites(userId);
  }
}
