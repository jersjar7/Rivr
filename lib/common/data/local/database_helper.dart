// lib/common/data/local/database_helper.dart

import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/services.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  static Database? _database;

  // Current database version - increment when schema changes
  static const int _databaseVersion = 1;

  // Table names with consistent casing
  static const String tableGeolocations = 'geolocations';
  static const String tableFavorites = 'favorites';
  static const String tableForecastCache = 'forecast_cache';
  static const String tableReturnPeriodCache = 'return_period_cache';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
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
    } else {
      print('DEBUG: Database already exists at $path');
    }

    // Open the database
    final db = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onOpen: _onOpen,
    );

    return db;
  }

  // Called when the database is opened
  Future<void> _onOpen(Database db) async {
    print("DEBUG: Database opened");

    // Check what tables exist
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );
    print(
      "DEBUG: Tables in database: ${tables.map((t) => t['name']).toList().join(', ')}",
    );

    // Ensure all required tables exist
    await ensureAllTablesExist(db);
  }

  // Create tables if database is newly created
  Future<void> _onCreate(Database db, int version) async {
    print("DEBUG: Creating database tables");

    // Create all required tables
    await ensureAllTablesExist(db);
  }

  // Central method to ensure all tables exist
  Future<void> ensureAllTablesExist([Database? providedDb]) async {
    final db = providedDb ?? await database;

    // Ensure each table exists
    await ensureGeolocationsTableExists(db);
    await ensureFavoritesTableExists(db);
    await ensureForecastCacheTableExists(db);
    await ensureReturnPeriodCacheTableExists(db);
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

  // Methods for each table
  Future<void> ensureGeolocationsTableExists([Database? providedDb]) async {
    final db = providedDb ?? await database;

    if (!await tableExists(tableGeolocations, db)) {
      print("DEBUG: Creating geolocations table");
      await db.execute('''
        CREATE TABLE $tableGeolocations (
          stationId INTEGER PRIMARY KEY,
          lat REAL NOT NULL,
          lon REAL NOT NULL
        )
      ''');
    }
  }

  Future<void> ensureFavoritesTableExists([Database? providedDb]) async {
    final db = providedDb ?? await database;

    if (!await tableExists(tableFavorites, db)) {
      print("DEBUG: Creating favorites table");
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
          UNIQUE(stationId, userId)
        )
      ''');
    }
  }

  Future<void> ensureForecastCacheTableExists([Database? providedDb]) async {
    final db = providedDb ?? await database;

    if (!await tableExists(tableForecastCache, db)) {
      print("DEBUG: Creating forecast cache table");
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
    }
  }

  Future<void> ensureReturnPeriodCacheTableExists([
    Database? providedDb,
  ]) async {
    final db = providedDb ?? await database;

    if (!await tableExists(tableReturnPeriodCache, db)) {
      print("DEBUG: Creating return period cache table");
      await db.execute('''
        CREATE TABLE $tableReturnPeriodCache (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          reach_id TEXT NOT NULL,
          data TEXT NOT NULL,
          timestamp INTEGER NOT NULL,
          UNIQUE(reach_id)
        )
      ''');
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
