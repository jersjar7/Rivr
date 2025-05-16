// lib/common/data/local/database_helper.dart

import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/services.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static bool _tablesCreated = false;
  static bool _initializingDatabase = false;
  static bool _logDatabaseExistence = true;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  static Database? _database;

  // Current database version - increment when schema changes
  static const int _databaseVersion = 1;

  // Table names with consistent casing
  static const String tableGeolocations = 'Geolocations';
  static const String tableFavorites = 'favorites';
  static const String tableForecastCache = 'forecast_cache';
  static const String tableReturnPeriodCache = 'return_period_cache';
  static const String tableCachedForecasts = 'CachedForecasts';
  static const String tableStreamNames = 'stream_names';

  Future<Database> get database async {
    if (_database != null) return _database!;

    // Only log database existence once
    if (_logDatabaseExistence) {
      _logDatabaseExistence = false;
    }

    // Make sure we only initialize the database once
    if (_initializingDatabase) {
      // Wait for initialization to complete if it's already in progress
      while (_initializingDatabase && _database == null) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _database!;
    }

    _initializingDatabase = true;
    _database = await _initDatabase();
    _initializingDatabase = false;
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Get the path to the database file
    String databasesPath = await getDatabasesPath();
    String path = join(databasesPath, 'stations_database.db');

    // Check if the database exists
    bool dbExists = await databaseExists(path);

    if (!dbExists) {
      // Copy the database from the assets
      try {
        print("DEBUG: Database doesn't exist, copying from assets");
        await Directory(dirname(path)).create(recursive: true);
        ByteData data = await rootBundle.load(
          'assets/databases/stationsDatabase.db',
        );
        List<int> bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        await File(path).writeAsBytes(bytes, flush: true);
        print('DEBUG: Database copied from assets to $path');
      } catch (e) {
        print("ERROR: Error copying database: $e");
      }
    } else if (_logDatabaseExistence) {
      print('DEBUG: Database already exists at $path');
    }

    // Open the database
    final db = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onOpen: _onOpen,
    );

    // Only create tables once per app run
    if (!_tablesCreated) {
      await ensureAllTablesExist(db);
      _tablesCreated = true;
    }

    return db;
  }

  // Called when the database is opened
  Future<void> _onOpen(Database db) async {
    if (_logDatabaseExistence) {
      print("DEBUG: Database opened");

      // Check what tables exist
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      print(
        "DEBUG: Tables in database: ${tables.map((t) => t['name']).toList().join(', ')}",
      );
    }
  }

  // Create tables if database is newly created
  Future<void> _onCreate(Database db, int version) async {
    print("DEBUG: Creating database tables");
    // No need to create tables here, as they should exist in the copied database
  }

  // Ensure all required tables exist
  Future<void> ensureAllTablesExist([Database? db]) async {
    final database = db ?? await this.database;
    await createFavoritesTable(database);
    await createForecastCacheTable(database);
    await createReturnPeriodCacheTable(database);
    await createCachedForecastsTable(database);
    await createStreamNamesTable(database);
  }

  // Check if a table exists
  Future<bool> tableExists(String tableName, [Database? providedDb]) async {
    final db = providedDb ?? await database;
    var tableInfo = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableName],
    );
    return tableInfo.isNotEmpty;
  }

  // Check if a column exists in a table
  Future<bool> columnExists(
    String tableName,
    String columnName, [
    Database? providedDb,
  ]) async {
    final db = providedDb ?? await database;

    try {
      print(
        "DEBUG: Checking if column '$columnName' exists in table '$tableName'",
      );
      final tableInfo = await db.rawQuery('PRAGMA table_info($tableName)');
      print(
        "DEBUG: Table '$tableName' columns: ${tableInfo.map((c) => c['name']).toList()}",
      );

      final exists = tableInfo.any((column) => column['name'] == columnName);
      print("DEBUG: Column '$columnName' exists: $exists");

      return exists;
    } catch (e) {
      print("ERROR: Failed to check if column exists: $e");
      print("ERROR: Stack trace: ${StackTrace.current}");
      return false;
    }
  }

  // Add a column to a table if it doesn't exist
  Future<bool> addColumnIfNeeded(
    String tableName,
    String columnName,
    String columnType, [
    Database? providedDb,
  ]) async {
    final db = providedDb ?? await database;

    try {
      // First check if the column already exists
      final hasColumn = await columnExists(tableName, columnName, db);

      if (!hasColumn) {
        print("DEBUG: Adding $columnName column to $tableName");
        await db.execute(
          'ALTER TABLE $tableName ADD COLUMN $columnName $columnType',
        );
        print("DEBUG: $columnName column added successfully");
        return true;
      } else {
        print("DEBUG: $columnName column already exists in $tableName");
        return false;
      }
    } catch (e) {
      print("ERROR: Failed to add column $columnName to $tableName: $e");
      return false;
    }
  }

  // Create stream_names table if it doesn't exist - can be called on demand
  Future<void> createStreamNamesTable([Database? providedDb]) async {
    final db = providedDb ?? await database;

    if (!await tableExists(tableStreamNames, db)) {
      print("DEBUG: Creating stream_names table");
      try {
        await db.execute('''
          CREATE TABLE $tableStreamNames (
            station_id TEXT PRIMARY KEY,
            display_name TEXT NOT NULL,
            original_api_name TEXT,
            last_updated INTEGER NOT NULL
          )
        ''');
        print("DEBUG: Stream names table created successfully");
      } catch (e) {
        print("ERROR: Failed to create stream_names table: $e");
        // Don't throw an exception - just log the error
      }
    } else {
      print("DEBUG: Stream names table already exists");
    }
  }

  // Migrate data from favorites to stream_names table
  Future<void> migrateNamesFromFavorites() async {
    final db = await database;

    // Ensure both tables exist
    await createFavoritesTable();
    await createStreamNamesTable();

    try {
      // Check if there's data to migrate
      final favCount = Sqflite.firstIntValue(
        await db.rawQuery("SELECT COUNT(*) FROM $tableFavorites"),
      );

      if (favCount == null || favCount == 0) {
        print("DEBUG: No favorites to migrate names from");
        return;
      }

      // Get all favorites with names and original API names
      final favorites = await db.query(
        tableFavorites,
        columns: ['stationId', 'name', 'originalApiName', 'lastUpdated'],
      );

      print("DEBUG: Found ${favorites.length} favorites to migrate names from");

      // Insert or update each name in the stream_names table
      int migrated = 0;
      for (final favorite in favorites) {
        final stationId = favorite['stationId']?.toString();
        final name = favorite['name']?.toString();

        if (stationId != null && name != null && name.isNotEmpty) {
          // Check if this station already has a name in stream_names
          final existing = await db.query(
            tableStreamNames,
            where: 'station_id = ?',
            whereArgs: [stationId],
          );

          if (existing.isEmpty) {
            // Insert new record
            await db.insert(tableStreamNames, {
              'station_id': stationId,
              'display_name': name,
              'original_api_name': favorite['originalApiName'],
              'last_updated':
                  favorite['lastUpdated'] ??
                  DateTime.now().millisecondsSinceEpoch,
            });
            migrated++;
          }
        }
      }

      print(
        "DEBUG: Migrated $migrated names from favorites to stream_names table",
      );
    } catch (e) {
      print("ERROR: Failed to migrate names from favorites: $e");
    }
  }

  Future<void> createFavoritesTable([Database? providedDb]) async {
    final db = providedDb ?? await database;

    if (!await tableExists(tableFavorites, db)) {
      print("DEBUG: Creating favorites table with city and state columns");
      try {
        await db.execute('''
      CREATE TABLE $tableFavorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stationId TEXT NOT NULL,
        name TEXT NOT NULL,
        userId TEXT NOT NULL,
        position INTEGER NOT NULL,
        color TEXT,
        description TEXT,
        imgNumber INTEGER,
        lastUpdated INTEGER NOT NULL,
        originalApiName TEXT,
        customImagePath TEXT,
        lat REAL,
        lon REAL,
        elevation REAL,
        city TEXT,
        state TEXT,
        UNIQUE(stationId, userId)
      )
      ''');
        print("DEBUG: Favorites table created successfully with all columns");

        // Verify the table creation
        final columns = await db.rawQuery('PRAGMA table_info($tableFavorites)');
        print(
          "DEBUG: Created table columns: ${columns.map((c) => c['name']).toList()}",
        );
      } catch (e) {
        print("ERROR: Failed to create favorites table: $e");
        print("ERROR: Stack trace: ${StackTrace.current}");
      }
    } else {
      print("DEBUG: Favorites table already exists");

      // Check for and add missing columns if needed
      await ensureFavoritesTableColumns(db);
    }
  }

  // Ensure all required columns exist in the favorites table
  Future<void> ensureFavoritesTableColumns([Database? providedDb]) async {
    final db = providedDb ?? await database;

    // Check and add originalApiName column if needed
    await addColumnIfNeeded(tableFavorites, 'originalApiName', 'TEXT', db);

    // Check and add customImagePath column if needed
    await addColumnIfNeeded(tableFavorites, 'customImagePath', 'TEXT', db);

    // Check and add location columns if needed
    await addColumnIfNeeded(tableFavorites, 'lat', 'REAL', db);
    await addColumnIfNeeded(tableFavorites, 'lon', 'REAL', db);
    await addColumnIfNeeded(tableFavorites, 'elevation', 'REAL', db);

    // Add city and state columns
    await addColumnIfNeeded(tableFavorites, 'city', 'TEXT', db);
    await addColumnIfNeeded(tableFavorites, 'state', 'TEXT', db);
  }

  // Specific method for ensuring customImagePath column exists
  Future<void> ensureCustomImagePathColumn([Database? providedDb]) async {
    final db = providedDb ?? await database;
    await addColumnIfNeeded(tableFavorites, 'customImagePath', 'TEXT', db);
  }

  // Create forecast cache table if it doesn't exist - can be called on demand
  Future<void> createForecastCacheTable([Database? providedDb]) async {
    final db = providedDb ?? await database;

    if (!await tableExists(tableForecastCache, db)) {
      print("DEBUG: Creating forecast cache table");
      try {
        await db.execute('''
          CREATE TABLE $tableForecastCache (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            reach_id TEXT NOT NULL,
            forecast_type TEXT NOT NULL,
            data TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            UNIQUE(reach_id, forecast_type)
          )
        ''');
        print("DEBUG: Forecast cache table created successfully");
      } catch (e) {
        print("ERROR: Failed to create forecast cache table: $e");
        // Don't throw an exception - just log the error
      }
    } else {
      print("DEBUG: Forecast cache table already exists");
    }
  }

  // Create return period cache table if it doesn't exist - can be called on demand
  Future<void> createReturnPeriodCacheTable([Database? providedDb]) async {
    final db = providedDb ?? await database;

    if (!await tableExists(tableReturnPeriodCache, db)) {
      print("DEBUG: Creating return period cache table");
      try {
        await db.execute('''
          CREATE TABLE $tableReturnPeriodCache (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            reach_id TEXT NOT NULL,
            data TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            UNIQUE(reach_id)
          )
        ''');
        print("DEBUG: Return period cache table created successfully");
      } catch (e) {
        print("ERROR: Failed to create return period cache table: $e");
        // Don't throw an exception - just log the error
      }
    } else {
      print("DEBUG: Return period cache table already exists");
    }
  }

  // Create cached forecasts table if it doesn't exist - can be called on demand
  Future<void> createCachedForecastsTable([Database? providedDb]) async {
    final db = providedDb ?? await database;

    if (!await tableExists(tableCachedForecasts, db)) {
      print("DEBUG: Creating cached forecasts table");
      try {
        await db.execute('''
          CREATE TABLE $tableCachedForecasts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            reachId TEXT NOT NULL,
            forecastType TEXT NOT NULL,
            data TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            UNIQUE(reachId, forecastType)
          )
        ''');
        print("DEBUG: Cached forecasts table created successfully");
      } catch (e) {
        print("ERROR: Failed to create cached forecasts table: $e");
        // Don't throw an exception - just log the error
      }
    } else {
      print("DEBUG: Cached forecasts table already exists");
    }
  }

  // Helper method to debug table contents
  Future<void> debugTableContents(String tableName, {int limit = 5}) async {
    final db = await database;

    try {
      final records = await db.query(tableName, limit: limit);
      print("DEBUG: First $limit records in $tableName: $records");
    } catch (e) {
      print("ERROR: Failed to query $tableName: $e");
    }
  }

  // Clear cache older than a certain threshold
  Future<int> clearOldCache(int maxAgeInHours) async {
    final db = await database;
    final threshold =
        DateTime.now().millisecondsSinceEpoch - (maxAgeInHours * 3600 * 1000);

    // Delete stale forecast cache entries
    final deletedCount = await db.delete(
      tableForecastCache,
      where: 'timestamp < ?',
      whereArgs: [threshold],
    );

    // Also clean up return period cache older than 7 days
    final returnPeriodThreshold =
        DateTime.now().millisecondsSinceEpoch - (7 * 24 * 3600 * 1000);
    await db.delete(
      tableReturnPeriodCache,
      where: 'timestamp < ?',
      whereArgs: [returnPeriodThreshold],
    );

    return deletedCount;
  }
}
