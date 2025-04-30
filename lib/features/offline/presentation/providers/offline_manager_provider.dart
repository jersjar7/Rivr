// lib/features/offline/presentation/providers/offline_manager_provider.dart

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:rivr/features/offline/data/repositories/offline_storage_repository.dart';
import '../../services/mapbox_offline_service.dart';
import '../../../favorites/presentation/providers/favorites_provider.dart';
import '../../../map/domain/entities/map_station.dart';

enum OfflineStatus { initial, loading, ready, downloading, error }

enum OfflineDownloadType { currentMapRegion, favoriteAreas, customArea }

class OfflineManagerProvider with ChangeNotifier {
  final OfflineStorageRepository _storage = OfflineStorageRepository();
  final MapboxOfflineService _mapboxService = MapboxOfflineService();
  final FavoritesProvider _favoritesProvider;

  OfflineStatus _status = OfflineStatus.initial;
  String? _errorMessage;
  double _downloadProgress = 0.0;
  Map<String, dynamic> _cacheStats = {
    'stationCount': 0,
    'forecastCount': 0,
    'tileCount': 0,
    'cacheSizeBytes': 0,
    'cacheSizeMb': 0,
  };
  bool _offlineModeEnabled = false;

  // Current download operation info
  OfflineDownloadType? _currentDownloadType;
  String? _currentDownloadName;
  bool _isDownloading = false;

  // Getters
  OfflineStatus get status => _status;
  String? get errorMessage => _errorMessage;
  double get downloadProgress => _downloadProgress;
  int get cachedStationCount => _cacheStats['stationCount'] ?? 0;
  int get cachedForecastCount => _cacheStats['forecastCount'] ?? 0;
  int get cachedTileCount => _cacheStats['tileCount'] ?? 0;
  int get cacheSizeInMb => _cacheStats['cacheSizeMb'] ?? 0;
  bool get offlineModeEnabled => _offlineModeEnabled;
  bool get isDownloading => _isDownloading;
  OfflineDownloadType? get currentDownloadType => _currentDownloadType;
  String? get currentDownloadName => _currentDownloadName;

  OfflineManagerProvider({required FavoritesProvider favoritesProvider})
    : _favoritesProvider = favoritesProvider {
    _initialize();
  }

  /// Initialize the offline manager
  Future<void> _initialize() async {
    try {
      _setStatus(OfflineStatus.loading);

      await _storage.initialize();
      await _mapboxService.initialize();

      // Load cache statistics
      await _refreshCacheStats();

      _setStatus(OfflineStatus.ready);
    } catch (e) {
      _setError('Failed to initialize offline manager: $e');
    }
  }

  /// Refresh cache statistics
  Future<void> _refreshCacheStats() async {
    try {
      _cacheStats = await _storage.getCacheStats();
      notifyListeners();
    } catch (e) {
      print('Error refreshing cache stats: $e');
    }
  }

  /// Toggle offline mode
  void toggleOfflineMode(bool enabled) {
    _offlineModeEnabled = enabled;
    notifyListeners();
  }

  /// Cache a station along with its API data
  Future<void> cacheStation(
    MapStation station,
    Map<String, dynamic>? apiData,
  ) async {
    try {
      await _storage.cacheStation(station, apiData);
      await _refreshCacheStats();
    } catch (e) {
      print('Error caching station: $e');
    }
  }

  /// Get a cached station by ID
  Future<Map<String, dynamic>?> getCachedStation(int stationId) async {
    return await _storage.getCachedStation(stationId);
  }

  /// Cache a forecast
  Future<void> cacheForecast(
    int stationId,
    Map<String, dynamic> forecastData, {
    int? expiryHours,
  }) async {
    try {
      await _storage.cacheForecast(
        stationId,
        forecastData,
        expiryHours: expiryHours,
      );
      await _refreshCacheStats();
    } catch (e) {
      print('Error caching forecast: $e');
    }
  }

  /// Get a cached forecast
  Future<Map<String, dynamic>?> getCachedForecast(
    int stationId, {
    bool ignoreExpiry = false,
  }) async {
    return await _storage.getCachedForecast(
      stationId,
      ignoreExpiry: ignoreExpiry,
    );
  }

  // Helper method to get the current map style URI
  Future<String> _getMapStyle(MapboxMap mapboxMap) async {
    // In newer versions of Mapbox SDK, we access style differently
    try {
      // Try to access style directly
      final style = mapboxMap.style;
      return await style.getStyleURI();
    } catch (e) {
      // Fallback to default style if we can't get the current one
      print('Error getting map style: $e');
      return MapboxStyles.STANDARD; // Use a default style
    }
  }

  /// Download the current map region for offline use
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

      // Use default zoom levels if not provided
      final minZoomLevel = minZoom ?? cameraState.zoom - 2;
      final maxZoomLevel = maxZoom ?? cameraState.zoom + 1;

      // Download the region
      await _mapboxService.downloadRegion(
        minLat: visibleRegion.southwest.coordinates.lat.toDouble(),
        maxLat: visibleRegion.northeast.coordinates.lat.toDouble(),
        minLon: visibleRegion.southwest.coordinates.lng.toDouble(),
        maxLon: visibleRegion.northeast.coordinates.lng.toDouble(),
        minZoom: minZoomLevel,
        maxZoom: maxZoomLevel,
        styleUrl: await _getMapStyle(mapboxMap),
        onProgress: (progress) {
          _downloadProgress = progress;
          notifyListeners();
        },
      );

      // Refresh cache stats after download
      await _refreshCacheStats();

      _isDownloading = false;
      _currentDownloadType = null;
      _currentDownloadName = null;
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

