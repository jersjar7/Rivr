// lib/features/offline/data/repository/offline_storage_repository.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:rivr/features/map/domain/entities/map_station.dart';

class OfflineStorageRepository {
  static final OfflineStorageRepository _instance =
      OfflineStorageRepository._internal();

  factory OfflineStorageRepository() {
    return _instance;
  }

  OfflineStorageRepository._internal();

  // Database references
  Database? _metadataDb;
  String? _cachePath;

  // Constants
  static const String _stationsTable = 'cached_stations';
  static const String _forecastsTable = 'cached_forecasts';
  static const String _mapTilesTable = 'cached_map_tiles';

  /// Initialize the storage system
  Future<void> initialize() async {
    // Get application documents directory
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    _cachePath = join(appDocDir.path, 'rivr_cache');

    // Create cache directory if it doesn't exist
    final dir = Directory(_cachePath!);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Open/create the metadata database
    _metadataDb = await openDatabase(
      join(_cachePath!, 'offline_metadata.db'),
      version: 1,
      onCreate: (Database db, int version) async {
        // Create tables
        await db.execute('''
          CREATE TABLE $_stationsTable (
            stationId INTEGER PRIMARY KEY,
            name TEXT,
            lat REAL,
            lon REAL,
            elevation REAL,
            type TEXT,
            description TEXT,
            color TEXT,
            lastUpdated INTEGER,
            apiData TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE $_forecastsTable (
            stationId INTEGER PRIMARY KEY,
            forecastData TEXT,
            timestamp INTEGER,
            expiresAt INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE $_mapTilesTable (
            tileKey TEXT PRIMARY KEY,
            filePath TEXT,
            lastAccessed INTEGER,
            expiresAt INTEGER
          )
        ''');
      },
    );

    if (kDebugMode) {
      print('OfflineStorageRepository initialized at $_cachePath');
    }
  }

