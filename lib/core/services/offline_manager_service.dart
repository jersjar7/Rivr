// lib/core/services/offline_manager_service.dart

import 'package:flutter/foundation.dart';
import 'package:rivr/core/cache/services/cache_service.dart';
import 'package:rivr/core/di/service_locator.dart';
import 'package:rivr/core/network/api_client.dart';
import 'package:rivr/core/network/network_info.dart';
import 'package:rivr/core/cache/storage/cache_database.dart';

/// Service for managing offline mode and cache settings
class OfflineManagerService extends ChangeNotifier {
  final CacheService _cacheService;
  final ApiClient _apiClient;
  final NetworkInfo _networkInfo;

  // Cache statistics
  int _cachedStationsCount = 0;
  int _cachedForecastsCount = 0;
  int _cachedMapTilesCount = 0;
  int _cacheSizeInBytes = 0;

  // Settings
  bool _offlineModeEnabled = false;
  bool _autoDownloadEnabled = false;
  int _maxCacheSizeMb = 500; // 500 MB default

  // Status
  bool _isLoading = false;
  bool _isDownloading = false;
  String? _errorMessage;
  double _downloadProgress = 0.0;

  // Getters
  bool get offlineModeEnabled => _offlineModeEnabled;
  bool get autoDownloadEnabled => _autoDownloadEnabled;
  int get maxCacheSizeMb => _maxCacheSizeMb;
  bool get isLoading => _isLoading;
  bool get isDownloading => _isDownloading;
  String? get errorMessage => _errorMessage;
  double get downloadProgress => _downloadProgress;
  int get cachedStationsCount => _cachedStationsCount;
  int get cachedForecastsCount => _cachedForecastsCount;
  int get cachedMapTilesCount => _cachedMapTilesCount;
  int get cacheSizeInMb => (_cacheSizeInBytes / (1024 * 1024)).round();

  OfflineManagerService({
    CacheService? cacheService,
    ApiClient? apiClient,
    NetworkInfo? networkInfo,
  }) : _cacheService = cacheService ?? sl<CacheService>(),
       _apiClient = apiClient ?? sl<ApiClient>(),
       _networkInfo = networkInfo ?? sl<NetworkInfo>() {
    // Initialize
    _init();
  }

  /// Initialize the service
  Future<void> _init() async {
    await refreshCacheStats();
    await _loadSettings();

    // Set offline mode based on settings and connectivity
    final isConnected = await _networkInfo.isConnected;
    if (!isConnected && !_offlineModeEnabled) {
      // Automatically enter offline mode when no connection
      setOfflineMode(true, notify: false);
    }
  }

  /// Load settings from persistent storage
  Future<void> _loadSettings() async {
    try {
      // Use CacheService to get settings
      final settings = await _cacheService.get<Map<String, dynamic>>(
        'offline_settings',
      );

      if (settings != null) {
        _offlineModeEnabled = settings['offlineModeEnabled'] ?? false;
        _autoDownloadEnabled = settings['autoDownloadEnabled'] ?? false;
        _maxCacheSizeMb = settings['maxCacheSizeMb'] ?? 500;
      }
    } catch (e) {
      print('Error loading offline settings: $e');
      // Use defaults
    }
  }

  /// Save settings to persistent storage
  Future<void> _saveSettings() async {
    try {
      await _cacheService.set(
        'offline_settings',
        {
          'offlineModeEnabled': _offlineModeEnabled,
          'autoDownloadEnabled': _autoDownloadEnabled,
          'maxCacheSizeMb': _maxCacheSizeMb,
        },
        // Settings don't expire
        duration: const Duration(days: 365),
      );
    } catch (e) {
      print('Error saving offline settings: $e');
    }
  }

  /// Toggle offline mode
  Future<void> setOfflineMode(bool enabled, {bool notify = true}) async {
    _offlineModeEnabled = enabled;

    // Propagate to API client
    _apiClient.setOfflineMode(enabled);

    // Save settings
    await _saveSettings();

    if (notify) {
      notifyListeners();
    }
  }

  /// Toggle auto-download
  void setAutoDownload(bool enabled) {
    _autoDownloadEnabled = enabled;
    _saveSettings();
    notifyListeners();
  }

