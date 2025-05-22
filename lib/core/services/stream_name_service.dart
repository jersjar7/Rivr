// lib/core/services/stream_name_service.dart

import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:get_it/get_it.dart';
import '../storage/app_database.dart';
import '../cache/services/cache_service.dart';
import '../di/service_locator.dart';
import '../../features/map/domain/entities/map_station.dart';

/// Service responsible for managing stream names throughout the app.
///
/// Acts as the single source of truth for all stream names.
/// Maintains both original API names and user-defined display names.
/// Provides methods to get, update, and check if a name is custom.
/// Notifies listeners when names change.
class StreamNameService {
  // Dependencies
  final AppDatabase _appDatabase;
  final CacheService _cacheService;

  // Cache for quick access (stationId -> name info)
  final Map<String, StreamNameInfo> _nameCache = {};

  // Stream controller for broadcasting name changes
  final _nameChangesController = StreamController<StreamNameChange>.broadcast();

  /// Stream of name changes that UI components can listen to
  Stream<StreamNameChange> get nameChanges => _nameChangesController.stream;

  /// Constructor with dependencies
  StreamNameService({
    required AppDatabase appDatabase,
    required CacheService cacheService,
  }) : _appDatabase = appDatabase,
       _cacheService = cacheService;

  /// Factory constructor using service locator
  factory StreamNameService.fromServiceLocator() {
    return StreamNameService(
      appDatabase: sl<AppDatabase>(),
      cacheService: sl<CacheService>(),
    );
  }

  /// Initialize the service, loading initial data if needed
  Future<void> initialize() async {
    // You might want to preload some names on startup
    // or defer loading until needed
    print("StreamNameService: Initialized");
  }

