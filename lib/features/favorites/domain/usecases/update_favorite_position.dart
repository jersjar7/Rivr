// lib/features/favorites/domain/usecases/update_favorite_position.dart

import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/favorites_repository.dart';

class UpdateFavoritePosition {
  final FavoritesRepository repository;

  UpdateFavoritePosition(this.repository);

  Future<Either<Failure, void>> call(
    String userId,
    String stationId,
    int position,
  ) {
    return repository.updateFavoritePosition(userId, stationId, position);
  }
}
