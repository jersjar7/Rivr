// lib/features/favorites/presentation/providers/favorites_provider.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rivr/features/offline/data/repositories/offline_storage_repository.dart';
import '../../domain/entities/favorite.dart';
import '../../data/models/favorite_model.dart';
import '../../domain/usecases/add_favorite.dart';
import '../../domain/usecases/get_favorites.dart';
import '../../domain/usecases/is_favorite.dart';
import '../../domain/usecases/remove_favorite.dart';
import '../../domain/usecases/update_favorite_position.dart';
import '../../../../features/map/domain/entities/map_station.dart';
import '../../../../common/data/local/database_helper.dart';

enum FavoritesStatus { initial, loading, loaded, error }

class FavoritesProvider with ChangeNotifier {
  // Use cases
  final GetFavorites getFavoritesUseCase;
  final AddFavorite addFavoriteUseCase;
  final RemoveFavorite removeFavoriteUseCase;
  final UpdateFavoritePosition updateFavoritePositionUseCase;
  final IsFavorite isFavoriteUseCase;

  // State
  FavoritesStatus _status = FavoritesStatus.initial;
  List<Favorite> _favorites = [];
  String? _errorMessage;
  bool _isProcessing = false;

  // Recently deleted favorites for undo functionality
  final Map<String, Favorite> _recentlyDeleted = {};

  // Database helper
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  // Getters
  FavoritesStatus get status => _status;
  List<Favorite> get favorites => _favorites;
  String? get errorMessage => _errorMessage;
  bool get isProcessing => _isProcessing;

  final OfflineStorageRepository _offlineStorage = OfflineStorageRepository();

  FavoritesProvider({
    required GetFavorites getFavorites,
    required AddFavorite addFavorite,
    required RemoveFavorite removeFavorite,
    required UpdateFavoritePosition updateFavoritePosition,
    required IsFavorite isFavorite,
  }) : getFavoritesUseCase = getFavorites,
       addFavoriteUseCase = addFavorite,
       removeFavoriteUseCase = removeFavorite,
       updateFavoritePositionUseCase = updateFavoritePosition,
       isFavoriteUseCase = isFavorite {
    // Initialize database tables when provider is created
    _initTables();
  }

  // Initialize database tables
  Future<void> _initTables() async {
    try {
      await _databaseHelper.createFavoritesTable();
    } catch (e) {
      print("ERROR in FavoritesProvider: Failed to initialize tables: $e");
    }
  }

  // Load favorites for user with error handling and retry logic
  Future<void> loadFavorites(String userId) async {
    if (_isProcessing) return;

    try {
      _isProcessing = true;
      _setStatus(FavoritesStatus.loading);

      // Ensure favorites table exists
      await _databaseHelper.createFavoritesTable();

      final result = await getFavoritesUseCase(userId);

      result.fold(
        (failure) {
          _setError(failure.message);
        },
        (loadedFavorites) {
          _favorites = loadedFavorites;
          _setStatus(FavoritesStatus.loaded);
        },
      );
    } catch (e) {
      _setError('Unexpected error: ${e.toString()}');
    } finally {
      _isProcessing = false;
    }
  }

  // Add a new favorite from a MapStation
  Future<bool> addFavoriteFromStation(
    String userId,
    MapStation station, {
    String? description,
  }) async {
    if (_isProcessing) return false;

    try {
      _isProcessing = true;

      print("Adding station to favorites: ${station.stationId}");

      // Ensure favorites table exists
      await _databaseHelper.createFavoritesTable();

      // Check if already a favorite
      final isAlreadyFavorite = await checkIsFavorite(
        userId,
        station.stationId.toString(),
      );

      print(
        "Station ${station.stationId} already favorited: $isAlreadyFavorite",
      );

      if (isAlreadyFavorite) {
        return true; // Already a favorite, no need to add again
      }

      // Get the next position
      final nextPosition = _favorites.length;

      // Generate a random image number
      final random = math.Random();
      final randomImgNumber = random.nextInt(30) + 1;

      // Get proper name, with fallback to "Untitled Stream"
      String riverName = "Untitled Stream"; // Start with default
      try {
        // First check cached API data
        final cachedStation = await _offlineStorage.getCachedStation(
          station.stationId,
        );

        if (cachedStation != null && cachedStation['apiData'] != null) {
          final apiData = cachedStation['apiData'];
          if (apiData is Map<String, dynamic> &&
              apiData.containsKey('name') &&
              apiData['name'] != null &&
              apiData['name'].toString().isNotEmpty) {
            riverName = apiData['name'].toString();
          }
        }

        // Check if station has name from another source
        if (station.name != null && station.name!.isNotEmpty) {
          // Use the name as is, without sanitization
          riverName = station.name!;
        }
        // Otherwise, keep the default "Untitled Stream"
      } catch (e) {
        print("Error getting proper station name: $e");
        // Already have the default "Untitled Stream"
      }

      // Create favorite model from station
      final favorite = FavoriteModel(
        stationId: station.stationId.toString(),
        name: riverName, // Use our determined name with fallbacks
        userId: userId,
        position: nextPosition,
        color: station.color,
        description: description,
        imgNumber: randomImgNumber,
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
      );

      print(
        "Created favorite object: ${favorite.stationId}, position: ${favorite.position}, name: ${favorite.name}",
      );

      final result = await addFavoriteUseCase(favorite);

      return result.fold(
        (failure) {
          print("Failed to add favorite: ${failure.message}");
          _setError(failure.message);
          return false;
        },
        (_) {
          print("Successfully added favorite: ${favorite.stationId}");
          _favorites.add(favorite);
          _sortFavoritesByPosition();
          notifyListeners();
          return true;
        },
      );
    } catch (e) {
      print("Error in addFavoriteFromStation: $e");
      _setError('Failed to add favorite: ${e.toString()}');
      return false;
    } finally {
      _isProcessing = false;
    }
  }

