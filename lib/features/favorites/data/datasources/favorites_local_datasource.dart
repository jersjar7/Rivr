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
  Future<void> addFavorite(FavoriteModel favorite) async {
    try {
      final db = await _databaseHelper.database;

      // Check if favorites table exists
      final tableExists = await _databaseHelper.tableExists(
        DatabaseHelper.tableFavorites,
      );
      print("DEBUG: Favorites table exists: $tableExists");

      if (!tableExists) {
        // Create the table if it doesn't exist
        print("DEBUG: Creating favorites table");
        await _databaseHelper.createFavoritesTable();
      }

      // Check if city and state columns exist
      final cityColumnExists = await _databaseHelper.columnExists(
        DatabaseHelper.tableFavorites,
        'city',
      );
      final stateColumnExists = await _databaseHelper.columnExists(
        DatabaseHelper.tableFavorites,
        'state',
      );
      print("DEBUG: In addFavorite - city column exists: $cityColumnExists");
      print("DEBUG: In addFavorite - state column exists: $stateColumnExists");

      // If columns don't exist, try to add them
      if (!cityColumnExists || !stateColumnExists) {
        print("DEBUG: Columns missing! Ensuring city/state columns exist");
        await _databaseHelper.ensureFavoritesTableColumns(db);
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

      // Create the map to insert
      final Map<String, dynamic> insertMap = {
        ...favorite.toMap(),
        'position': newPosition,
        'lastUpdated': timestamp,
      };

      print("DEBUG: About to insert favorite with data:");
      print("DEBUG: stationId: ${insertMap['stationId']}");
      print("DEBUG: name: ${insertMap['name']}");
      print("DEBUG: city: ${insertMap['city']}");
      print("DEBUG: state: ${insertMap['state']}");
      print("DEBUG: lat: ${insertMap['lat']}, lon: ${insertMap['lon']}");

      // Insert with the next position
      await db.insert(
        DatabaseHelper.tableFavorites,
        insertMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      print("DEBUG: Favorite inserted successfully");

      // Verify the insert by querying the record
      final List<Map<String, dynamic>> verifyInsert = await db.query(
        DatabaseHelper.tableFavorites,
        where: 'stationId = ? AND userId = ?',
        whereArgs: [favorite.stationId, favorite.userId],
      );

      if (verifyInsert.isNotEmpty) {
        final insertedData = verifyInsert.first;
        print(
          "DEBUG: Inserted record has city: ${insertedData['city']}, state: ${insertedData['state']}",
        );
      } else {
        print(
          "DEBUG: Could not verify insertion! Record not found after insert",
        );
      }
    } catch (e) {
      print("ERROR: Failed to add favorite: $e");
      throw app_exceptions.DatabaseException(
        message: 'Failed to add favorite: $e',
      );
    }
  }

  @override
  Future<List<FavoriteModel>> getFavorites(String userId) async {
    try {
      final db = await _databaseHelper.database;

      // Check if favorites table exists
      final tableExists = await _databaseHelper.tableExists(
        DatabaseHelper.tableFavorites,
      );
      print("DEBUG: In getFavorites - table exists: $tableExists");

      if (!tableExists) {
        print("DEBUG: Favorites table doesn't exist, creating it");
        // Create the table if it doesn't exist
        await _databaseHelper.createFavoritesTable();
        // Return empty list since it's a new table
        return [];
      }

      // Check if city and state columns exist
      final cityColumnExists = await _databaseHelper.columnExists(
        DatabaseHelper.tableFavorites,
        'city',
      );
      final stateColumnExists = await _databaseHelper.columnExists(
        DatabaseHelper.tableFavorites,
        'state',
      );
      print("DEBUG: In getFavorites - city column exists: $cityColumnExists");
      print("DEBUG: In getFavorites - state column exists: $stateColumnExists");

      // Show all columns in table
      final tableInfo = await db.rawQuery(
        'PRAGMA table_info(${DatabaseHelper.tableFavorites})',
      );
      print(
        "DEBUG: All columns in favorites table: ${tableInfo.map((c) => c['name']).toList()}",
      );

      final List<Map<String, dynamic>> results = await db.query(
        DatabaseHelper.tableFavorites,
        where: 'userId = ?',
        whereArgs: [userId],
        orderBy: 'position ASC',
      );

      print("DEBUG: Retrieved ${results.length} favorites from database");

      if (results.isNotEmpty) {
        print("DEBUG: First result keys: ${results.first.keys.toList()}");
        print(
          "DEBUG: First result city: ${results.first['city']}, state: ${results.first['state']}",
        );
      }

      final favorites =
          results.map((map) {
            final model = FavoriteModel.fromMap(map);
            print(
              "DEBUG: Parsed favorite ${model.stationId} - city: ${model.city}, state: ${model.state}",
            );
            return model;
          }).toList();

      return favorites;
    } catch (e) {
      print("ERROR: Failed to get favorites: $e");
      throw app_exceptions.DatabaseException(
        message: 'Failed to get favorites: $e',
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
