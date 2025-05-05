// lib/core/cache/storage/cache_database.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Central database for all caching operations
class CacheDatabase {
  static final CacheDatabase _instance = CacheDatabase._internal();

  // Database references
  Database? _database;
  static const String _databaseName = 'rivr_cache.db';
  static const int _databaseVersion = 1;

  // Table names
  static const String tableCache = 'cache_entries';
  static const String tableNetworkCache = 'network_cache';
  static const String tableFileCache = 'file_cache';

  // Factory constructor
  factory CacheDatabase() {
    return _instance;
  }

  // Private constructor
  CacheDatabase._internal();

  // Database getter
  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  // Initialize database
  Future<Database> _initDatabase() async {
    // Get application documents directory
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String dbPath = join(appDocDir.path, _databaseName);

    // Open the database
    return await openDatabase(
      dbPath,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // Create database tables
  Future<void> _onCreate(Database db, int version) async {
    // General cache table for key-value pairs
    await db.execute('''
      CREATE TABLE $tableCache (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL,
        metadata TEXT
      )
    ''');

    // Network cache table for HTTP responses
    await db.execute('''
      CREATE TABLE $tableNetworkCache (
        url TEXT PRIMARY KEY,
        method TEXT NOT NULL,
        headers TEXT,
        body TEXT,
        status_code INTEGER,
        response_body TEXT,
        response_headers TEXT,
        created_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL
      )
    ''');

    // File cache table for map tiles, images, etc.
    await db.execute('''
      CREATE TABLE $tableFileCache (
        key TEXT PRIMARY KEY,
        file_path TEXT NOT NULL,
        size INTEGER NOT NULL,
        mime_type TEXT,
        created_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL,
        last_accessed INTEGER NOT NULL
      )
    ''');
  }

  // Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Logic for migrating between database versions
    if (oldVersion < 2) {
      // Migration for future version 2
    }
  }

  // Clean up expired cache entries
  Future<int> cleanExpiredEntries() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    int deletedCount = 0;

    // Delete expired entries from each table
    deletedCount += await db.delete(
      tableCache,
      where: 'expires_at < ?',
      whereArgs: [now],
    );

    deletedCount += await db.delete(
      tableNetworkCache,
      where: 'expires_at < ?',
      whereArgs: [now],
    );

    // For file cache, we need to delete the actual files too
    final expiredFiles = await db.query(
      tableFileCache,
      columns: ['file_path'],
      where: 'expires_at < ?',
      whereArgs: [now],
    );

    // Delete the physical files
    for (final row in expiredFiles) {
      final filePath = row['file_path'] as String;
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    // Then delete the database entries
    deletedCount += await db.delete(
      tableFileCache,
      where: 'expires_at < ?',
      whereArgs: [now],
    );

    return deletedCount;
  }

  // Clear all cache
  Future<void> clearAllCache() async {
    final db = await database;

    // Delete file entries first
    final fileEntries = await db.query(tableFileCache, columns: ['file_path']);

    // Delete the physical files
    for (final row in fileEntries) {
      final filePath = row['file_path'] as String;
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    // Then delete all database entries
    await db.delete(tableCache);
    await db.delete(tableNetworkCache);
    await db.delete(tableFileCache);
  }

  // Get cache size
  Future<int> getCacheSize() async {
    final db = await database;
    int totalSize = 0;

    // Get size of file cache
    final result = await db.rawQuery(
      'SELECT SUM(size) as total_size FROM $tableFileCache',
    );

    if (result.isNotEmpty && result.first['total_size'] != null) {
      totalSize = result.first['total_size'] as int;
    }

    // Add rough size of database itself
    final dbFile = File(db.path);
    if (await dbFile.exists()) {
      totalSize += await dbFile.length();
    }

    return totalSize;
  }
}