  /// Set maximum cache size
  void setMaxCacheSize(int sizeMb) {
    _maxCacheSizeMb = sizeMb;
    _saveSettings();
    notifyListeners();

    // Trigger cache cleanup if over limit
    if (cacheSizeInMb > _maxCacheSizeMb) {
      cleanupCache();
    }
  }

  /// Refresh cache statistics
  Future<void> refreshCacheStats() async {
    if (_isLoading) return;

    _isLoading = true;
    if (_errorMessage != null) _errorMessage = null;
    notifyListeners();

    try {
      // Get database instance
      final cacheDb = CacheDatabase();
      final db = await cacheDb.database;

      // Count entries in each table
      _cachedStationsCount = await _getTableCount(db, 'cached_stations');
      _cachedForecastsCount = await _getTableCount(db, 'cached_forecasts');
      _cachedMapTilesCount = await _getTableCount(db, 'file_cache');

      // Get total cache size
      _cacheSizeInBytes = await _cacheService.getCacheSize();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to refresh cache stats: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Helper to get count from table
  Future<int> _getTableCount(dynamic db, String tableName) async {
    try {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableName',
      );
      return result.first['count'] as int? ?? 0;
    } catch (e) {
      print('Error counting $tableName: $e');
      return 0;
    }
  }

  /// Clean up cache to meet size limits
  Future<void> cleanupCache() async {
    if (_isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      // Clean expired entries first
      await _cacheService.cleanExpired();

      // If still over limit, perform more aggressive cleanup
      await refreshCacheStats();

      if (cacheSizeInMb > _maxCacheSizeMb) {
        // TODO: Implement more aggressive cleanup strategies
        // This would include removing oldest accessed entries
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to clean cache: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear all cache
  Future<void> clearAllCache() async {
    if (_isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _cacheService.clearAll();
      await refreshCacheStats();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to clear cache: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Download station areas for offline use
  Future<bool> downloadStationAreas(
    List<String> stationIds, {
    Function(double progress)? onProgress,
  }) async {
    if (_isDownloading) return false;

    _isDownloading = true;
    _downloadProgress = 0.0;
    notifyListeners();

    try {
      // Here you would implement the logic to:
      // 1. Download station data
      // 2. Download forecasts for each station
      // 3. Download map tiles for station areas

      // This would need to be implemented based on your data sources
      // For now, we'll just simulate progress updates

      final totalSteps = stationIds.length * 3; // 3 operations per station
      int completedSteps = 0;

      for (final stationId in stationIds) {
        // 1. Download station data
        // await _downloadStationData(stationId);
        completedSteps++;
        _updateProgress(completedSteps / totalSteps, onProgress);

        // 2. Download forecasts
        // await _downloadStationForecasts(stationId);
        completedSteps++;
        _updateProgress(completedSteps / totalSteps, onProgress);

        // 3. Download map tiles
        // await _downloadStationMapArea(stationId);
        completedSteps++;
        _updateProgress(completedSteps / totalSteps, onProgress);
      }

      // Update cache stats after download
      await refreshCacheStats();

      _isDownloading = false;
      _downloadProgress = 1.0;
      notifyListeners();

      return true;
    } catch (e) {
      _errorMessage = 'Failed to download station areas: ${e.toString()}';
      _isDownloading = false;
      notifyListeners();
      return false;
    }
  }

  /// Update download progress
  void _updateProgress(double progress, Function(double)? onProgress) {
    _downloadProgress = progress;
    onProgress?.call(progress);
    notifyListeners();
  }

  /// Cancel active downloads
  void cancelDownload() {
    if (!_isDownloading) return;

    // In a real implementation, you would abort any active download operations

    _isDownloading = false;
    _downloadProgress = 0.0;
    notifyListeners();
  }

  /// Check if there's enough space for a download of specified size
  Future<bool> checkAvailableSpace(int requiredMb) async {
    // Get available storage space
    // This is a platform-specific operation and would require plugins
    // For now, just check against our max cache size
    final availableMb = _maxCacheSizeMb - cacheSizeInMb;
    return availableMb >= requiredMb;
  }

  /// Clear error message
  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }
}
