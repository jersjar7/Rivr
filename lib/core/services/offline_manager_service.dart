// lib/core/services/offline_manager_service.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../cache/services/cache_service.dart';
import '../network/api_client.dart';
import '../network/network_info.dart';
import '../../features/map/domain/entities/map_station.dart';

enum OfflineStatus { initial, loading, ready, downloading, error }

enum OfflineDownloadType { currentMapRegion, favoriteAreas, customArea }

/// Central service for managing offline capabilities
class OfflineManagerService extends ChangeNotifier {
  final CacheService _cacheService;
  final ApiClient _apiClient;

  // State
  OfflineStatus _status = OfflineStatus.initial;
  String? _errorMessage;
  double _downloadProgress = 0.0;
  bool _offlineModeEnabled = false;

  // Cache statistics
  Map<String, dynamic> _cacheStats = {
    'stationCount': 0,
    'forecastCount': 0,
    'tileCount': 0,
    'cacheSizeBytes': 0,
    'cacheSizeMb': 0,
  };

  // Current download operation info
  OfflineDownloadType? _currentDownloadType;
  String? _currentDownloadName;
  bool _isDownloading = false;

  // Flag to prevent redundant cache refreshes
  bool _isRefreshingCacheStats = false;

  // Debounce timer for non-critical operations
  Timer? _debounceTimer;

  // Getters
  OfflineStatus get status => _status;
  String? get errorMessage => _errorMessage;
  double get downloadProgress => _downloadProgress;
  bool get offlineModeEnabled => _offlineModeEnabled;
  bool get isDownloading => _isDownloading;
  int get cachedStationCount => _cacheStats['stationCount'] ?? 0;
  int get cachedForecastCount => _cacheStats['forecastCount'] ?? 0;
  int get cachedTileCount => _cacheStats['tileCount'] ?? 0;
  int get cacheSizeInMb => _cacheStats['cacheSizeMb'] ?? 0;
  OfflineDownloadType? get currentDownloadType => _currentDownloadType;
  String? get currentDownloadName => _currentDownloadName;

  OfflineManagerService({
    required CacheService cacheService,
    required ApiClient apiClient,
    required NetworkInfo networkInfo,
  }) : _cacheService = cacheService,
       _apiClient = apiClient {
    _initialize();
  }

  /// Initialize the offline manager service
  Future<void> _initialize() async {
    try {
      _setStatus(OfflineStatus.loading);

      // Perform initial setup
      await _refreshCacheStats();

      _setStatus(OfflineStatus.ready);
    } catch (e) {
      _setError('Failed to initialize offline manager: $e');
    }
  }

  /// Toggle offline mode
  void setOfflineMode(bool enabled) {
    // Only update if the value actually changes
    if (_offlineModeEnabled == enabled) return;

    _offlineModeEnabled = enabled;

    // Update API client offline mode
    _apiClient.setOfflineMode(enabled);

    notifyListeners();
  }

