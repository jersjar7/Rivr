// lib/core/repositories/offline_storage_repository.dart

import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../../features/map/domain/entities/map_station.dart';
import '../services/stream_name_service.dart';
import '../di/service_locator.dart';

/// Repository for managing offline storage
class OfflineStorageRepository {
  static const String _dbName = 'offline_storage.db';
  static const int _dbVersion = 1;

  // Tables
  static const String _stationsTable = 'stations';
  static const String _forecastsTable = 'forecasts';
  static const String _mapRegionsTable = 'map_regions';

  Database? _db;
  String? _cacheDirPath;
  String? _dbPath;

  // Reference to StreamNameService
  final StreamNameService? _streamNameService;

  /// Constructor with optional StreamNameService injection
  OfflineStorageRepository({StreamNameService? streamNameService})
    : _streamNameService = streamNameService ?? sl<StreamNameService>();

  /// Initialize the repository
  Future<void> initialize() async {
    await _initDatabase();
    await _initCacheDir();
  }

  /// Initialize database
  Future<void> _initDatabase() async {
    if (_db != null) return;

    final documentsDir = await getApplicationDocumentsDirectory();
    _dbPath = join(documentsDir.path, _dbName);

    _db = await openDatabase(
      _dbPath!,
      version: _dbVersion,
      onCreate: _createDb,
      onUpgrade: _upgradeDb,
    );
  }

