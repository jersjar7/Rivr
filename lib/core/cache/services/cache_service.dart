// lib/core/cache/services/cache_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../storage/cache_database.dart';

/// High-level service for caching any type of data
class CacheService {
  final CacheDatabase _cacheDatabase;
  String? _cacheDirPath;

  CacheService({CacheDatabase? cacheDatabase})
    : _cacheDatabase = cacheDatabase ?? CacheDatabase();

  /// Initialize the cache directory
  Future<void> _initCacheDir() async {
    if (_cacheDirPath != null) return;

    final appDocDir = await getApplicationDocumentsDirectory();
    _cacheDirPath = join(appDocDir.path, 'rivr_cache', 'files');

    // Create directory if it doesn't exist
    final dir = Directory(_cacheDirPath!);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  /// Get value from cache
  Future<T?> get<T>(String key, {bool updateAccessTime = true}) async {
    final db = await _cacheDatabase.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Query the cache
    final results = await db.query(
      CacheDatabase.tableCache,
      where: 'key = ? AND expires_at > ?',
      whereArgs: [key, now],
    );

    if (results.isEmpty) {
      return null;
    }

    final entry = results.first;
    final jsonValue = entry['value'] as String;

    try {
      // Parse the JSON value
      final value = jsonDecode(jsonValue);

      // Update last accessed time if requested
      if (updateAccessTime) {
        await db.update(
          CacheDatabase.tableCache,
          {'created_at': now},
          where: 'key = ?',
          whereArgs: [key],
        );
      }

      return value as T;
    } catch (e) {
      // If parsing fails, remove the invalid entry
      await db.delete(
        CacheDatabase.tableCache,
        where: 'key = ?',
        whereArgs: [key],
      );
      return null;
    }
  }

  /// Set value in cache
  Future<void> set(
    String key,
    dynamic value, {
    Duration duration = const Duration(days: 1),
    Map<String, dynamic>? metadata,
  }) async {
    final db = await _cacheDatabase.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiresAt = now + duration.inMilliseconds;

    // Convert value to JSON
    final jsonValue = jsonEncode(value);
    final jsonMetadata = metadata != null ? jsonEncode(metadata) : null;

    // Insert or replace the entry
    await db.insert(CacheDatabase.tableCache, {
      'key': key,
      'value': jsonValue,
      'created_at': now,
      'expires_at': expiresAt,
      'metadata': jsonMetadata,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Check if key exists in cache
  Future<bool> exists(String key) async {
    final db = await _cacheDatabase.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    final count = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM ${CacheDatabase.tableCache} WHERE key = ? AND expires_at > ?',
        [key, now],
      ),
    );

    return count != null && count > 0;
  }

  /// Remove key from cache
  Future<void> remove(String key) async {
    final db = await _cacheDatabase.database;

    await db.delete(
      CacheDatabase.tableCache,
      where: 'key = ?',
      whereArgs: [key],
    );
  }

  /// Cache binary file data
  Future<void> cacheFile(
    String key,
    List<int> data, {
    Duration duration = const Duration(days: 7),
    String? mimeType,
  }) async {
    await _initCacheDir();
    final db = await _cacheDatabase.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiresAt = now + duration.inMilliseconds;

    // Create a unique filename
    final filename = '$key-${now.toString()}';
    final filePath = join(_cacheDirPath!, filename);

    // Write the file
    final file = File(filePath);
    await file.writeAsBytes(data);

    // Add entry to database
    await db.insert(CacheDatabase.tableFileCache, {
      'key': key,
      'file_path': filePath,
      'size': data.length,
      'mime_type': mimeType,
      'created_at': now,
      'expires_at': expiresAt,
      'last_accessed': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Get cached file data
  Future<List<int>?> getFile(String key, {bool updateAccessTime = true}) async {
    final db = await _cacheDatabase.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Query for the file entry
    final results = await db.query(
      CacheDatabase.tableFileCache,
      where: 'key = ? AND expires_at > ?',
      whereArgs: [key, now],
    );

    if (results.isEmpty) {
      return null;
    }

    // Get the file path
    final entry = results.first;
    final filePath = entry['file_path'] as String;

    // Check if the file exists
    final file = File(filePath);
    if (!await file.exists()) {
      // File is missing, clean up the entry
      await db.delete(
        CacheDatabase.tableFileCache,
        where: 'key = ?',
        whereArgs: [key],
      );
      return null;
    }

    // Update last accessed time if requested
    if (updateAccessTime) {
      await db.update(
        CacheDatabase.tableFileCache,
        {'last_accessed': now},
        where: 'key = ?',
        whereArgs: [key],
      );
    }

    // Read the file
    return await file.readAsBytes();
  }

  /// Clear all cache
  Future<void> clearAll() async {
    await _cacheDatabase.clearAllCache();
  }

  /// Clean expired entries
  Future<int> cleanExpired() async {
    return await _cacheDatabase.cleanExpiredEntries();
  }

  /// Get total cache size in bytes
  Future<int> getCacheSize() async {
    return await _cacheDatabase.getCacheSize();
  }
}