  /// Cache station data from API or map view
  Future<void> cacheStation(
    MapStation station,
    Map<String, dynamic>? apiData,
  ) async {
    if (_metadataDb == null) await initialize();

    // Only use "Untitled Stream" if name is null or empty
    String stationName =
        (station.name == null || station.name!.isEmpty)
            ? "Untitled Stream"
            : station.name!;

    // Same for API data - only change if null or empty
    if (apiData != null && apiData.containsKey('name')) {
      final apiName = apiData['name'];
      if (apiName == null || apiName.toString().isEmpty) {
        apiData['name'] = "Untitled Stream";
      }
    }

    final apiDataJson = apiData != null ? jsonEncode(apiData) : null;

    await _metadataDb!.insert(_stationsTable, {
      'stationId': station.stationId,
      'name': stationName, // Use our sanitized name
      'lat': station.lat,
      'lon': station.lon,
      'elevation': station.elevation,
      'type': station.type,
      'description': station.description,
      'color': station.color,
      'lastUpdated': DateTime.now().millisecondsSinceEpoch,
      'apiData': apiDataJson,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Get cached station data
  Future<Map<String, dynamic>?> getCachedStation(int stationId) async {
    if (_metadataDb == null) await initialize();

    final List<Map<String, dynamic>> results = await _metadataDb!.query(
      _stationsTable,
      where: 'stationId = ?',
      whereArgs: [stationId],
    );

    if (results.isEmpty) return null;

    final result = results.first;

    // Parse API data if present
    if (result['apiData'] != null) {
      try {
        result['apiData'] = jsonDecode(result['apiData'] as String);
      } catch (e) {
        print('Error decoding API data: $e');
        result['apiData'] = null;
      }
    }

    return result;
  }

  /// Cache forecast data
  Future<void> cacheForecast(
    int stationId,
    Map<String, dynamic> forecastData, {
    int? expiryHours,
  }) async {
    if (_metadataDb == null) await initialize();

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final expiresAt =
        expiryHours != null
            ? timestamp + (expiryHours * 60 * 60 * 1000)
            : timestamp + (24 * 60 * 60 * 1000); // Default 24 hours

    await _metadataDb!.insert(_forecastsTable, {
      'stationId': stationId,
      'forecastData': jsonEncode(forecastData),
      'timestamp': timestamp,
      'expiresAt': expiresAt,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Get cached forecast data
  Future<Map<String, dynamic>?> getCachedForecast(
    int stationId, {
    bool ignoreExpiry = false,
  }) async {
    if (_metadataDb == null) await initialize();

    final List<Map<String, dynamic>> results = await _metadataDb!.query(
      _forecastsTable,
      where: 'stationId = ?',
      whereArgs: [stationId],
    );

    if (results.isEmpty) return null;

    final result = results.first;

    // Check if forecast has expired
    if (!ignoreExpiry) {
      final expiresAt = result['expiresAt'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;

      if (now > expiresAt) {
        // Forecast has expired
        return null;
      }
    }

    // Parse forecast data
    try {
      return jsonDecode(result['forecastData'] as String);
    } catch (e) {
      print('Error decoding forecast data: $e');
      return null;
    }
  }

  /// Cache map tile
  Future<void> cacheMapTile(
    String tileKey,
    List<int> tileData, {
    int? expiryDays,
  }) async {
    if (_metadataDb == null || _cachePath == null) await initialize();

    // Generate a filepath for the tile
    final tilePath = join(_cachePath!, 'map_tiles', '$tileKey.tile');

    // Ensure directory exists
    final dir = Directory(dirname(tilePath));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Save tile data to file
    final file = File(tilePath);
    await file.writeAsBytes(tileData);

    // Save metadata
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final expiresAt =
        expiryDays != null
            ? timestamp + (expiryDays * 24 * 60 * 60 * 1000)
            : timestamp + (30 * 24 * 60 * 60 * 1000); // Default 30 days

    await _metadataDb!.insert(_mapTilesTable, {
      'tileKey': tileKey,
      'filePath': tilePath,
      'lastAccessed': timestamp,
      'expiresAt': expiresAt,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Get cached map tile
  Future<List<int>?> getCachedMapTile(
    String tileKey, {
    bool updateLastAccessed = true,
  }) async {
    if (_metadataDb == null) await initialize();

    final List<Map<String, dynamic>> results = await _metadataDb!.query(
      _mapTilesTable,
      where: 'tileKey = ?',
      whereArgs: [tileKey],
    );

    if (results.isEmpty) return null;

    final result = results.first;

    // Check if tile has expired
    final expiresAt = result['expiresAt'] as int;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (now > expiresAt) {
      // Tile has expired, should be refreshed
      return null;
    }

    // Update last accessed time if requested
    if (updateLastAccessed) {
      await _metadataDb!.update(
        _mapTilesTable,
        {'lastAccessed': now},
        where: 'tileKey = ?',
        whereArgs: [tileKey],
      );
    }

    // Read tile data from file
    final filePath = result['filePath'] as String;
    final file = File(filePath);

    if (await file.exists()) {
      return await file.readAsBytes();
    }

    // File missing but metadata exists - clean up the orphaned record
    await _metadataDb!.delete(
      _mapTilesTable,
      where: 'tileKey = ?',
      whereArgs: [tileKey],
    );

    return null;
  }

  /// Get all cached stations
  Future<List<Map<String, dynamic>>> getAllCachedStations() async {
    if (_metadataDb == null) await initialize();

    final List<Map<String, dynamic>> results = await _metadataDb!.query(
      _stationsTable,
      orderBy: 'lastUpdated DESC',
    );

    // Parse API data for each result
    for (final result in results) {
      if (result['apiData'] != null) {
        try {
          result['apiData'] = jsonDecode(result['apiData'] as String);
        } catch (e) {
          print('Error decoding API data: $e');
          result['apiData'] = null;
        }
      }
    }

    return results;
  }

  /// Clean up expired or least recently used cache entries
  Future<void> performCacheCleanup({int maxCacheSizeMb = 100}) async {
    if (_metadataDb == null || _cachePath == null) await initialize();

    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. Delete expired map tiles
    final expiredTiles = await _metadataDb!.query(
      _mapTilesTable,
      where: 'expiresAt < ?',
      whereArgs: [now],
    );

    for (final tile in expiredTiles) {
      final filePath = tile['filePath'] as String;
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      await _metadataDb!.delete(
        _mapTilesTable,
        where: 'tileKey = ?',
        whereArgs: [tile['tileKey']],
      );
    }

    // 2. Calculate current cache size
    int totalCacheSize = 0;
    final cacheDir = Directory(_cachePath!);
    await for (final entity in cacheDir.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) {
        totalCacheSize += await entity.length();
      }
    }

    // 3. If cache exceeds max size, delete least recently used tiles
    if (totalCacheSize > maxCacheSizeMb * 1024 * 1024) {
      final tilesToDelete = await _metadataDb!.query(
        _mapTilesTable,
        orderBy: 'lastAccessed ASC',
        limit: 100, // Delete batches of 100 tiles at a time
      );

      for (final tile in tilesToDelete) {
        final filePath = tile['filePath'] as String;
        final file = File(filePath);
        if (await file.exists()) {
          totalCacheSize -= await file.length();
          await file.delete();
        }

        await _metadataDb!.delete(
          _mapTilesTable,
          where: 'tileKey = ?',
          whereArgs: [tile['tileKey']],
        );

        // Stop deleting once we're under the limit
        if (totalCacheSize <= maxCacheSizeMb * 1024 * 1024) {
          break;
        }
      }
    }

    // 4. Delete expired forecasts
    await _metadataDb!.delete(
      _forecastsTable,
      where: 'expiresAt < ?',
      whereArgs: [now],
    );
  }

  /// Calculate the current cache size
  Future<int> getCacheSizeInBytes() async {
    if (_cachePath == null) await initialize();

    int totalSize = 0;
    final cacheDir = Directory(_cachePath!);

    if (await cacheDir.exists()) {
      await for (final entity in cacheDir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
    }

    return totalSize;
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    if (_metadataDb == null) await initialize();

    // Get station count
    final stationCount =
        Sqflite.firstIntValue(
          await _metadataDb!.rawQuery('SELECT COUNT(*) FROM $_stationsTable'),
        ) ??
        0;

    // Get forecast count
    final forecastCount =
        Sqflite.firstIntValue(
          await _metadataDb!.rawQuery('SELECT COUNT(*) FROM $_forecastsTable'),
        ) ??
        0;

    // Get tile count
    final tileCount =
        Sqflite.firstIntValue(
          await _metadataDb!.rawQuery('SELECT COUNT(*) FROM $_mapTilesTable'),
        ) ??
        0;

    // Get cache size
    final cacheSize = await getCacheSizeInBytes();

    return {
      'stationCount': stationCount,
      'forecastCount': forecastCount,
      'tileCount': tileCount,
      'cacheSizeBytes': cacheSize,
      'cacheSizeMb': (cacheSize / (1024 * 1024)).round(),
    };
  }

  /// Clear all cached data
  Future<void> clearAllCache() async {
    if (_metadataDb == null || _cachePath == null) await initialize();

    // Delete all database records
    await _metadataDb!.delete(_stationsTable);
    await _metadataDb!.delete(_forecastsTable);
    await _metadataDb!.delete(_mapTilesTable);

    // Delete all cached files
    final cacheDir = Directory(_cachePath!);
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
      await cacheDir.create(recursive: true);
    }
  }

  /// Clear specific cache type
  Future<void> clearCacheByType(String cacheType) async {
    if (_metadataDb == null || _cachePath == null) await initialize();

    switch (cacheType) {
      case 'stations':
        await _metadataDb!.delete(_stationsTable);
        break;
      case 'forecasts':
        await _metadataDb!.delete(_forecastsTable);
        break;
      case 'map_tiles':
        // Delete map tile records
        await _metadataDb!.delete(_mapTilesTable);

        // Delete map tile files
        final mapTilesDir = Directory(join(_cachePath!, 'map_tiles'));
        if (await mapTilesDir.exists()) {
          await mapTilesDir.delete(recursive: true);
          await mapTilesDir.create(recursive: true);
        }
        break;
      default:
        throw ArgumentError('Invalid cache type: $cacheType');
    }
  }

  /// Get station name from cached data or return fallback
  Future<String> getStationName(
    int stationId, {
    String fallback = 'Untitled Stream',
  }) async {
    if (_metadataDb == null) await initialize();

    try {
      // First check if we have cached API data
      final cachedStation = await getCachedStation(stationId);
      if (cachedStation != null) {
        // If we have cached API data with a name, use it
        if (cachedStation['apiData'] != null &&
            cachedStation['apiData'] is Map<String, dynamic> &&
            cachedStation['apiData']['name'] != null) {
          final String name = cachedStation['apiData']['name'];
          if (name.isNotEmpty) {
            // REMOVED: No longer replacing names that start with "Station"
            return name;
          }
        }

        // If we have a name in the cached station itself, use it
        if (cachedStation['name'] != null) {
          final String name = cachedStation['name'];
          if (name.isNotEmpty) {
            // REMOVED: No longer replacing names that start with "Station"
            return name;
          }
        }
      }

      // If we couldn't find a name, return the fallback
      return fallback;
    } catch (e) {
      print('Error getting cached station name: $e');
      return fallback;
    }
  }

  /// Update cached station with name
  Future<void> updateStationName(int stationId, String name) async {
    if (_metadataDb == null) await initialize();

    try {
      final cachedStation = await getCachedStation(stationId);
      if (cachedStation == null) {
        // If we don't have a cached station, we can't update it
        print('No cached station found for ID: $stationId');
        return;
      }

      // REMOVED: No longer replacing names that start with "Station"
      String updatedName = name;

      // Update the name in the cached station
      await _metadataDb!.update(
        _stationsTable,
        {'name': updatedName},
        where: 'stationId = ?',
        whereArgs: [stationId],
      );

      // If there's API data, update the name there too
      if (cachedStation['apiData'] != null) {
        Map<String, dynamic> apiData = cachedStation['apiData'];
        apiData['name'] = updatedName;

        await _metadataDb!.update(
          _stationsTable,
          {'apiData': jsonEncode(apiData)},
          where: 'stationId = ?',
          whereArgs: [stationId],
        );
      }

      print('Updated cached station name for ID: $stationId to: $updatedName');
    } catch (e) {
      print('Error updating cached station name: $e');
    }
  }
}