  /// Download regions for all favorite stations
  Future<bool> downloadFavoriteAreas({
    required MapboxMap mapboxMap,
    double radiusKm = 10.0,
    double? minZoom,
    double? maxZoom,
  }) async {
    if (_isDownloading) return false;

    try {
      _isDownloading = true;
      _currentDownloadType = OfflineDownloadType.favoriteAreas;
      _currentDownloadName = "Favorite Areas";
      _downloadProgress = 0.0;
      notifyListeners();

      // Get all favorite stations
      final favorites = _favoritesProvider.favorites;

      if (favorites.isEmpty) {
        _setError('No favorite stations found');
        _isDownloading = false;
        _currentDownloadType = null;
        _currentDownloadName = null;
        notifyListeners();
        return false;
      }

      // Use default zoom levels if not provided
      final minZoomLevel = minZoom ?? 10.0;
      final maxZoomLevel = maxZoom ?? 15.0;

      // Get current map style
      final styleUrl = await _getMapStyle(mapboxMap);

      // Calculate Earth's radius in degrees (rough approximation)
      // 111.32 km per degree of latitude/longitude at the equator
      final radiusDegrees = radiusKm / 111.32;

      // Process each favorite
      for (int i = 0; i < favorites.length; i++) {
        final favorite = favorites[i];

        // Get station coordinates (assuming position is stored as "lat,lon" string)
        final coords = favorite.position.toString().split(',');
        if (coords.length != 2) continue;

        final lat = double.tryParse(coords[0]);
        final lon = double.tryParse(coords[1]);

        if (lat == null || lon == null) continue;

        // Calculate bounding box
        final minLat = lat - radiusDegrees;
        final maxLat = lat + radiusDegrees;
        final minLon = lon - radiusDegrees;
        final maxLon = lon + radiusDegrees;

        // Update current download name
        _currentDownloadName = "Favorite: ${favorite.name}";
        notifyListeners();

        // Download the region
        await _mapboxService.downloadRegion(
          minLat: minLat,
          maxLat: maxLat,
          minLon: minLon,
          maxLon: maxLon,
          minZoom: minZoomLevel,
          maxZoom: maxZoomLevel,
          styleUrl: styleUrl,
          onProgress: (progress) {
            // Scale progress to account for multiple favorites
            _downloadProgress = (i + progress) / favorites.length;
            notifyListeners();
          },
        );
      }

      // Refresh cache stats after download
      await _refreshCacheStats();

      _isDownloading = false;
      _currentDownloadType = null;
      _currentDownloadName = null;
      notifyListeners();

      return true;
    } catch (e) {
      _setError('Failed to download favorite areas: $e');

      _isDownloading = false;
      _currentDownloadType = null;
      _currentDownloadName = null;
      notifyListeners();

      return false;
    }
  }

  /// Download a custom area
  Future<bool> downloadCustomArea({
    required String areaName,
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
    required String styleUrl,
    double minZoom = 10.0,
    double maxZoom = 15.0,
  }) async {
    if (_isDownloading) return false;

    try {
      _isDownloading = true;
      _currentDownloadType = OfflineDownloadType.customArea;
      _currentDownloadName = areaName;
      _downloadProgress = 0.0;
      notifyListeners();

      // Download the region
      await _mapboxService.downloadRegion(
        minLat: minLat,
        maxLat: maxLat,
        minLon: minLon,
        maxLon: maxLon,
        minZoom: minZoom,
        maxZoom: maxZoom,
        styleUrl: styleUrl,
        onProgress: (progress) {
          _downloadProgress = progress;
          notifyListeners();
        },
      );

      // Refresh cache stats after download
      await _refreshCacheStats();

      _isDownloading = false;
      _currentDownloadType = null;
      _currentDownloadName = null;
      notifyListeners();

      return true;
    } catch (e) {
      _setError('Failed to download custom area: $e');

      _isDownloading = false;
      _currentDownloadType = null;
      _currentDownloadName = null;
      notifyListeners();

      return false;
    }
  }

  /// Calculate estimated size of a download
  Future<int> calculateDownloadSize({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
    required double minZoom,
    required double maxZoom,
  }) async {
    return await _mapboxService.calculateRegionSize(
      minLat: minLat,
      maxLat: maxLat,
      minLon: minLon,
      maxLon: maxLon,
      minZoom: minZoom,
      maxZoom: maxZoom,
    );
  }

  /// Clean up the cache
  Future<void> cleanupCache({int maxCacheSizeMb = 100}) async {
    try {
      await _storage.performCacheCleanup(maxCacheSizeMb: maxCacheSizeMb);
      await _refreshCacheStats();
    } catch (e) {
      _setError('Failed to clean up cache: $e');
    }
  }

  /// Clear all cached data
  Future<void> clearAllCache() async {
    try {
      await _storage.clearAllCache();
      await _refreshCacheStats();
    } catch (e) {
      _setError('Failed to clear cache: $e');
    }
  }

  /// Clear specific type of cached data
  Future<void> clearCacheByType(String cacheType) async {
    try {
      await _storage.clearCacheByType(cacheType);
      await _refreshCacheStats();
    } catch (e) {
      _setError('Failed to clear cache: $e');
    }
  }

  /// Refresh cache statistics
  Future<void> refreshCacheStats() async {
    try {
      // Update cache stats
      _cacheStats = await _storage.getCacheStats();
      notifyListeners();
    } catch (e) {
      print('Error refreshing cache stats: $e');
      _setError('Failed to refresh cache statistics: $e');
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

  /// Helper to set status with notification
  void _setStatus(OfflineStatus status) {
    _status = status;
    notifyListeners();
  }

  /// Helper to set error state
  void _setError(String message) {
    _errorMessage = message;
    _status = OfflineStatus.error;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _errorMessage = null;
    if (_status == OfflineStatus.error) {
      _status = OfflineStatus.ready;
    }
    notifyListeners();
  }
}