  /// Cache a station data for offline use
  Future<void> cacheStation(
    MapStation station,
    Map<String, dynamic>? apiData,
  ) async {
    print("DEBUG CACHE: Caching station ${station.stationId}");
    print("DEBUG CACHE: Station name: ${station.name}");
    print("DEBUG CACHE: API data: $apiData");
    if (apiData != null) {
      print("DEBUG CACHE: API data name: ${apiData['name']}");
    }

    if (apiData == null) return;

    final stationKey = 'station_${station.stationId}';

    // Save station metadata and API data
    await _cacheService.set(stationKey, {
      'station': {
        'id': station.stationId,
        'name': station.name,
        'lat': station.lat,
        'lon': station.lon,
        'elevation': station.elevation,
        'color': station.color,
      },
      'apiData': apiData,
      'cachedAt': DateTime.now().millisecondsSinceEpoch,
    }, duration: const Duration(days: 30));

    print("DEBUG CACHE: Station cached successfully");

    // Use a debounce for non-critical operations like updating stats
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _refreshCacheStats();
    });
  }

  /// Get cached station data
  Future<Map<String, dynamic>?> getCachedStation(int stationId) async {
    print("DEBUG CACHE GET: Getting cached station $stationId");
    final stationKey = 'station_$stationId';
    final data = await _cacheService.get<Map<String, dynamic>>(stationKey);

    if (data != null) {
      print("DEBUG CACHE GET: Found cached data");
      if (data['apiData'] != null) {
        print("DEBUG CACHE GET: API data: ${data['apiData']}");
        if (data['apiData'] is Map && data['apiData']['name'] != null) {
          print("DEBUG CACHE GET: Cached API name: ${data['apiData']['name']}");
        }
      }
      if (data['station'] != null && data['station']['name'] != null) {
        print(
          "DEBUG CACHE GET: Cached station name: ${data['station']['name']}",
        );
      }
    } else {
      print("DEBUG CACHE GET: No cached data found");
    }

    return data;
  }

  /// Cache forecast data
  Future<void> cacheForecast(
    int stationId,
    Map<String, dynamic> forecastData, {
    int? expiryHours,
  }) async {
    final forecastKey = 'forecast_$stationId';

    await _cacheService.set(forecastKey, {
      'data': forecastData,
      'cachedAt': DateTime.now().millisecondsSinceEpoch,
    }, duration: Duration(hours: expiryHours ?? 24));

    // Use a debounce for non-critical operations
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _refreshCacheStats();
    });
  }

  /// Get cached forecast data
  Future<Map<String, dynamic>?> getCachedForecast(
    int stationId, {
    bool ignoreExpiry = false,
  }) async {
    final forecastKey = 'forecast_$stationId';

    if (ignoreExpiry) {
      // TODO: Implement a way to get cached forecast even if expired
      // This might require direct database access or a special method in CacheService
      return await _cacheService.get<Map<String, dynamic>>(forecastKey);
    }

    return await _cacheService.get<Map<String, dynamic>>(forecastKey);
  }

  /// Download map region for offline use
  Future<bool> downloadCurrentMapRegion({
    required MapboxMap mapboxMap,
    required String regionName,
    double? minZoom,
    double? maxZoom,
  }) async {
    if (_isDownloading) return false;

    try {
      _isDownloading = true;
      _currentDownloadType = OfflineDownloadType.currentMapRegion;
      _currentDownloadName = regionName;
      _downloadProgress = 0.0;
      notifyListeners();

      // Get the current visible region from the map
      final cameraState = await mapboxMap.getCameraState();
      final visibleRegion = await mapboxMap.coordinateBoundsForCamera(
        CameraOptions(
          center: cameraState.center,
          zoom: cameraState.zoom,
          bearing: cameraState.bearing,
          pitch: cameraState.pitch,
        ),
      );

      // Default zoom levels if not provided
      final minZoomLevel = minZoom ?? cameraState.zoom - 2;
      final maxZoomLevel = maxZoom ?? cameraState.zoom + 1;

      // Simulate download with less frequent updates
      for (int i = 0; i < 10; i++) {
        // Simulate download progress with fewer UI updates
        await Future.delayed(const Duration(milliseconds: 300));

        // Only update UI every other step or when complete
        if (i % 2 == 0 || i == 9) {
          _downloadProgress = (i + 1) / 10;
          notifyListeners();
        }
      }

      _isDownloading = false;
      _currentDownloadType = null;
      _currentDownloadName = null;

      // Store metadata about downloaded region
      await _cacheService.set('map_region_$regionName', {
        'name': regionName,
        'bounds': {
          'southwest': {
            'lat': visibleRegion.southwest.coordinates.lat,
            'lon': visibleRegion.southwest.coordinates.lng,
          },
          'northeast': {
            'lat': visibleRegion.northeast.coordinates.lat,
            'lon': visibleRegion.northeast.coordinates.lng,
          },
        },
        'minZoom': minZoomLevel,
        'maxZoom': maxZoomLevel,
        'downloadedAt': DateTime.now().millisecondsSinceEpoch,
      }, duration: const Duration(days: 90));

      await _refreshCacheStats();
      notifyListeners();

      return true;
    } catch (e) {
      _setError('Failed to download region: $e');

      _isDownloading = false;
      _currentDownloadType = null;
      _currentDownloadName = null;
      notifyListeners();

      return false;
    }
  }

  /// Cancel current download
  void cancelDownload() {
    if (_isDownloading) {
      _isDownloading = false;
      _currentDownloadType = null;
      _currentDownloadName = null;
      _downloadProgress = 0.0;
      notifyListeners();
    }
  }

  /// Clear all cached data
  Future<void> clearAllCache() async {
    await _cacheService.clearAll();
    await _refreshCacheStats();
  }

  /// Clear specific type of cached data
  Future<void> clearCacheByType(String cacheType) async {
    final db = await (_cacheService as dynamic)._cacheDatabase.database;

    switch (cacheType) {
      case 'map_tiles':
        // Clear map tile cache - implementation depends on map service
        break;
      case 'forecasts':
        // Delete all forecast cache entries
        await db.delete(
          'cache_entries',
          where: 'key LIKE ?',
          whereArgs: ['forecast_%'],
        );
        break;
      case 'stations':
        // Delete all station cache entries
        await db.delete(
          'cache_entries',
          where: 'key LIKE ?',
          whereArgs: ['station_%'],
        );
        break;
    }

    await _refreshCacheStats();
  }

  /// Refresh cache statistics
  Future<void> _refreshCacheStats() async {
    // Prevent multiple simultaneous refreshes
    if (_isRefreshingCacheStats) return;

    _isRefreshingCacheStats = true;

    try {
      final db = await (_cacheService as dynamic)._cacheDatabase.database;

      // Count station entries
      final stationCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM cache_entries WHERE key LIKE ?',
        ['station_%'],
      );

      // Count forecast entries
      final forecastCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM cache_entries WHERE key LIKE ?',
        ['forecast_%'],
      );

      // Get total size
      final cacheSize = await _cacheService.getCacheSize();

      final newStats = {
        'stationCount': stationCount.first['count'] ?? 0,
        'forecastCount': forecastCount.first['count'] ?? 0,
        'tileCount': 0, // Placeholder - implementation depends on map service
        'cacheSizeBytes': cacheSize,
        'cacheSizeMb': (cacheSize / (1024 * 1024)).ceil(),
      };

      // Only update and notify if stats have changed
      if (_cacheStats['stationCount'] != newStats['stationCount'] ||
          _cacheStats['forecastCount'] != newStats['forecastCount'] ||
          _cacheStats['cacheSizeBytes'] != newStats['cacheSizeBytes']) {
        _cacheStats = newStats;
        notifyListeners();
      }
    } catch (e) {
      print('Error refreshing cache stats: $e');
    } finally {
      _isRefreshingCacheStats = false;
    }
  }

  /// Get total cache size in MB
  Future<int> getCacheSizeInMb() async {
    final size = await _cacheService.getCacheSize();
    return (size / (1024 * 1024)).ceil();
  }

  /// Public method to refresh cache stats
  Future<void> refreshCacheStats() async {
    await _refreshCacheStats();
  }

  /// Set status with notification
  void _setStatus(OfflineStatus newStatus) {
    if (_status == newStatus) return;

    _status = newStatus;
    notifyListeners();
  }

  /// Set error state
  void _setError(String message) {
    _errorMessage = message;
    _status = OfflineStatus.error;
    notifyListeners();
  }

  /// Clear error state
  void clearError() {
    _errorMessage = null;
    if (_status == OfflineStatus.error) {
      _status = OfflineStatus.ready;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
