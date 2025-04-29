// lib/features/favorites/domain/usecases/add_favorite.dart

import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/favorite.dart';
import '../repositories/favorites_repository.dart';

class AddFavorite {
  final FavoritesRepository repository;

  AddFavorite(this.repository);

  Future<Either<Failure, void>> call(Favorite favorite) {
    return repository.addFavorite(favorite);
  }
}