  /// Get stream name information for a station
  /// Returns both original and display names
  Future<StreamNameInfo> getNameInfo(String stationId) async {
    // Check cache first
    if (_nameCache.containsKey(stationId)) {
      return _nameCache[stationId]!;
    }

    // Try to get from database
    final db = await _appDatabase.database;

    // Ensure table exists before querying
    await _ensureTableExists(db);

    final results = await db.query(
      'stream_names',
      where: 'station_id = ?',
      whereArgs: [stationId],
    );

    if (results.isNotEmpty) {
      final nameInfo = StreamNameInfo.fromMap(results.first);
      _nameCache[stationId] = nameInfo;
      return nameInfo;
    }

    // Try to get from cache service
    try {
      final cacheKey = 'station_name_$stationId';
      final cachedData = await _cacheService.get<Map<String, dynamic>>(
        cacheKey,
      );

      if (cachedData != null) {
        final nameInfo = StreamNameInfo.fromJson(cachedData);
        _nameCache[stationId] = nameInfo;
        return nameInfo;
      }
    } catch (e) {
      print("StreamNameService: Error retrieving from cache: $e");
    }

    // If no data found, return default info
    return StreamNameInfo(
      stationId: stationId,
      displayName: 'Stream $stationId',
      originalApiName: null,
      lastUpdated: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Get just the display name for a station
  /// This is the main method that should be used when just needing to show a name
  Future<String> getDisplayName(String stationId) async {
    final nameInfo = await getNameInfo(stationId);
    return nameInfo.displayName;
  }

  /// Set the original API name for a station
  /// This should only be called when retrieving data from the API
  /// and should never be changed afterwards
  Future<void> setOriginalApiName(String stationId, String? apiName) async {
    if (apiName == null || apiName.trim().isEmpty) {
      print(
        "StreamNameService: Ignoring empty API name for station $stationId",
      );
      return;
    }

    // Get current info
    final currentInfo = await getNameInfo(stationId);

    // If we already have an original API name, don't overwrite it
    if (currentInfo.originalApiName != null &&
        currentInfo.originalApiName!.isNotEmpty) {
      print(
        "StreamNameService: Original API name already exists for station $stationId, not overwriting",
      );
      return;
    }

    // Create new info with original API name
    final newInfo = StreamNameInfo(
      stationId: stationId,
      // If no display name set yet, use the API name as display name too
      displayName:
          currentInfo.displayName == 'Stream $stationId'
              ? apiName
              : currentInfo.displayName,
      originalApiName: apiName,
      lastUpdated: DateTime.now().millisecondsSinceEpoch,
    );

    // Save to database and cache
    await _saveNameInfo(newInfo);

    // Update cache and notify listeners
    _nameCache[stationId] = newInfo;
    _notifyNameChange(stationId, newInfo.displayName);
  }

  /// Update the display name for a station
  /// This can be called whenever the user edits a name
  Future<bool> updateDisplayName(String stationId, String newName) async {
    try {
      // Validate name
      if (newName.trim().isEmpty) {
        print("StreamNameService: Cannot set empty display name");
        return false;
      }

      // Get current info
      final currentInfo = await getNameInfo(stationId);

      // Create new info with updated display name
      final newInfo = StreamNameInfo(
        stationId: stationId,
        displayName: newName.trim(),
        originalApiName: currentInfo.originalApiName,
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
      );

      // Save to database and cache
      await _saveNameInfo(newInfo);

      // Update cache and notify listeners
      _nameCache[stationId] = newInfo;
      _notifyNameChange(stationId, newName);

      return true;
    } catch (e) {
      print("StreamNameService: Error updating display name: $e");
      return false;
    }
  }

  /// Reset display name to original API name
  Future<bool> resetToOriginalName(String stationId) async {
    try {
      // Get current info
      final currentInfo = await getNameInfo(stationId);

      // Make sure we have an original API name to reset to
      if (currentInfo.originalApiName == null ||
          currentInfo.originalApiName!.isEmpty) {
        print("StreamNameService: No original API name to reset to");
        return false;
      }

      // Create new info with original name as display name
      final newInfo = StreamNameInfo(
        stationId: stationId,
        displayName: currentInfo.originalApiName!,
        originalApiName: currentInfo.originalApiName,
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
      );

      // Save to database and cache
      await _saveNameInfo(newInfo);

      // Update cache and notify listeners
      _nameCache[stationId] = newInfo;
      _notifyNameChange(stationId, currentInfo.originalApiName!);

      return true;
    } catch (e) {
      print("StreamNameService: Error resetting to original name: $e");
      return false;
    }
  }

  /// Check if a station has a custom name (different from original)
  Future<bool> hasCustomName(String stationId) async {
    final nameInfo = await getNameInfo(stationId);

    if (nameInfo.originalApiName == null || nameInfo.originalApiName!.isEmpty) {
      return false; // Can't be custom if we don't know the original
    }

    return nameInfo.displayName != nameInfo.originalApiName;
  }

  /// Set both original and display names from a station and API data
  /// Used when loading a station from the API
  Future<void> setNamesFromApiData(
    MapStation station,
    Map<String, dynamic>? apiData,
  ) async {
    // Extract name from API data
    String? apiName;
    if (apiData != null &&
        apiData.containsKey('name') &&
        apiData['name'] != null &&
        apiData['name'].toString().trim().isNotEmpty) {
      apiName = apiData['name'].toString().trim();
    }

    // API name takes priority, then station name, then default
    final originalName = apiName ?? station.name;

    if (originalName != null && originalName.isNotEmpty) {
      // Get current info
      final currentInfo = await getNameInfo(station.stationId.toString());

      // Only update if we don't already have both names
      if (currentInfo.originalApiName == null ||
          currentInfo.displayName == 'Stream ${station.stationId}') {
        final newInfo = StreamNameInfo(
          stationId: station.stationId.toString(),
          displayName:
              currentInfo.displayName == 'Stream ${station.stationId}'
                  ? originalName
                  : currentInfo.displayName,
          originalApiName: originalName,
          lastUpdated: DateTime.now().millisecondsSinceEpoch,
        );

        // Save to database and cache
        await _saveNameInfo(newInfo);

        // Update cache
        _nameCache[station.stationId.toString()] = newInfo;

        // If we updated the display name, notify listeners
        if (currentInfo.displayName != newInfo.displayName) {
          _notifyNameChange(station.stationId.toString(), newInfo.displayName);
        }
      }
    }
  }

  /// Import names from favorites repository
  /// Used for migrating existing data
  Future<void> importFromFavorites(List<Map<String, dynamic>> favorites) async {
    for (final favorite in favorites) {
      final stationId = favorite['stationId']?.toString();
      final name = favorite['name']?.toString();
      final originalApiName = favorite['originalApiName']?.toString();

      if (stationId != null && name != null) {
        final nameInfo = StreamNameInfo(
          stationId: stationId,
          displayName: name,
          originalApiName: originalApiName == "null" ? null : originalApiName,
          lastUpdated:
              favorite['lastUpdated'] ?? DateTime.now().millisecondsSinceEpoch,
        );

        await _saveNameInfo(nameInfo);
        _nameCache[stationId] = nameInfo;
      }
    }
  }

  /// Save name info to database and cache
  Future<void> _saveNameInfo(StreamNameInfo info) async {
    // Save to database
    final db = await _appDatabase.database;

    // Make sure table exists
    await _ensureTableExists(db);

    // Insert or update
    await db.insert(
      'stream_names',
      info.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Save to cache service for offline access
    try {
      final cacheKey = 'station_name_${info.stationId}';
      await _cacheService.set(
        cacheKey,
        info.toJson(),
        duration: const Duration(days: 365), // Long expiration
      );
    } catch (e) {
      print("StreamNameService: Error saving to cache: $e");
    }
  }

  /// Ensure database table exists
  Future<void> _ensureTableExists(Database db) async {
    // Check if table exists
    final tableExists = await _tableExists(db, 'stream_names');

    if (!tableExists) {
      await db.execute('''
        CREATE TABLE stream_names (
          station_id TEXT PRIMARY KEY,
          display_name TEXT NOT NULL,
          original_api_name TEXT,
          last_updated INTEGER NOT NULL
        )
      ''');
      print("StreamNameService: Created stream_names table");
    }
  }

  /// Check if a table exists in the database
  Future<bool> _tableExists(Database db, String tableName) async {
    final result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableName],
    );
    return result.isNotEmpty;
  }

  /// Notify listeners of a name change
  void _notifyNameChange(String stationId, String newName) {
    _nameChangesController.add(
      StreamNameChange(
        stationId: stationId,
        newName: newName,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  /// Clean up resources
  void dispose() {
    _nameChangesController.close();
  }
}

/// Model class for stream name information
class StreamNameInfo {
  final String stationId;
  final String displayName;
  final String? originalApiName;
  final int lastUpdated;

  StreamNameInfo({
    required this.stationId,
    required this.displayName,
    this.originalApiName,
    required this.lastUpdated,
  });

  /// Create from database map
  factory StreamNameInfo.fromMap(Map<String, dynamic> map) {
    return StreamNameInfo(
      stationId: map['station_id'],
      displayName: map['display_name'],
      originalApiName:
          map['original_api_name'] == "null" ? null : map['original_api_name'],
      lastUpdated: map['last_updated'],
    );
  }

  /// Create from JSON
  factory StreamNameInfo.fromJson(Map<String, dynamic> json) {
    return StreamNameInfo(
      stationId: json['stationId'],
      displayName: json['displayName'],
      originalApiName:
          json['originalApiName'] == "null" ? null : json['originalApiName'],
      lastUpdated: json['lastUpdated'],
    );
  }

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      'station_id': stationId,
      'display_name': displayName,
      'original_api_name': originalApiName,
      'last_updated': lastUpdated,
    };
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'stationId': stationId,
      'displayName': displayName,
      'originalApiName': originalApiName,
      'lastUpdated': lastUpdated,
    };
  }
}

/// Model class for name change events
class StreamNameChange {
  final String stationId;
  final String newName;
  final int timestamp;

  StreamNameChange({
    required this.stationId,
    required this.newName,
    required this.timestamp,
  });
}

/// Extension for StreamNameService to add helper methods for registration
extension StreamNameServiceExt on GetIt {
  /// Register StreamNameService with GetIt
  void registerStreamNameService() {
    if (!isRegistered<StreamNameService>()) {
      registerLazySingleton<StreamNameService>(
        () => StreamNameService(
          appDatabase: get<AppDatabase>(),
          cacheService: get<CacheService>(),
        ),
      );
      print("Registered StreamNameService with GetIt");
    }
  }
}
