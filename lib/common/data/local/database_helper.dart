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
  static const int _databaseVersion = 2;

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
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
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
        timeFavorited TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS CachedForecasts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        reachId TEXT NOT NULL,
        forecastType TEXT NOT NULL,
        data TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        UNIQUE(reachId, forecastType)
      )
    ''');

    // Add any other tables needed for offline functionality
  }

  // Handle database migrations
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migration logic based on version differences
    if (oldVersion < 2) {
      // Example migration from version 1 to 2
      await db.execute('''
        CREATE TABLE IF NOT EXISTS CachedForecasts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          reachId TEXT NOT NULL,
          forecastType TEXT NOT NULL,
          data TEXT NOT NULL,
          timestamp INTEGER NOT NULL,
          UNIQUE(reachId, forecastType)
        )
      ''');

      // Add lastSyncTimestamp to Favorites table if needed
      await db.execute(
        'ALTER TABLE Favorites ADD COLUMN lastSyncTimestamp INTEGER',
      );
    }

    // Add future migrations here as needed
  }

  // Clear cache older than a certain threshold
  Future<int> clearOldCache(int maxAgeInHours) async {
    final db = await database;
    final threshold =
        DateTime.now().millisecondsSinceEpoch - (maxAgeInHours * 3600 * 1000);

    return await db.delete(
      'CachedForecasts',
      where: 'timestamp < ?',
      whereArgs: [threshold],
    );
  }
}
