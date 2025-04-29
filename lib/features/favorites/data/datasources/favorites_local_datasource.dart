// lib/features/favorites/data/datasources/favorites_local_datasource.dart

import 'package:rivr/common/data/local/database_helper.dart';
import 'package:rivr/core/error/exceptions.dart' as app_exceptions;
import '../models/favorite_model.dart';
import 'package:sqflite/sqflite.dart';

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
    : _databaseHelper = databaseHelper {
    // Ensure the favorites table exists
    _ensureFavoritesTableExists();
  }

  // Private method to ensure favorites table exists
  Future<void> _ensureFavoritesTableExists() async {
    try {
      final db = await _databaseHelper.database;

      // Check if favorites table exists
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='favorites'",
      );

      if (tables.isEmpty) {
        // Create favorites table if it doesn't exist
        print("Creating favorites table as it doesn't exist");
        await db.execute('''
          CREATE TABLE favorites(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            stationId TEXT NOT NULL,
            name TEXT NOT NULL,
            userId TEXT NOT NULL,
            position INTEGER NOT NULL,
            color TEXT,
            description TEXT,
            imgNumber INTEGER,
            lastUpdated INTEGER NOT NULL,
            UNIQUE(stationId, userId)
          )
        ''');
      }
    } catch (e) {
      print("Error ensuring favorites table exists: $e");
      // Don't throw here to avoid startup errors
    }
  }

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
      throw app_exceptions.DatabaseException(
        message: 'Failed to get favorites: $e',
      );
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
      throw app_exceptions.DatabaseException(
        message: 'Failed to add favorite: $e',
      );
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
      throw app_exceptions.DatabaseException(
        message: 'Failed to remove favorite: $e',
      );
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
      throw app_exceptions.DatabaseException(
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
      throw app_exceptions.DatabaseException(
        message: 'Failed to check favorite status: $e',
      );
    }
  }
}
