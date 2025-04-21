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
  static const int _databaseVersion = 3;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Get the path to the database file
    String databasesPath = await getDatabasesPath();
    String path = join(databasesPath, 'stationDatabase.db');

    // Check if the database exists
    bool dbExists = await databaseExists(path);

    if (!dbExists) {
      // Copy the database from the assets
      try {
        await Directory(dirname(path)).create(recursive: true);
        ByteData data = await rootBundle.load(
          'assets/databases/stationDatabase.db',
        );
        List<int> bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        await File(path).writeAsBytes(bytes, flush: true);
        print('Database copied from assets to $path');
      } catch (e) {
        print("Error copying database: $e");
      }
    } else {
      print('Database already exists at $path');
    }

    // Open the database with migration support
    final db = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    print("DEBUG: Database opened at path: $path");
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );
    print(
      "DEBUG: Tables in database: ${tables.map((t) => t['name']).toList()}",
    );

    try {
      final stationCount =
          Sqflite.firstIntValue(
            await db.rawQuery("SELECT COUNT(*) FROM StationDetails"),
          ) ??
          0;
      print("DEBUG: StationDetails table has $stationCount records");
    } catch (e) {
      print("DEBUG: Error checking StationDetails table: $e");
    }

    return db;
  }

  // Create tables if database is newly created
  Future<void> _onCreate(Database db, int version) async {
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

    await db.execute('''
      CREATE TABLE IF NOT EXISTS StationDetails (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stationId INTEGER NOT NULL UNIQUE,
        name TEXT,
        lat REAL,
        lon REAL,
        lastMeasurement REAL,
        timestamp INTEGER
      )
    ''');
  }

  // Handle database migrations
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migration logic based on version differences
    if (oldVersion < 2) {
      // Example migration from version 1 to 2
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

      // Add lastSyncTimestamp to Favorites table if needed
      await db.execute(
        'ALTER TABLE Favorites ADD COLUMN lastSyncTimestamp INTEGER',
      );
    }

    if (oldVersion < 3) {
      // Migration from version 2 to 3
      await db.execute('''
        CREATE TABLE IF NOT EXISTS return_period_cache (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          reach_id TEXT NOT NULL,
          data TEXT NOT NULL,
          timestamp INTEGER NOT NULL,
          UNIQUE(reach_id)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS StationDetails (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          stationId INTEGER NOT NULL UNIQUE,
          name TEXT,
          lat REAL,
          lon REAL,
          lastMeasurement REAL,
          timestamp INTEGER
        )
      ''');
    }
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

  // Check if tables exist
  Future<bool> tableExists(String tableName) async {
    final db = await database;
    var tableInfo = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableName],
    );
    return tableInfo.isNotEmpty;
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
}