  /// Initialize cache directory
  Future<void> _initCacheDir() async {
    if (_cacheDirPath != null) return;

    final appDocDir = await getApplicationDocumentsDirectory();
    _cacheDirPath = join(appDocDir.path, 'offline_cache');

    // Create directory if it doesn't exist
    final dir = Directory(_cacheDirPath!);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  /// Create database tables
  Future<void> _createDb(Database db, int version) async {
    // Stations table
    await db.execute('''
      CREATE TABLE $_stationsTable (
        station_id TEXT PRIMARY KEY,
        name TEXT,
        latitude REAL,
        longitude REAL,
        elevation REAL,
        color TEXT,
        api_data TEXT,
        cached_at INTEGER NOT NULL
      )
    ''');

    // Forecasts table
    await db.execute('''
      CREATE TABLE $_forecastsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        station_id TEXT NOT NULL,
        forecast_data TEXT NOT NULL,
        cached_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL
      )
    ''');

    // Map regions table
    await db.execute('''
      CREATE TABLE $_mapRegionsTable (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        min_lat REAL NOT NULL,
        max_lat REAL NOT NULL,
        min_lon REAL NOT NULL,
        max_lon REAL NOT NULL,
        min_zoom REAL NOT NULL,
        max_zoom REAL NOT NULL,
        style_url TEXT NOT NULL,
        downloaded_at INTEGER NOT NULL,
        tile_count INTEGER,
        size_bytes INTEGER
      )
    ''');
  }

  /// Handle database upgrades
  Future<void> _upgradeDb(Database db, int oldVersion, int newVersion) async {
    // Implement version migrations if needed
    if (oldVersion < 2) {
      // Example upgrade logic for version 2
    }
  }

  /// Cache a station with its API data
  /// Now also updates the StreamNameService with name data
  Future<void> cacheStation(
    MapStation station,
    Map<String, dynamic>? apiData,
  ) async {
    if (_db == null) await _initDatabase();

    // First, cache in the database for backward compatibility
    await _db!.insert(_stationsTable, {
      'station_id': station.stationId.toString(),
      'name': station.name,
      'latitude': station.lat,
      'longitude': station.lon,
      'elevation': station.elevation,
      'color': station.color,
      'api_data': apiData != null ? jsonEncode(apiData) : null,
      'cached_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // Then, update the names in StreamNameService if available
    try {
      if (_streamNameService != null) {
        await _streamNameService.setNamesFromApiData(station, apiData);
        print(
          "Cached station names in StreamNameService: ${station.stationId}",
        );
      }
    } catch (e) {
      print("Error updating StreamNameService: $e");
      // We don't want to fail the entire operation if name service fails
    }
  }

  /// Get a cached station by ID
  /// Still provides names for backward compatibility
  Future<Map<String, dynamic>?> getCachedStation(int stationId) async {
    if (_db == null) await _initDatabase();

    final results = await _db!.query(
      _stationsTable,
      where: 'station_id = ?',
      whereArgs: [stationId.toString()],
    );

    if (results.isEmpty) return null;

    final stationData = results.first;
    Map<String, dynamic> apiData = {};

    // Parse API data if available
    if (stationData['api_data'] != null) {
      try {
        apiData = jsonDecode(stationData['api_data'] as String);
      } catch (e) {
        print("Error parsing API data: $e");
      }
    }

    // Try to get the most up-to-date name from StreamNameService if available
    String? displayName;
    if (_streamNameService != null) {
      try {
        displayName = await _streamNameService.getDisplayName(
          stationId.toString(),
        );

        // If API data exists, update it with the current display name
        if (apiData.isNotEmpty) {
          apiData['name'] = displayName;
        }
      } catch (e) {
        print("Error getting name from StreamNameService: $e");
        // Fall back to stored name if error occurs
      }
    }

    // Build the response with the station data
    return {
      'station': {
        'id': stationId,
        'name':
            displayName ??
            stationData['name'], // Use the display name if available
        'lat': stationData['latitude'],
        'lon': stationData['longitude'],
        'elevation': stationData['elevation'],
        'color': stationData['color'],
      },
      'apiData': apiData,
      'cachedAt': stationData['cached_at'],
    };
  }

  /// Get only the station data without names
  /// Useful when names will be handled separately by StreamNameService
  Future<Map<String, dynamic>?> getStationDataOnly(int stationId) async {
    if (_db == null) await _initDatabase();

    final results = await _db!.query(
      _stationsTable,
      columns: [
        'station_id',
        'latitude',
        'longitude',
        'elevation',
        'color',
        'cached_at',
      ],
      where: 'station_id = ?',
      whereArgs: [stationId.toString()],
    );

    if (results.isEmpty) return null;

    final stationData = results.first;

    return {
      'station': {
        'id': stationId,
        'lat': stationData['latitude'],
        'lon': stationData['longitude'],
        'elevation': stationData['elevation'],
        'color': stationData['color'],
      },
      'cachedAt': stationData['cached_at'],
    };
  }

  /// Get only the API data for a station
  Future<Map<String, dynamic>?> getStationApiData(int stationId) async {
    if (_db == null) await _initDatabase();

    final results = await _db!.query(
      _stationsTable,
      columns: ['api_data', 'cached_at'],
      where: 'station_id = ?',
      whereArgs: [stationId.toString()],
    );

    if (results.isEmpty) return null;

    final stationData = results.first;

    if (stationData['api_data'] == null) return null;

    try {
      final apiData = jsonDecode(stationData['api_data'] as String);
      return {'data': apiData, 'cachedAt': stationData['cached_at']};
    } catch (e) {
      print("Error parsing API data: $e");
      return null;
    }
  }

  /// Cache a forecast
  Future<void> cacheForecast(
    int stationId,
    Map<String, dynamic> forecastData, {
    int? expiryHours,
  }) async {
    if (_db == null) await _initDatabase();

    final now = DateTime.now().millisecondsSinceEpoch;
    final expires = now + (expiryHours ?? 24) * 60 * 60 * 1000;

    // Delete any existing forecasts for this station
    await _db!.delete(
      _forecastsTable,
      where: 'station_id = ?',
      whereArgs: [stationId.toString()],
    );

    // Insert new forecast
    await _db!.insert(_forecastsTable, {
      'station_id': stationId.toString(),
      'forecast_data': jsonEncode(forecastData),
      'cached_at': now,
      'expires_at': expires,
    });
  }

  /// Get a cached forecast
  Future<Map<String, dynamic>?> getCachedForecast(
    int stationId, {
    bool ignoreExpiry = false,
  }) async {
    if (_db == null) await _initDatabase();

    final now = DateTime.now().millisecondsSinceEpoch;

    // Construct query parameters
    final String whereClause =
        ignoreExpiry ? 'station_id = ?' : 'station_id = ? AND expires_at > ?';
    final List<dynamic> whereArgs =
        ignoreExpiry ? [stationId.toString()] : [stationId.toString(), now];

    final results = await _db!.query(
      _forecastsTable,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'cached_at DESC',
      limit: 1,
    );

    if (results.isEmpty) return null;

    final forecast = results.first;
    final forecastData = jsonDecode(forecast['forecast_data'] as String);

    return {
      'data': forecastData,
      'cachedAt': forecast['cached_at'],
      'expiresAt': forecast['expires_at'],
    };
  }

  /// Get all cached stations
  Future<List<Map<String, dynamic>>> getAllCachedStations() async {
    if (_db == null) await _initDatabase();

    final results = await _db!.query(_stationsTable);
    final stations = <Map<String, dynamic>>[];

    for (final data in results) {
      final stationId = data['station_id'].toString();
      String? displayName;

      // Try to get name from StreamNameService if available
      if (_streamNameService != null) {
        try {
          displayName = await _streamNameService.getDisplayName(stationId);
        } catch (e) {
          print("Error getting name for station $stationId: $e");
        }
      }

      Map<String, dynamic> apiData = {};
      if (data['api_data'] != null) {
        try {
          apiData = jsonDecode(data['api_data'] as String);
        } catch (e) {
          print("Error parsing API data for station $stationId: $e");
        }
      }

      stations.add({
        'station': {
          'id': int.tryParse(stationId) ?? 0,
          'name': displayName ?? data['name'],
          'lat': data['latitude'],
          'lon': data['longitude'],
          'elevation': data['elevation'],
          'color': data['color'],
        },
        'apiData': apiData,
        'cachedAt': data['cached_at'],
      });
    }

    return stations;
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    if (_db == null) await _initDatabase();

    // Count stations
    final stationCount =
        Sqflite.firstIntValue(
          await _db!.rawQuery('SELECT COUNT(*) FROM $_stationsTable'),
        ) ??
        0;

    // Count forecasts
    final forecastCount =
        Sqflite.firstIntValue(
          await _db!.rawQuery('SELECT COUNT(*) FROM $_forecastsTable'),
        ) ??
        0;

    // Count map regions
    final regionCount =
        Sqflite.firstIntValue(
          await _db!.rawQuery('SELECT COUNT(*) FROM $_mapRegionsTable'),
        ) ??
        0;

    // Get total size (approximate)
    int dbSize = 0;
    if (_dbPath != null) {
      final dbFile = File(_dbPath!);
      if (await dbFile.exists()) {
        dbSize = await dbFile.length();
      }
    }

    // Calculate cache dir size
    int cacheSize = 0;
    if (_cacheDirPath != null) {
      cacheSize = await _calculateDirSize(Directory(_cacheDirPath!));
    }

    final totalSize = dbSize + cacheSize;

    return {
      'stationCount': stationCount,
      'forecastCount': forecastCount,
      'tileCount': regionCount, // This is just an approximation
      'cacheSizeBytes': totalSize,
      'cacheSizeMb': (totalSize / (1024 * 1024)).ceil(),
    };
  }

  /// Calculate directory size recursively
  Future<int> _calculateDirSize(Directory dir) async {
    int size = 0;
    try {
      final List<FileSystemEntity> entities = await dir.list().toList();
      for (final entity in entities) {
        if (entity is File) {
          size += await entity.length();
        } else if (entity is Directory) {
          size += await _calculateDirSize(entity);
        }
      }
    } catch (e) {
      print('Error calculating dir size: $e');
    }
    return size;
  }

  /// Perform cache cleanup to limit size
  Future<void> performCacheCleanup({int maxCacheSizeMb = 100}) async {
    if (_db == null) await _initDatabase();

    final stats = await getCacheStats();
    final currentSizeMb = stats['cacheSizeMb'] as int;

    if (currentSizeMb <= maxCacheSizeMb) return;

    // First, clean up expired forecasts
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db!.delete(
      _forecastsTable,
      where: 'expires_at < ?',
      whereArgs: [now],
    );

    // If still too large, delete older forecasts
    if ((await getCacheStats())['cacheSizeMb'] > maxCacheSizeMb) {
      final oldestForecasts = await _db!.query(
        _forecastsTable,
        orderBy: 'cached_at ASC',
        limit: 10,
      );

      for (final forecast in oldestForecasts) {
        await _db!.delete(
          _forecastsTable,
          where: 'id = ?',
          whereArgs: [forecast['id']],
        );

        if ((await getCacheStats())['cacheSizeMb'] <= maxCacheSizeMb) {
          break;
        }
      }
    }

    // If still too large, delete older map regions
    if ((await getCacheStats())['cacheSizeMb'] > maxCacheSizeMb) {
      final oldestRegions = await _db!.query(
        _mapRegionsTable,
        orderBy: 'downloaded_at ASC',
        limit: 5,
      );

      for (final region in oldestRegions) {
        await _db!.delete(
          _mapRegionsTable,
          where: 'id = ?',
          whereArgs: [region['id']],
        );

        if ((await getCacheStats())['cacheSizeMb'] <= maxCacheSizeMb) {
          break;
        }
      }
    }
  }

  /// Clear all cached data
  Future<void> clearAllCache() async {
    if (_db == null) await _initDatabase();

    await _db!.delete(_stationsTable);
    await _db!.delete(_forecastsTable);
    await _db!.delete(_mapRegionsTable);

    // Clear cache directory
    if (_cacheDirPath != null) {
      final dir = Directory(_cacheDirPath!);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create();
      }
    }
  }

  /// Clear specific type of cached data
  Future<void> clearCacheByType(String cacheType) async {
    if (_db == null) await _initDatabase();

    switch (cacheType) {
      case 'stations':
        await _db!.delete(_stationsTable);
        break;
      case 'forecasts':
        await _db!.delete(_forecastsTable);
        break;
      case 'map_tiles':
        await _db!.delete(_mapRegionsTable);
        // Also clear map tile files from cache dir
        if (_cacheDirPath != null) {
          final mapTilesDir = Directory(join(_cacheDirPath!, 'map_tiles'));
          if (await mapTilesDir.exists()) {
            await mapTilesDir.delete(recursive: true);
            await mapTilesDir.create();
          }
        }
        break;
      case 'all':
        await clearAllCache();
        break;
      default:
        throw ArgumentError('Unknown cache type: $cacheType');
    }
  }
}
