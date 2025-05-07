// lib/features/favorites/presentation/providers/favorites_provider.dart

import 'dart:async';

import 'package:flutter/material.dart';
import '../../domain/entities/favorite.dart';
import '../../domain/usecases/add_favorite.dart';
import '../../domain/usecases/get_favorites.dart';
import '../../domain/usecases/is_favorite.dart';
import '../../domain/usecases/remove_favorite.dart';
import '../../domain/usecases/update_favorite_position.dart';
import '../../../../core/services/stream_name_service.dart';
import '../../../../core/services/offline_manager_service.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/di/service_locator.dart';
import './favorites_data_manager.dart';
import './favorites_persistence_manager.dart';

enum FavoritesStatus { initial, loading, loaded, error, noConnection }

/// Provider for managing favorites throughout the app
class FavoritesProvider with ChangeNotifier {
  // Use cases
  final GetFavorites getFavoritesUseCase;
  final AddFavorite addFavoriteUseCase;
  final RemoveFavorite removeFavoriteUseCase;
  final UpdateFavoritePosition updateFavoritePositionUseCase;
  final IsFavorite isFavoriteUseCase;

  // Services for offline functionality
  final OfflineManagerService _offlineManager;
  final NetworkInfo _networkInfo;
  final StreamNameService _streamNameService;

  // Helper managers for different aspects of favorites functionality
  late final FavoritesDataManager _dataManager;
  late final FavoritesPersistenceManager _persistenceManager;

  // State
  FavoritesStatus _status = FavoritesStatus.initial;
  List<Favorite> _favorites = [];
  String? _errorMessage;
  bool _isProcessing = false;
  bool _isUsingOfflineData = false;
  DateTime? _lastSyncTime;

  // Recently deleted favorites for undo functionality
  final Map<String, Favorite> _recentlyDeleted = {};

  // Getters
  FavoritesStatus get status => _status;
  List<Favorite> get favorites => _favorites;
  String? get errorMessage => _errorMessage;
  bool get isProcessing => _isProcessing;
  bool get isUsingOfflineData => _isUsingOfflineData;
  DateTime? get lastSyncTime => _lastSyncTime;

  // Direct access to managers for specialized operations
  FavoritesDataManager get dataManager => _dataManager;
  FavoritesPersistenceManager get persistenceManager => _persistenceManager;

  FavoritesProvider({
    required GetFavorites getFavorites,
    required AddFavorite addFavorite,
    required RemoveFavorite removeFavorite,
    required UpdateFavoritePosition updateFavoritePosition,
    required IsFavorite isFavorite,
    required OfflineManagerService offlineManager,
    required NetworkInfo networkInfo,
    StreamNameService? streamNameService,
  }) : getFavoritesUseCase = getFavorites,
       addFavoriteUseCase = addFavorite,
       removeFavoriteUseCase = removeFavorite,
       updateFavoritePositionUseCase = updateFavoritePosition,
       isFavoriteUseCase = isFavorite,
       _offlineManager = offlineManager,
       _networkInfo = networkInfo,
       _streamNameService = streamNameService ?? sl<StreamNameService>() {
    // Initialize helper managers
    _dataManager = FavoritesDataManager(
      parent: this,
      streamNameService: _streamNameService,
    );

    _persistenceManager = FavoritesPersistenceManager(
      parent: this,
      offlineManager: _offlineManager,
      networkInfo: _networkInfo,
    );

    // Initialize database tables
    _dataManager.initTables();
  }

  /// Public method to notify listeners of changes
  /// This allows manager classes to trigger UI updates without directly accessing protected methods
  void notifyChanges() {
    // Use microtask to avoid setState during build
    Future.microtask(() {
      notifyListeners();
    });
  }

  /// Set the last synchronization time
  /// This allows persistence manager to update sync time when retrieving cached data
  void setLastSyncTime(DateTime time) {
    _lastSyncTime = time;
    // No need to notify listeners as this is mostly for internal bookkeeping
  }

  // Load favorites for user with offline handling
  Future<void> loadFavorites(String userId) async {
    // Prevent multiple simultaneous loads
    if (_isProcessing) return;

    try {
      _isProcessing = true;

      // Only update status if changing from non-loading state
      if (_status != FavoritesStatus.loading) {
        _setStatus(FavoritesStatus.loading);
      }

      // Check network connectivity and offline mode
      final bool isConnected = await _networkInfo.isConnected;
      final bool isOfflineMode = _offlineManager.offlineModeEnabled;

      // If offline mode is enabled or there's no connection, try to use cached data
      if (isOfflineMode || !isConnected) {
        final cachedFavorites = await _persistenceManager.getCachedFavorites(
          userId,
        );

        if (cachedFavorites.isNotEmpty) {
          // Only update if the list actually changed
          if (!_areFavoritesEqual(_favorites, cachedFavorites)) {
            _favorites = cachedFavorites;
            _isUsingOfflineData = true;
            _setStatus(FavoritesStatus.loaded);
          }
          return;
        } else if (!isConnected) {
          // No cached data and no connection
          _setStatus(FavoritesStatus.noConnection);
          return;
        }
        // If we're in offline mode but no cache found, try online anyway
      }

      // If we have a connection and not in forced offline mode, load from repository
      final result = await getFavoritesUseCase(userId);

      result.fold(
        (failure) {
          _setError(failure.message);
        },
        (loadedFavorites) {
          // Only update if the list actually changed
          if (!_areFavoritesEqual(_favorites, loadedFavorites)) {
            _favorites = loadedFavorites;
            _isUsingOfflineData = false;
            _lastSyncTime = DateTime.now();

            // Sync favorite names with StreamNameService
            _syncFavoriteNamesWithService();

            _setStatus(FavoritesStatus.loaded);

            // Cache favorites for offline use
            _persistenceManager.cacheFavorites(userId, _favorites);
          } else {
            // If no change in data, just update the status if needed
            if (_status != FavoritesStatus.loaded) {
              _setStatus(FavoritesStatus.loaded);
            }
          }
        },
      );
    } catch (e) {
      _setError('Unexpected error: ${e.toString()}');
    } finally {
      _isProcessing = false;
    }
  }

