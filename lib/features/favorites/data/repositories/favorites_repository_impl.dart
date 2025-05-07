// lib/features/favorites/data/repositories/favorites_repository_impl.dart

import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/favorite.dart';
import '../../domain/repositories/favorites_repository.dart';
import '../datasources/favorites_local_datasource.dart';
import '../models/favorite_model.dart';

class FavoritesRepositoryImpl implements FavoritesRepository {
  final FavoritesLocalDataSource localDataSource;

  FavoritesRepositoryImpl({required this.localDataSource});

  @override
  Future<Either<Failure, List<Favorite>>> getFavorites(String userId) async {
    try {
      final favorites = await localDataSource.getFavorites(userId);
      return Right(favorites);
    } on DatabaseException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> addFavorite(Favorite favorite) async {
    try {
      print(
        "DEBUG: Repository adding favorite: ${favorite.stationId}, ${favorite.name}",
      );
      await localDataSource.addFavorite(
        FavoriteModel(
          stationId: favorite.stationId,
          name: favorite.name,
          userId: favorite.userId,
          position: favorite.position,
          color: favorite.color,
          description: favorite.description,
          imgNumber: favorite.imgNumber,
          lastUpdated: favorite.lastUpdated,
          originalApiName: favorite.originalApiName,
          customImagePath: favorite.customImagePath,
        ),
      );
      print("DEBUG: Repository addFavorite succeeded");
      return const Right(null);
    } on DatabaseException catch (e) {
      print("DEBUG: DatabaseException in repository: ${e.message}");
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      print("DEBUG: General exception in repository: $e");
      return Left(CacheFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> removeFavorite(
    String userId,
    String stationId,
  ) async {
    try {
      await localDataSource.removeFavorite(userId, stationId);
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateFavoritePosition(
    String userId,
    String stationId,
    int position,
  ) async {
    try {
      await localDataSource.updateFavoritePosition(userId, stationId, position);
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> isFavorite(
    String userId,
    String stationId,
  ) async {
    try {
      final isFavorite = await localDataSource.isFavorite(userId, stationId);
      return Right(isFavorite);
    } on DatabaseException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }
}
