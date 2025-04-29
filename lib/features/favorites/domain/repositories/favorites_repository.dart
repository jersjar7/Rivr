// lib/features/favorites/domain/repositories/favorites_repository.dart

import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/favorite.dart';

abstract class FavoritesRepository {
  Future<Either<Failure, List<Favorite>>> getFavorites(String userId);
  Future<Either<Failure, void>> addFavorite(Favorite favorite);
  Future<Either<Failure, void>> removeFavorite(String userId, String stationId);
  Future<Either<Failure, void>> updateFavoritePosition(
    String userId,
    String stationId,
    int position,
  );
  Future<Either<Failure, bool>> isFavorite(String userId, String stationId);
}