  // Sync all favorite names with the StreamNameService
  void _syncFavoriteNamesWithService() {
    for (final favorite in _favorites) {
      try {
        // Store each name in the central service
        if (favorite.name.isNotEmpty) {
          _streamNameService.updateDisplayName(
            favorite.stationId,
            favorite.name,
          );
        }

        // Store original API names if available
        if (favorite.originalApiName != null &&
            favorite.originalApiName != "null" &&
            favorite.originalApiName!.isNotEmpty) {
          _streamNameService.setOriginalApiName(
            favorite.stationId,
            favorite.originalApiName,
          );
        }
      } catch (e) {
        print("Error syncing name for station ${favorite.stationId}: $e");
      }
    }
  }

  // Compare two favorite lists to avoid unnecessary updates
  bool _areFavoritesEqual(List<Favorite> list1, List<Favorite> list2) {
    if (list1.length != list2.length) return false;

    // Create a set of station IDs for quick comparison
    final set1 = {for (var f in list1) f.stationId};
    final set2 = {for (var f in list2) f.stationId};

    return set1.length == set2.length && set1.difference(set2).isEmpty;
  }

  // Update a specific favorite directly without going through the database
  void updateFavoriteDirectly(int index, Favorite updatedFavorite) {
    if (index >= 0 && index < _favorites.length) {
      _favorites[index] = updatedFavorite;

      // Sync with StreamNameService
      _streamNameService.updateDisplayName(
        updatedFavorite.stationId,
        updatedFavorite.name,
      );

      notifyListeners();
    }
  }

  // Check if a station is favorited
  Future<bool> checkIsFavorite(String userId, String stationId) async {
    try {
      // First check the local cache
      final isCached = _favorites.any(
        (f) => f.stationId == stationId && f.userId == userId,
      );

      if (isCached) {
        return true;
      }

      // Check connectivity
      final isConnected = await _networkInfo.isConnected;
      final isOfflineMode = _offlineManager.offlineModeEnabled;
      final useOfflineMode = !isConnected || isOfflineMode;

      if (useOfflineMode) {
        // In offline mode, check persisted cache
        final cachedFavorites = await _persistenceManager.getCachedFavorites(
          userId,
        );
        return cachedFavorites.any((f) => f.stationId == stationId);
      }

      // If online, check database
      final result = await isFavoriteUseCase(userId, stationId);

      return result.fold((failure) {
        print('Error checking favorite status: ${failure.message}');
        return false;
      }, (isFav) => isFav);
    } catch (e) {
      print('Exception checking favorite status: $e');
      return false;
    }
  }

  // Add a new favorite from a MapStation
  Future<bool> addFavoriteFromStation(
    String userId,
    String stationId, {
    String? displayName,
    String? description,
    String? originalApiName,
  }) async {
    return _dataManager.addFavorite(
      userId,
      stationId,
      displayName: displayName,
      description: description,
      originalApiName: originalApiName,
    );
  }

  // Remove a favorite
  Future<void> deleteFavorite(String userId, String stationId) async {
    if (_isProcessing) return;

    try {
      _isProcessing = true;

      // Find the favorite to remove
      final favoriteIndex = _favorites.indexWhere(
        (f) => f.stationId == stationId && f.userId == userId,
      );

      if (favoriteIndex < 0) {
        // Not found
        return;
      }

      // Store for potential undo
      final deletedFavorite = _favorites[favoriteIndex];
      _recentlyDeleted[stationId] = deletedFavorite;

      // Remove from local list first for responsive UI
      _favorites.removeAt(favoriteIndex);
      notifyListeners();

      // Check connectivity
      final bool isConnected = await _networkInfo.isConnected;
      final bool isOfflineMode = _offlineManager.offlineModeEnabled;

      if (!isConnected || isOfflineMode) {
        // Offline mode - add to pending operations
        await _persistenceManager.addToPendingOperations(
          'DELETE',
          deletedFavorite,
        );

        // Update cached favorites
        _persistenceManager.cacheFavorites(userId, _favorites);

        // Clean up the recently deleted after some time
        _scheduleRecentlyDeletedCleanup(stationId);
        return;
      }

      // Online mode - remove from database
      final result = await removeFavoriteUseCase(userId, stationId);

      result.fold(
        (failure) {
          // If deletion failed, restore the favorite
          _favorites.insert(favoriteIndex, deletedFavorite);
          _setError(failure.message);
        },
        (_) {
          // Success - already removed from the list
          // Update cache
          _persistenceManager.cacheFavorites(userId, _favorites);

          // Clean up the recently deleted after some time
          _scheduleRecentlyDeletedCleanup(stationId);
        },
      );
    } catch (e) {
      _setError('Failed to delete favorite: ${e.toString()}');
    } finally {
      _isProcessing = false;
    }
  }

