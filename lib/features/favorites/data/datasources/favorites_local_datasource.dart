// lib/features/favorites/data/datasources/favorites_local_datasource.dart

import 'package:rivr/common/data/local/database_helper.dart';
import 'package:rivr/core/error/exceptions.dart';
import '../models/favorite_model.dart';

abstract class FavoritesLocalDataSource {
  Future<List<FavoriteModel>> getFavorites(String userId);
  Future<void> addFavorite(FavoriteModel favorite);
  Future<void> removeFavorite(String userId, String stationId);
  Future<void> updateFavoritePosition(
    String userId,
    String stationId,
    int position,
  );
  Future<bool> isFavorite(String userId, String stationId);
}

class FavoritesLocalDataSourceImpl implements FavoritesLocalDataSource {
  final DatabaseHelper _databaseHelper;

  FavoritesLocalDataSourceImpl({required DatabaseHelper databaseHelper})
    : _databaseHelper = databaseHelper;

  @override
  Future<List<FavoriteModel>> getFavorites(String userId) async {
    try {
      final db = await _databaseHelper.database;
      final List<Map<String, dynamic>> results = await db.query(
        'favorites',
        where: 'userId = ?',
        whereArgs: [userId],
        orderBy: 'position ASC',
      );

      return results.map((map) => FavoriteModel.fromMap(map)).toList();
    } catch (e) {
      throw DatabaseException(message: 'Failed to get favorites: $e');
    }
  }

  @override
  Future<void> addFavorite(FavoriteModel favorite) async {
    try {
      final db = await _databaseHelper.database;

      // Get the highest position for this user
      final maxPositionResult = await db.rawQuery(
        'SELECT MAX(position) as maxPos FROM favorites WHERE userId = ?',
        [favorite.userId],
      );

      final int maxPosition = maxPositionResult.first['maxPos'] as int? ?? -1;
      final newPosition = maxPosition + 1;

      // Add timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Insert with the next position
      await db.insert('favorites', {
        ...favorite.toMap(),
        'position': newPosition,
        'lastUpdated': timestamp,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      throw DatabaseException(message: 'Failed to add favorite: $e');
    }
  }

  @override
  Future<void> removeFavorite(String userId, String stationId) async {
    try {
      final db = await _databaseHelper.database;
      await db.delete(
        'favorites',
        where: 'userId = ? AND stationId = ?',
        whereArgs: [userId, stationId],
      );
    } catch (e) {
      throw DatabaseException(message: 'Failed to remove favorite: $e');
    }
  }

  @override
  Future<void> updateFavoritePosition(
    String userId,
    String stationId,
    int position,
  ) async {
    try {
      final db = await _databaseHelper.database;
      await db.update(
        'favorites',
        {
          'position': position,
          'lastUpdated': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'userId = ? AND stationId = ?',
        whereArgs: [userId, stationId],
      );
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to update favorite position: $e',
      );
    }
  }

  @override
  Future<bool> isFavorite(String userId, String stationId) async {
    try {
      final db = await _databaseHelper.database;
      final List<Map<String, dynamic>> results = await db.query(
        'favorites',
        where: 'userId = ? AND stationId = ?',
        whereArgs: [userId, stationId],
        limit: 1,
      );

      return results.isNotEmpty;
    } catch (e) {
      throw DatabaseException(message: 'Failed to check favorite status: $e');
    }
  }
}
