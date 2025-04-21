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

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Get the path to the database file
    String databasesPath = await getDatabasesPath();
    String path = join(
      databasesPath,
      'stationsDatabase.db',
    ); // Corrected filename with 's'

    // Check if the database exists
    bool dbExists = await databaseExists(path);

    if (!dbExists) {
      // Copy the database from the assets
      try {
        print("DEBUG: Database doesn't exist, copying from assets");
        await Directory(dirname(path)).create(recursive: true);
        ByteData data = await rootBundle.load(
          'assets/databases/stationsDatabase.db', // Corrected filename with 's'
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

    // Check specifically for Geolocations table
    final geolocations = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='Geolocations'",
    );

    if (geolocations.isEmpty) {
      print("ERROR: Geolocations table not found!");
    } else {
      // Check table structure
      final columns = await db.rawQuery("PRAGMA table_info(Geolocations)");
      print("DEBUG: Geolocations table columns: $columns");

      // Get count of stations
      try {
        final count = await db.rawQuery(
          "SELECT COUNT(*) as count FROM Geolocations",
        );
        print("DEBUG: Geolocations table has ${count.first['count']} records");
      } catch (e) {
        print("ERROR: Failed to count records in Geolocations: $e");
      }
    }
  }

  // Create tables if database is newly created
  Future<void> _onCreate(Database db, int version) async {
    print("DEBUG: Creating database tables");

    // If the database is copied from assets, these CREATE statements
    // won't run since the database already exists.
    // But they're here as a backup in case the database isn't copied correctly.

    await db.execute('''
      CREATE TABLE IF NOT EXISTS Geolocations (
        stationId INTEGER PRIMARY KEY,
        lat REAL NOT NULL,
        lon REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS Favorites (
        favoriteId INTEGER PRIMARY KEY AUTOINCREMENT,
        stationId INTEGER NOT NULL,
        name TEXT NOT NULL,
        color TEXT,
        description TEXT,
        position INTEGER NOT NULL,
        img_number INTEGER,
        dateFavorited TEXT,
        timeFavorited TEXT,
        lastSyncTimestamp INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS forecast_cache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        reach_id TEXT NOT NULL,
        forecast_type TEXT NOT NULL,
        data TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        UNIQUE(reach_id, forecast_type)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS return_period_cache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        reach_id TEXT NOT NULL,
        data TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        UNIQUE(reach_id)
      )
    ''');
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

  // Ensure all required tables exist
  Future<void> ensureTablesExist() async {
    final db = await database;

    if (!await tableExists('forecast_cache')) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS forecast_cache (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          reach_id TEXT NOT NULL,
          forecast_type TEXT NOT NULL,
          data TEXT NOT NULL,
          timestamp INTEGER NOT NULL,
          UNIQUE(reach_id, forecast_type)
        )
      ''');
    }

    if (!await tableExists('return_period_cache')) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS return_period_cache (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          reach_id TEXT NOT NULL,
          data TEXT NOT NULL,
          timestamp INTEGER NOT NULL,
          UNIQUE(reach_id)
        )
      ''');
    }
  }

  // Check if a table exists
  Future<bool> tableExists(String tableName) async {
    final db = await database;
    var tableInfo = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableName],
    );
    return tableInfo.isNotEmpty;
  }

  // Clear cache older than a certain threshold
  Future<int> clearOldCache(int maxAgeInHours) async {
    final db = await database;
    final threshold =
        DateTime.now().millisecondsSinceEpoch - (maxAgeInHours * 3600 * 1000);

    // Delete stale forecast cache entries
    final deletedCount = await db.delete(
      'forecast_cache',
      where: 'timestamp < ?',
      whereArgs: [threshold],
    );

    // Also clean up return period cache older than 7 days
    final returnPeriodThreshold =
        DateTime.now().millisecondsSinceEpoch - (7 * 24 * 3600 * 1000);
    await db.delete(
      'return_period_cache',
      where: 'timestamp < ?',
      whereArgs: [returnPeriodThreshold],
    );

    return deletedCount;
  }
}