  // Add a favorite directly (for undoing deletions)
  Future<void> addNewFavorite(Favorite favorite) async {
    if (_isProcessing) return;

    try {
      _isProcessing = true;

      // Ensure favorites table exists
      await _databaseHelper.createFavoritesTable();

      // Convert favorite to FavoriteModel if it's not already
      final favoriteModel =
          favorite is FavoriteModel
              ? favorite
              : FavoriteModel(
                stationId: favorite.stationId,
                name: favorite.name,
                userId: favorite.userId,
                position: favorite.position,
                color: favorite.color,
                description: favorite.description,
                imgNumber: favorite.imgNumber,
                lastUpdated: favorite.lastUpdated,
              );

      final result = await addFavoriteUseCase(favoriteModel);

      result.fold(
        (failure) {
          _setError(failure.message);
        },
        (_) {
          _favorites.add(favoriteModel);
          _sortFavoritesByPosition();
          notifyListeners();
        },
      );
    } catch (e) {
      _setError('Failed to add favorite: ${e.toString()}');
    } finally {
      _isProcessing = false;
    }
  }

  // Remove a favorite with undo capability
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

      // Then remove from database
      final result = await removeFavoriteUseCase(userId, stationId);

      result.fold(
        (failure) {
          // If deletion failed, restore the favorite
          _favorites.insert(favoriteIndex, deletedFavorite);
          _setError(failure.message);
        },
        (_) {
          // Success - already removed from the list
          // Clean up the recently deleted after some time
          Future.delayed(const Duration(minutes: 5), () {
            _recentlyDeleted.remove(stationId);
          });
        },
      );
    } catch (e) {
      _setError('Failed to delete favorite: ${e.toString()}');
    } finally {
      _isProcessing = false;
    }
  }

  // Undo a recent deletion
  Future<void> undoDelete(String stationId) async {
    if (!_recentlyDeleted.containsKey(stationId)) {
      return; // Nothing to undo
    }

    final favorite = _recentlyDeleted.remove(stationId);
    if (favorite != null) {
      await addNewFavorite(favorite);
    }
  }

  // Reorder favorites with proper position updates
  Future<void> reorderFavorites(int oldIndex, int newIndex) async {
    if (_isProcessing ||
        oldIndex < 0 ||
        newIndex < 0 ||
        oldIndex >= _favorites.length) {
      return;
    }

    try {
      _isProcessing = true;

      // Adjust indices for list operations
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }

      // Update the local list first for responsive UI
      final favorite = _favorites.removeAt(oldIndex);
      _favorites.insert(newIndex, favorite);
      notifyListeners();

      // Then update positions in the database
      final updatePromises = <Future<void>>[];
      for (int i = 0; i < _favorites.length; i++) {
        final fav = _favorites[i];
        updatePromises.add(
          updateFavoritePositionUseCase(fav.userId, fav.stationId, i).then(
            (result) => result.fold(
              (failure) {
                print(
                  'Failed to update position for ${fav.stationId}: ${failure.message}',
                );
              },
              (_) {
                // Success, nothing to do
              },
            ),
          ),
        );
      }

      // Wait for all updates to complete
      await Future.wait(updatePromises);
    } catch (e) {
      _setError('Failed to reorder favorites: ${e.toString()}');
      // Refresh the list from database to ensure consistency
      if (_favorites.isNotEmpty) {
        loadFavorites(_favorites.first.userId);
      }
    } finally {
      _isProcessing = false;
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

      // If not in cache, check database
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

  /// Update favorite name
  Future<bool> updateFavoriteName(
    String userId,
    String stationId,
    String newName,
  ) async {
    if (_isProcessing) return false;

    try {
      _isProcessing = true;

      // Find the favorite to update
      final favoriteIndex = _favorites.indexWhere(
        (f) => f.stationId == stationId && f.userId == userId,
      );

      if (favoriteIndex < 0) {
        return false; // Not found
      }

      // Get the favorite
      final favorite = _favorites[favoriteIndex];

      // Create updated favorite
      final updatedFavorite = FavoriteModel(
        stationId: favorite.stationId,
        name: newName,
        userId: favorite.userId,
        position: favorite.position,
        color: favorite.color,
        description: favorite.description,
        imgNumber: favorite.imgNumber,
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
      );

      // Update in database (we'll reuse the add method with replace conflict strategy)
      final result = await addFavoriteUseCase(updatedFavorite);

      return result.fold(
        (failure) {
          _setError(failure.message);
          return false;
        },
        (_) {
          // Update local list
          _favorites[favoriteIndex] = updatedFavorite;
          notifyListeners();
          return true;
        },
      );
    } catch (e) {
      _setError('Failed to update favorite name: ${e.toString()}');
      return false;
    } finally {
      _isProcessing = false;
    }
  }

  // Helper to sort favorites by position
  void _sortFavoritesByPosition() {
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
    _errorMessage = message;
    _status = FavoritesStatus.error;
    // Use microtask to avoid setState during build
    Future.microtask(() {
      notifyListeners();
    });
  }

  // Clear error
  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }
}
