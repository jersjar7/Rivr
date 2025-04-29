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
    // Create favorites table if needed, but don't await it
    _databaseHelper.createFavoritesTable();
  }

  @override
  Future<List<FavoriteModel>> getFavorites(String userId) async {
    try {
      final db = await _databaseHelper.database;

      // Check if favorites table exists
      final tableExists = await _databaseHelper.tableExists(
        DatabaseHelper.tableFavorites,
      );
      if (!tableExists) {
        // Create the table if it doesn't exist
        await _databaseHelper.createFavoritesTable();
        // Return empty list since it's a new table
        return [];
      }

      final List<Map<String, dynamic>> results = await db.query(
        DatabaseHelper.tableFavorites,
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

      // Check if favorites table exists
      final tableExists = await _databaseHelper.tableExists(
        DatabaseHelper.tableFavorites,
      );
      if (!tableExists) {
        // Create the table if it doesn't exist
        await _databaseHelper.createFavoritesTable();
      }

      // Get the highest position for this user
      final maxPositionResult = await db.rawQuery(
        'SELECT MAX(position) as maxPos FROM ${DatabaseHelper.tableFavorites} WHERE userId = ?',
        [favorite.userId],
      );

      final int maxPosition = maxPositionResult.first['maxPos'] as int? ?? -1;
      final newPosition = maxPosition + 1;

      // Add timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Insert with the next position
      await db.insert(
        DatabaseHelper.tableFavorites,
        {
          ...favorite.toMap(),
          'position': newPosition,
          'lastUpdated': timestamp,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
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

      // Check if favorites table exists
      final tableExists = await _databaseHelper.tableExists(
        DatabaseHelper.tableFavorites,
      );
      if (!tableExists) {
        // If table doesn't exist, there's nothing to remove
        return;
      }

      await db.delete(
        DatabaseHelper.tableFavorites,
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

      // Check if favorites table exists
      final tableExists = await _databaseHelper.tableExists(
        DatabaseHelper.tableFavorites,
      );
      if (!tableExists) {
        // Create the table if it doesn't exist
        await _databaseHelper.createFavoritesTable();
        // Nothing to update if table was just created
        return;
      }

      await db.update(
        DatabaseHelper.tableFavorites,
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

      // Check if favorites table exists
      final tableExists = await _databaseHelper.tableExists(
        DatabaseHelper.tableFavorites,
      );
      if (!tableExists) {
        // Create the table if it doesn't exist
        await _databaseHelper.createFavoritesTable();
        // Not a favorite if table was just created
        return false;
      }

      final List<Map<String, dynamic>> results = await db.query(
        DatabaseHelper.tableFavorites,
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