  // Schedule cleanup of recently deleted item
  void _scheduleRecentlyDeletedCleanup(String stationId) {
    Future.delayed(const Duration(minutes: 5), () {
      _recentlyDeleted.remove(stationId);
    });
  }

  // Undo a recent deletion
  Future<void> undoDelete(String stationId) async {
    if (!_recentlyDeleted.containsKey(stationId)) {
      return; // Nothing to undo
    }

    final favorite = _recentlyDeleted.remove(stationId);
    if (favorite != null) {
      await _dataManager.addExistingFavorite(favorite);
    }
  }

  // Reorder favorites
  Future<void> reorderFavorites(int oldIndex, int newIndex) async {
    print(
      "DEBUG: FavoritesProvider.reorderFavorites called with oldIndex=$oldIndex, newIndex=$newIndex",
    );
    print(
      "DEBUG: Favorites list before reordering - types: ${_favorites.map((f) => f.runtimeType).toList()}",
    );
    print("DEBUG: Favorites length: ${_favorites.length}");

    try {
      await _dataManager.reorderFavorites(oldIndex, newIndex);
      print("DEBUG: Reordering completed in FavoritesProvider");
    } catch (e) {
      print("DEBUG: Error in FavoritesProvider.reorderFavorites: $e");
      print("DEBUG: Stack trace: ${StackTrace.current}");
    }
  }

  // Update favorite name using new StreamNameService
  Future<bool> updateFavoriteName(
    String userId,
    String stationId,
    String newName,
  ) async {
    print(
      "DEBUG: Provider updateFavoriteName called for station $stationId with new name '$newName'",
    );

    if (_isProcessing) {
      print("DEBUG: Provider is already processing, returning false");
      return false;
    }

    try {
      _isProcessing = true;
      print("DEBUG: Set _isProcessing = true");

      // First update the central StreamNameService
      print("DEBUG: About to update StreamNameService");
      final streamNameUpdateSuccess = await _streamNameService
          .updateDisplayName(stationId, newName);
      print("DEBUG: StreamNameService update result: $streamNameUpdateSuccess");

      if (!streamNameUpdateSuccess) {
        print("Warning: Failed to update StreamNameService for $stationId");
        // Continue anyway to maintain backward compatibility
      }

      // Now update the favorite in our local list
      print("DEBUG: Calling _dataManager.updateFavoriteName");
      final result = await _dataManager.updateFavoriteName(
        userId,
        stationId,
        newName,
      );
      print("DEBUG: _dataManager.updateFavoriteName returned: $result");
      return result;
    } catch (e) {
      print("Error in updateFavoriteName: $e");
      _setError('Failed to update favorite name: ${e.toString()}');
      return false;
    } finally {
      _isProcessing = false;
      print("DEBUG: Set _isProcessing = false");
    }
  }

  // Update favorite image
  Future<bool> updateFavoriteImage(
    String userId,
    String stationId,
    int imgNumber,
  ) async {
    return _dataManager.updateFavoriteImage(userId, stationId, imgNumber);
  }

  // Update custom image path
  Future<bool> updateFavoriteCustomImage(
    String userId,
    String stationId,
    String customImagePath,
  ) async {
    return _dataManager.updateFavoriteCustomImage(
      userId,
      stationId,
      customImagePath,
    );
  }

  // Check for connectivity and try to sync if needed
  Future<void> checkConnectionAndSync() async {
    await _persistenceManager.checkConnectionAndSync();
  }

  // Helper to sort favorites by position
  void sortFavoritesByPosition() {
    _favorites.sort((a, b) => a.position.compareTo(b.position));
  }

  // Helper to update status with notification
  void _setStatus(FavoritesStatus status) {
    // Only notify if status actually changed
    if (_status != status) {
      _status = status;

      // Use microtask to avoid setState during build
      Future.microtask(() {
        notifyListeners();
      });
    }
  }

  // Helper to set error state
  void _setError(String message) {
    // Only update if error message changed
    if (_errorMessage != message) {
      _errorMessage = message;
      _status = FavoritesStatus.error;

      // Use microtask to avoid setState during build
      Future.microtask(() {
        notifyListeners();
      });
    }
  }

  // Clear error
  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    // Clean up resources
    _persistenceManager.dispose();
    super.dispose();
  }
}
