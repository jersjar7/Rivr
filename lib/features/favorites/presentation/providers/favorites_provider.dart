// lib/features/favorites/presentation/providers/favorites_provider.dart

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../domain/entities/favorite.dart';
import '../../data/models/favorite_model.dart';
import '../../domain/usecases/add_favorite.dart';
import '../../domain/usecases/get_favorites.dart';
import '../../domain/usecases/is_favorite.dart';
import '../../domain/usecases/remove_favorite.dart';
import '../../domain/usecases/update_favorite_position.dart';
import '../../../../features/map/domain/entities/map_station.dart';
import '../../../../common/data/local/database_helper.dart';
import '../../../../core/services/offline_manager_service.dart';
import '../../../../core/network/network_info.dart';

enum FavoritesStatus { initial, loading, loaded, error, noConnection }

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

  // State
  FavoritesStatus _status = FavoritesStatus.initial;
  List<Favorite> _favorites = [];
  String? _errorMessage;
  bool _isProcessing = false;
  bool _isUsingOfflineData = false;
  DateTime? _lastSyncTime;

  // Recently deleted favorites for undo functionality
  final Map<String, Favorite> _recentlyDeleted = {};

  // Database helper
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  // Debounce timer to prevent rapid state changes
  Timer? _debounceTimer;

  // Flag to avoid redundant operations
  bool _isRefreshingFavorites = false;

  // Getters
  FavoritesStatus get status => _status;
  List<Favorite> get favorites => _favorites;
  String? get errorMessage => _errorMessage;
  bool get isProcessing => _isProcessing;
  bool get isUsingOfflineData => _isUsingOfflineData;
  DateTime? get lastSyncTime => _lastSyncTime;

  FavoritesProvider({
    required GetFavorites getFavorites,
    required AddFavorite addFavorite,
    required RemoveFavorite removeFavorite,
    required UpdateFavoritePosition updateFavoritePosition,
    required IsFavorite isFavorite,
    required OfflineManagerService offlineManager,
    required NetworkInfo networkInfo,
  }) : getFavoritesUseCase = getFavorites,
       addFavoriteUseCase = addFavorite,
       removeFavoriteUseCase = removeFavorite,
       updateFavoritePositionUseCase = updateFavoritePosition,
       isFavoriteUseCase = isFavorite,
       _offlineManager = offlineManager,
       _networkInfo = networkInfo {
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

  // Load favorites for user with offline handling
  Future<void> loadFavorites(String userId) async {
    // Prevent multiple simultaneous loads and redundant operations
    if (_isProcessing || _isRefreshingFavorites) return;

    try {
      _isProcessing = true;
      _isRefreshingFavorites = true;

      // Only update status if changing from non-loading state
      if (_status != FavoritesStatus.loading) {
        _setStatus(FavoritesStatus.loading);
      }

      // Ensure favorites table exists
      await _databaseHelper.createFavoritesTable();

      // Check network connectivity and offline mode
      final bool isConnected = await _networkInfo.isConnected;
      final bool isOfflineMode = _offlineManager.offlineModeEnabled;

      // If offline mode is enabled or there's no connection, try to use cached data
      if (isOfflineMode || !isConnected) {
        // Get cached favorites
        final cachedFavorites = await _getCachedFavorites(userId);
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
            _setStatus(FavoritesStatus.loaded);

            // Cache favorites for offline use - use debouncing
            _debounceTimer?.cancel();
            _debounceTimer = Timer(const Duration(milliseconds: 300), () {
              _cacheFavorites(userId, loadedFavorites);
            });
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
      _isRefreshingFavorites = false;
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

  // Cache favorites for offline use - compatible with OfflineManagerService
  Future<void> _cacheFavorites(String userId, List<Favorite> favorites) async {
    try {
      final Map<String, dynamic> favoritesData = {
        'userId': userId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'favorites': favorites.map((f) => _favoriteToJson(f)).toList(),
      };

      // Create a fake "station" that contains our favorites data
      // This is a workaround to use existing OfflineManagerService methods
      final fakeStationId = int.parse(
        userId.hashCode.toString().replaceAll('-', '').substring(0, 8),
      );

      // Use cacheStation method which is available in OfflineManagerService
      final MapStation fakeStation = MapStation(
        stationId: fakeStationId,
        name: 'favorites_store',
        lat: 0,
        lon: 0,
      );

      // Store our favorites data in the apiData parameter
      await _offlineManager.cacheStation(fakeStation, favoritesData);
    } catch (e) {
      print("Error caching favorites: $e");
      // Non-critical error, don't disrupt the UI
    }
  }

  // Retrieve cached favorites - compatible with OfflineManagerService
  Future<List<Favorite>> _getCachedFavorites(String userId) async {
    try {
      // Create the same fake station ID we used in _cacheFavorites
      final fakeStationId = int.parse(
        userId.hashCode.toString().replaceAll('-', '').substring(0, 8),
      );

      // Use getCachedStation method which is available in OfflineManagerService
      final cachedData = await _offlineManager.getCachedStation(fakeStationId);

      if (cachedData != null && cachedData['apiData'] != null) {
        final apiData = cachedData['apiData'];

        if (apiData is Map<String, dynamic> && apiData['favorites'] != null) {
          final List<dynamic> favoritesJson = apiData['favorites'];
          final List<Favorite> favorites =
              favoritesJson.map((json) => _favoriteFromJson(json)).toList();

          // Get cache timestamp
          if (apiData['timestamp'] != null) {
            _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(
              apiData['timestamp'],
            );
          }

          return favorites;
        }
      }
    } catch (e) {
      print("Error retrieving cached favorites: $e");
    }
    return [];
  }

  void updateFavoriteDirectly(int index, Favorite updatedFavorite) {
    if (index >= 0 && index < _favorites.length) {
      _favorites[index] = updatedFavorite;
      notifyListeners(); // This will refresh the UI immediately
    }
  }

  // Convert Favorite to JSON
  Map<String, dynamic> _favoriteToJson(Favorite favorite) {
    final json = {
      'stationId': favorite.stationId,
      'name': favorite.name,
      'userId': favorite.userId,
      'position': favorite.position,
      'color': favorite.color,
      'description': favorite.description,
      'imgNumber': favorite.imgNumber,
      'lastUpdated': favorite.lastUpdated,
      'originalApiName':
          favorite.originalApiName, // Make sure this field is included
    };

    print(
      "_favoriteToJson DEBUG: name='${favorite.name}', saving originalApiName=${favorite.originalApiName}",
    );
    return json;
  }

  // Create Favorite from JSON
  Favorite _favoriteFromJson(Map<String, dynamic> json) {
    final favorite = FavoriteModel(
      stationId: json['stationId'],
      name: json['name'],
      userId: json['userId'],
      position: json['position'],
      color: json['color'],
      description: json['description'],
      imgNumber: json['imgNumber'] ?? 1,
      lastUpdated: json['lastUpdated'],
      originalApiName: json['originalApiName'], // Make sure to read this field
    );

    print(
      "_favoriteFromJson DEBUG: deserializing - name='${favorite.name}', originalApiName='${favorite.originalApiName}'",
    );
    return favorite;
  }

  // Add a new favorite from a MapStation with offline awareness
  Future<bool> addFavoriteFromStation(
    String userId,
    MapStation station, {
    String? displayName,
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

      // Determine station name with priority to displayName
      String riverName;
      String? originalApiName;

      if (displayName != null && displayName.isNotEmpty) {
        riverName = displayName;
      } else {
        // Try to get name from offline cache
        riverName = ""; // Default fallback
        try {
          // Check cached station data
          final cachedStation = await _offlineManager.getCachedStation(
            station.stationId,
          );

          if (cachedStation != null && cachedStation['apiData'] != null) {
            final apiData = cachedStation['apiData'];
            if (apiData is Map<String, dynamic> &&
                apiData.containsKey('name') &&
                apiData['name'] != null &&
                apiData['name'].toString().isNotEmpty) {
              riverName = apiData['name'].toString();
              originalApiName = riverName; // Store the API name
              print(
                "DEBUG NAME: Got name '$riverName' from cached station data",
              );
            }
          }

          // Check if station has name from another source
          if (station.name != null && station.name!.isNotEmpty) {
            riverName = station.name!;
            if (originalApiName == null) {
              originalApiName = station.name!;
              print(
                "DEBUG NAME: Using station.name as originalApiName: $originalApiName",
              );
            }
          }
        } catch (e) {
          print("Error getting proper station name: $e");
        }
      }

      // If we have a name but no original API name, set the original to the current name
      if (riverName.isNotEmpty && originalApiName == null) {
        originalApiName = riverName;
        print(
          "DEBUG NAME: Setting originalApiName to current riverName: $originalApiName",
        );
      }

      print(
        "DEBUG NAME: Final values - riverName: '$riverName', originalApiName: '$originalApiName'",
      );

      // Create favorite model
      final favorite = FavoriteModel(
        stationId: station.stationId.toString(),
        name: riverName,
        userId: userId,
        position: nextPosition,
        color: station.color,
        description: description,
        imgNumber: randomImgNumber,
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
        originalApiName: originalApiName, // Store the original API name
      );

      print(
        "addFavoriteFromStation: New favorite - stationId=${station.stationId}, name='$riverName', originalApiName='$originalApiName'",
      );

      print(
        "Created favorite object: ${favorite.stationId}, position: ${favorite.position}, name: ${favorite.name}, originalApiName: ${favorite.originalApiName}",
      );

      // Rest of the method remains unchanged...

      // Check if we're online or offline
      final bool isConnected = await _networkInfo.isConnected;
      final bool isOfflineMode = _offlineManager.offlineModeEnabled;

      if (!isConnected || isOfflineMode) {
        // In offline mode, add to local list and cache
        _favorites.add(favorite);
        _sortFavoritesByPosition();

        // Add to pending operations queue for later sync
        await _addToPendingOperations('ADD', favorite);

        notifyListeners();
        return true;
      }

      // If online, add directly to repository
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

          // Cache the updated favorites list - with debouncing
          _debounceTimer?.cancel();
          _debounceTimer = Timer(const Duration(milliseconds: 300), () {
            _cacheFavorites(userId, _favorites);
          });

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

      // Convert favorite to FavoriteModel if needed
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

      // Check connectivity before proceeding
      final bool isConnected = await _networkInfo.isConnected;
      final bool isOfflineMode = _offlineManager.offlineModeEnabled;

      if (!isConnected || isOfflineMode) {
        // Offline mode - add to local list and pending operations
        _favorites.add(favoriteModel);
        _sortFavoritesByPosition();

        // Add to pending operations queue
        await _addToPendingOperations('ADD', favoriteModel);

        notifyListeners();
        return;
      }

      // Online mode - add to repository
      final result = await addFavoriteUseCase(favoriteModel);

      result.fold(
        (failure) {
          _setError(failure.message);
        },
        (_) {
          _favorites.add(favoriteModel);
          _sortFavoritesByPosition();

          // Update cache - with debouncing
          _debounceTimer?.cancel();
          _debounceTimer = Timer(const Duration(milliseconds: 300), () {
            _cacheFavorites(favoriteModel.userId, _favorites);
          });

          notifyListeners();
        },
      );
    } catch (e) {
      _setError('Failed to add favorite: ${e.toString()}');
    } finally {
      _isProcessing = false;
    }
  }

  // Remove a favorite with offline awareness
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
        await _addToPendingOperations('DELETE', deletedFavorite);

        // Update cached favorites - with debouncing
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 300), () {
          _cacheFavorites(userId, _favorites);
        });

        // Clean up the recently deleted after some time
        Future.delayed(const Duration(minutes: 5), () {
          _recentlyDeleted.remove(stationId);
        });

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
          // Update cache - with debouncing
          _debounceTimer?.cancel();
          _debounceTimer = Timer(const Duration(milliseconds: 300), () {
            _cacheFavorites(userId, _favorites);
          });

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

  // Undo a recent deletion with offline awareness
  Future<void> undoDelete(String stationId) async {
    if (!_recentlyDeleted.containsKey(stationId)) {
      return; // Nothing to undo
    }

    final favorite = _recentlyDeleted.remove(stationId);
    if (favorite != null) {
      await addNewFavorite(favorite);
    }
  }

  // Reorder favorites with offline awareness
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

      // Check connectivity
      final bool isConnected = await _networkInfo.isConnected;
      final bool isOfflineMode = _offlineManager.offlineModeEnabled;

      // Update positions in local list
      // We need to create new model instances with updated positions since position is final
      final updatedFavorites = <Favorite>[];
      for (int i = 0; i < _favorites.length; i++) {
        final fav = _favorites[i];
        if (fav is FavoriteModel) {
          // Create a new model with the updated position
          updatedFavorites.add(
            FavoriteModel(
              stationId: fav.stationId,
              name: fav.name,
              userId: fav.userId,
              position: i, // Update position
              color: fav.color,
              description: fav.description,
              imgNumber: fav.imgNumber,
              lastUpdated: fav.lastUpdated,
            ),
          );
        } else {
          // Add original with potentially wrong position, will be fixed when synced
          updatedFavorites.add(fav);
        }
      }

      // Replace the favorites list with the updated one
      _favorites = updatedFavorites;

      if (!isConnected || isOfflineMode) {
        // Offline mode - add to pending operations
        await _addToPendingOperations('REORDER', null);

        // Update cache with new positions - with debouncing
        if (_favorites.isNotEmpty) {
          _debounceTimer?.cancel();
          _debounceTimer = Timer(const Duration(milliseconds: 300), () {
            _cacheFavorites(_favorites.first.userId, _favorites);
          });
        }

        return;
      }

      // Online mode - update positions in database with fewer UI updates
      // Group operations to reduce notifications
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

      // Update cache - with debouncing
      if (_favorites.isNotEmpty) {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 300), () {
          _cacheFavorites(_favorites.first.userId, _favorites);
        });
      }
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

  // Check if a station is favorited with offline awareness
  Future<bool> checkIsFavorite(String userId, String stationId) async {
    try {
      // First check the local cache
      final isCached = _favorites.any(
        (f) => f.stationId == stationId && f.userId == userId,
      );

      if (isCached) {
        return true;
      }

      // Check connectivity - use a single combined check to reduce overhead
      final isConnected = await _networkInfo.isConnected;
      final isOfflineMode = _offlineManager.offlineModeEnabled;
      final useOfflineMode = !isConnected || isOfflineMode;

      if (useOfflineMode) {
        // In offline mode, if not in local list, check offline cache
        final cachedFavorites = await _getCachedFavorites(userId);
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

  // Update favorite name with offline awareness
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

      print(
        "updateFavoriteName: BEFORE update - stationId=$stationId, name='${favorite.name}', originalApiName='${favorite.originalApiName}'",
      );

      // Create updated favorite - preserve original API name
      final updatedFavorite = FavoriteModel(
        stationId: favorite.stationId,
        name: newName,
        userId: favorite.userId,
        position: favorite.position,
        color: favorite.color,
        description: favorite.description,
        imgNumber: favorite.imgNumber,
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
        originalApiName:
            favorite
                .originalApiName, // IMPORTANT: Preserve the original API name
      );

      print(
        "updateFavoriteName: AFTER update - stationId=$stationId, name='$newName', originalApiName='${updatedFavorite.originalApiName}'",
      );

      // Update local list first for responsive UI
      _favorites[favoriteIndex] = updatedFavorite;
      notifyListeners();

      // Check connectivity
      final bool isConnected = await _networkInfo.isConnected;
      final bool isOfflineMode = _offlineManager.offlineModeEnabled;

      if (!isConnected || isOfflineMode) {
        // Offline mode - add to pending operations
        await _addToPendingOperations('UPDATE', updatedFavorite);

        // Update cache - with debouncing
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 300), () {
          _cacheFavorites(userId, _favorites);
        });

        return true;
      }

      // Update in database
      final result = await addFavoriteUseCase(updatedFavorite);

      return result.fold(
        (failure) {
          _setError(failure.message);
          return false;
        },
        (_) {
          // Update cache - with debouncing
          _debounceTimer?.cancel();
          _debounceTimer = Timer(const Duration(milliseconds: 300), () {
            _cacheFavorites(userId, _favorites);
          });
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

  Future<bool> updateFavoriteImage(
    String userId,
    String stationId,
    int imgNumber,
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

      // Get the current favorite
      final favorite = _favorites[favoriteIndex];

      // Create updated favorite with new image number
      final updatedFavorite = FavoriteModel(
        stationId: favorite.stationId,
        name: favorite.name,
        userId: favorite.userId,
        position: favorite.position,
        color: favorite.color,
        description: favorite.description,
        imgNumber: imgNumber, // Update the image number
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
        originalApiName:
            favorite.originalApiName, // Preserve the original API name
      );

      // Update local list first for responsive UI
      _favorites[favoriteIndex] = updatedFavorite;
      notifyListeners();

      // Check connectivity
      final bool isConnected = await _networkInfo.isConnected;
      final bool isOfflineMode = _offlineManager.offlineModeEnabled;

      if (!isConnected || isOfflineMode) {
        // Offline mode - add to pending operations
        await _addToPendingOperations('UPDATE', updatedFavorite);

        // Update cache - with debouncing
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 300), () {
          _cacheFavorites(userId, _favorites);
        });

        return true;
      }

      // Update in database
      final result = await addFavoriteUseCase(updatedFavorite);

      return result.fold(
        (failure) {
          _setError(failure.message);
          return false;
        },
        (_) {
          // Update cache - with debouncing
          _debounceTimer?.cancel();
          _debounceTimer = Timer(const Duration(milliseconds: 300), () {
            _cacheFavorites(userId, _favorites);
          });
          return true;
        },
      );
    } catch (e) {
      _setError('Failed to update favorite image: ${e.toString()}');
      return false;
    } finally {
      _isProcessing = false;
    }
  }

  Future<bool> updateFavoriteCustomImage(
    String userId,
    String stationId,
    String customImagePath,
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

      // Get the current favorite
      final favorite = _favorites[favoriteIndex];

      // Create updated favorite with new custom image path
      final updatedFavorite = FavoriteModel(
        stationId: favorite.stationId,
        name: favorite.name,
        userId: favorite.userId,
        position: favorite.position,
        color: favorite.color,
        description: favorite.description,
        imgNumber: favorite.imgNumber,
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
        originalApiName: favorite.originalApiName,
        customImagePath: customImagePath, // Update the custom image path
      );

      // Update local list first for responsive UI
      _favorites[favoriteIndex] = updatedFavorite;
      notifyListeners();

      // Check connectivity
      final bool isConnected = await _networkInfo.isConnected;
      final bool isOfflineMode = _offlineManager.offlineModeEnabled;

      if (!isConnected || isOfflineMode) {
        // Offline mode - add to pending operations
        await _addToPendingOperations('UPDATE', updatedFavorite);

        // Update cache - with debouncing
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 300), () {
          _cacheFavorites(userId, _favorites);
        });

        return true;
      }

      // Update in database
      final result = await addFavoriteUseCase(updatedFavorite);

      return result.fold(
        (failure) {
          _setError(failure.message);
          return false;
        },
        (_) {
          // Update cache - with debouncing
          _debounceTimer?.cancel();
          _debounceTimer = Timer(const Duration(milliseconds: 300), () {
            _cacheFavorites(userId, _favorites);
          });
          return true;
        },
      );
    } catch (e) {
      _setError('Failed to update custom image: ${e.toString()}');
      return false;
    } finally {
      _isProcessing = false;
    }
  }

  // Store pending operations for later sync - compatible with OfflineManagerService
  Future<void> _addToPendingOperations(
    String operation,
    Favorite? favorite,
  ) async {
    try {
      final List<Map<String, dynamic>> pendingOps =
          await _getPendingOperations();

      pendingOps.add({
        'operation': operation,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'favorite': favorite != null ? _favoriteToJson(favorite) : null,
      });

      // Create a fake station to store pending operations
      final fakeStationId = int.parse(
        "12345678",
      ); // Use consistent ID for pending ops
      final fakeStation = MapStation(
        stationId: fakeStationId,
        name: 'pending_operations',
        lat: 0,
        lon: 0,
      );

      // Cache the pending operations
      await _offlineManager.cacheStation(fakeStation, {
        'operations': pendingOps,
      });
    } catch (e) {
      print("Error adding to pending operations: $e");
    }
  }

  // Get pending operations - compatible with OfflineManagerService
  Future<List<Map<String, dynamic>>> _getPendingOperations() async {
    try {
      // Use consistent ID for pending operations
      final fakeStationId = int.parse("12345678");

      // Get cached data
      final cachedData = await _offlineManager.getCachedStation(fakeStationId);

      if (cachedData != null &&
          cachedData['apiData'] != null &&
          cachedData['apiData']['operations'] != null) {
        return List<Map<String, dynamic>>.from(
          cachedData['apiData']['operations'],
        );
      }
    } catch (e) {
      print("Error getting pending operations: $e");
    }

    return [];
  }

  // Sync pending operations when back online
  Future<void> syncPendingOperations() async {
    if (_isProcessing) return;

    // Check if we're online
    final bool isConnected = await _networkInfo.isConnected;
    if (!isConnected) return;

    try {
      _isProcessing = true;
      final pendingOps = await _getPendingOperations();

      if (pendingOps.isEmpty) {
        // Nothing to sync
        return;
      }

      // Sort by timestamp to process in order
      pendingOps.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));

      // Track successfully processed operations to remove later
      final List<int> processedIndices = [];

      for (int i = 0; i < pendingOps.length; i++) {
        final op = pendingOps[i];
        final operation = op['operation'];

        switch (operation) {
          case 'ADD':
            if (op['favorite'] != null) {
              final favorite = _favoriteFromJson(op['favorite']);
              final result = await addFavoriteUseCase(
                favorite as FavoriteModel,
              );

              if (result.isRight()) {
                processedIndices.add(i);
              }
            }
            break;

          case 'DELETE':
            if (op['favorite'] != null) {
              final favorite = _favoriteFromJson(op['favorite']);
              final result = await removeFavoriteUseCase(
                favorite.userId,
                favorite.stationId,
              );

              if (result.isRight()) {
                processedIndices.add(i);
              }
            }
            break;

          case 'UPDATE':
            if (op['favorite'] != null) {
              final favorite = _favoriteFromJson(op['favorite']);
              final result = await addFavoriteUseCase(
                favorite as FavoriteModel,
              );

              if (result.isRight()) {
                processedIndices.add(i);
              }
            }
            break;

          case 'REORDER':
            // For reorder, we need to update all positions
            bool success = true;
            for (final fav in _favorites) {
              final result = await updateFavoritePositionUseCase(
                fav.userId,
                fav.stationId,
                fav.position,
              );

              if (result.isLeft()) {
                success = false;
                break;
              }
            }

            if (success) {
              processedIndices.add(i);
            }
            break;
        }
      }

      // Remove processed operations
      if (processedIndices.isNotEmpty) {
        // Process in reverse order to avoid index shifting
        processedIndices.sort((a, b) => b.compareTo(a));

        for (final index in processedIndices) {
          pendingOps.removeAt(index);
        }

        // Update the pending operations cache
        final fakeStationId = int.parse("12345678");
        final fakeStation = MapStation(
          stationId: fakeStationId,
          name: 'pending_operations',
          lat: 0,
          lon: 0,
        );

        await _offlineManager.cacheStation(fakeStation, {
          'operations': pendingOps,
        });
      }

      // Refresh favorites to ensure consistency - but avoid redundant refreshes
      if (_favorites.isNotEmpty && processedIndices.isNotEmpty) {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 300), () {
          loadFavorites(_favorites.first.userId);
        });
      }

      _lastSyncTime = DateTime.now();
      _isUsingOfflineData = false;

      // Only notify if there were actual changes
      if (processedIndices.isNotEmpty) {
        notifyListeners();
      }
    } catch (e) {
      print("Error syncing pending operations: $e");
    } finally {
      _isProcessing = false;
    }
  }

  // Check for connectivity and try to sync if needed
  Future<void> checkConnectionAndSync() async {
    // Prevent redundant connection checks
    if (_isProcessing) return;

    final bool isConnected = await _networkInfo.isConnected;
    final bool wasUsingOfflineData = _isUsingOfflineData;

    if (isConnected && wasUsingOfflineData) {
      // We just got back online after using offline data
      await syncPendingOperations();

      // Refresh favorites - with debouncing
      if (_favorites.isNotEmpty) {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 300), () {
          loadFavorites(_favorites.first.userId);
        });
      }
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
    _debounceTimer?.cancel();
    super.dispose();
  }
}
