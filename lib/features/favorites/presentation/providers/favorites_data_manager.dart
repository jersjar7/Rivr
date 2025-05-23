// lib/features/favorites/presentation/providers/favorites_data_manager.dart

import 'dart:math' as math;

import '../../data/models/favorite_model.dart';
import '../../domain/entities/favorite.dart';
import '../../../../common/data/local/database_helper.dart';
import '../../../../core/services/stream_name_service.dart';
import './favorites_provider.dart';

/// Manages data operations for favorites
class FavoritesDataManager {
  // Reference to parent provider
  final FavoritesProvider parent;

  // StreamNameService for centralized name management
  final StreamNameService _streamNameService;

  // Database helper
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  FavoritesDataManager({
    required this.parent,
    required StreamNameService streamNameService,
  }) : _streamNameService = streamNameService;

  // Initialize database tables
  Future<void> initTables() async {
    try {
      await _databaseHelper.createFavoritesTable();
    } catch (e) {
      print("ERROR in FavoritesDataManager: Failed to initialize tables: $e");
    }
  }

  // Add a favorite from a station
  Future<bool> addFavorite(
    String userId,
    String stationId, {
    String? displayName,
    String? description,
    String? originalApiName,
    double? lat,
    double? lon,
    double? elevation,
    String? city, // New parameters for location text
    String? state,
  }) async {
    print('DEBUG: DataManager.addFavorite called with:');
    print('DEBUG: lat=$lat, lon=$lon, city=$city, state=$state');

    if (parent.isProcessing) return false;

    try {
      // Check if already a favorite
      final isAlreadyFavorite = await parent.checkIsFavorite(userId, stationId);

      if (isAlreadyFavorite) {
        return true; // Already a favorite, no need to add again
      }

      // Get the next position
      final nextPosition = parent.favorites.length;

      // Generate a random image number
      final random = math.Random();
      final randomImgNumber = random.nextInt(96) + 1;

      // Get the proper name for this station
      String riverName = "";
      String? apiName = originalApiName;

      // If display name is provided, use it
      if (displayName != null && displayName.isNotEmpty) {
        riverName = displayName;
      }
      // Otherwise try to get it from the StreamNameService
      else {
        try {
          // This will get the display name from StreamNameService or default to 'Stream $stationId'
          riverName = await _streamNameService.getDisplayName(stationId);
        } catch (e) {
          print("Error getting name from StreamNameService: $e");
          riverName = "Stream $stationId"; // Default fallback
        }
      }

      // If we have a river name but no original API name, get it from StreamNameService
      if (apiName == null) {
        try {
          final nameInfo = await _streamNameService.getNameInfo(stationId);
          apiName = nameInfo.originalApiName;
        } catch (e) {
          print("Error getting original API name: $e");
          // If we can't get the original name, use the current name as a fallback
          apiName = riverName;
        }
      }

      // Create favorite model with location data and city/state
      final favorite = FavoriteModel(
        stationId: stationId,
        name: riverName,
        userId: userId,
        position: nextPosition,
        color: null, // Will be set from station if available
        description: description,
        imgNumber: randomImgNumber,
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
        originalApiName: apiName,
        lat: lat, // Store coordinates
        lon: lon,
        elevation: elevation,
        city: city, // Store city
        state: state, // Store state
      );

      print(
        'DEBUG: Created FavoriteModel with city=${favorite.city}, state=${favorite.state}',
      );

      // Update the name in StreamNameService for future consistency
      try {
        await _streamNameService.updateDisplayName(stationId, riverName);

        // Only set original API name if we have one and it's different from the display name
        if (apiName != null && apiName != riverName) {
          await _streamNameService.setOriginalApiName(stationId, apiName);
        }
      } catch (e) {
        print("Warning: Failed to update StreamNameService with new name: $e");
        // Continue anyway - the favorite will still be created
      }

      // Check connectivity
      final bool isConnected = await parent.persistenceManager.isConnected();
      final bool isOfflineMode =
          await parent.persistenceManager.isOfflineMode();

      if (!isConnected || isOfflineMode) {
        // In offline mode, add to local list and cache
        parent.favorites.add(favorite);
        parent.sortFavoritesByPosition();

        // Add to pending operations queue for later sync
        await parent.persistenceManager.addToPendingOperations('ADD', favorite);

        // Use notifyChanges method instead of direct access to notifyListeners
        parent.notifyChanges();
        return true;
      }

      // If online, add directly to repository
      final result = await parent.addFavoriteUseCase(favorite);

      return result.fold(
        (failure) {
          print("Failed to add favorite: ${failure.message}");
          return false;
        },
        (_) {
          // Add to local list
          parent.favorites.add(favorite);
          parent.sortFavoritesByPosition();

          // Cache the updated favorites list
          parent.persistenceManager.cacheFavorites(userId, parent.favorites);

          // Use notifyChanges method instead of direct access to notifyListeners
          parent.notifyChanges();
          return true;
        },
      );
    } catch (e) {
      print("Error in addFavorite: $e");
      return false;
    }
  }

  // Add an existing favorite (for undo operations)
  Future<void> addExistingFavorite(Favorite favorite) async {
    if (parent.isProcessing) return;

    try {
      // Update name in StreamNameService
      try {
        await _streamNameService.updateDisplayName(
          favorite.stationId,
          favorite.name,
        );

        if (favorite.originalApiName != null &&
            favorite.originalApiName != "null") {
          await _streamNameService.setOriginalApiName(
            favorite.stationId,
            favorite.originalApiName!,
          );
        }
      } catch (e) {
        print("Warning: Failed to update StreamNameService: $e");
      }

      // Convert to FavoriteModel if needed
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
                originalApiName: favorite.originalApiName,
                customImagePath: favorite.customImagePath,
                lat: favorite.lat,
                lon: favorite.lon,
                elevation: favorite.elevation,
                city: favorite.city,
                state: favorite.state,
              );

      // Check connectivity
      final bool isConnected = await parent.persistenceManager.isConnected();
      final bool isOfflineMode =
          await parent.persistenceManager.isOfflineMode();

      if (!isConnected || isOfflineMode) {
        // Offline mode - add to local list and pending operations
        parent.favorites.add(favoriteModel);
        parent.sortFavoritesByPosition();

        // Add to pending operations queue
        await parent.persistenceManager.addToPendingOperations(
          'ADD',
          favoriteModel,
        );

        // Use notifyChanges method instead of direct access to notifyListeners
        parent.notifyChanges();
        return;
      }

      // Online mode - add to repository
      final result = await parent.addFavoriteUseCase(favoriteModel);

      result.fold(
        (failure) {
          print("Failed to restore favorite: ${failure.message}");
        },
        (_) {
          parent.favorites.add(favoriteModel);
          parent.sortFavoritesByPosition();

          // Update cache
          parent.persistenceManager.cacheFavorites(
            favoriteModel.userId,
            parent.favorites,
          );

          // Use notifyChanges method instead of direct access to notifyListeners
          parent.notifyChanges();
        },
      );
    } catch (e) {
      print('Error adding existing favorite: $e');
    }
  }

  // Update favorite name
  Future<bool> updateFavoriteName(
    String userId,
    String stationId,
    String newName,
  ) async {
    print(
      "DEBUG: DataManager updateFavoriteName called for station $stationId with new name '$newName'",
    );

    try {
      // Find the favorite to update
      print("DEBUG: Looking for favorite in list");
      final favoriteIndex = parent.favorites.indexWhere(
        (f) => f.stationId == stationId && f.userId == userId,
      );
      print("DEBUG: Favorite index: $favoriteIndex");

      if (favoriteIndex < 0) {
        print("DEBUG: Favorite not found, returning false");
        return false; // Not found
      }

      // Get the favorite
      final favorite = parent.favorites[favoriteIndex];
      print(
        "DEBUG: Found favorite: ${favorite.stationId}, current name: '${favorite.name}'",
      );

      // IMPORTANT: Ensure we have an originalApiName before changing the name
      print(
        "DEBUG: Original API name from favorite: ${favorite.originalApiName}",
      );
      String? originalApiNameToUse = favorite.originalApiName;
      if (originalApiNameToUse == null ||
          originalApiNameToUse.isEmpty ||
          originalApiNameToUse == "null") {
        // Try to get from StreamNameService first
        try {
          print(
            "DEBUG: Trying to get original API name from StreamNameService",
          );
          final nameInfo = await _streamNameService.getNameInfo(stationId);
          originalApiNameToUse = nameInfo.originalApiName;
          print(
            "DEBUG: Got original API name from service: $originalApiNameToUse",
          );
        } catch (e) {
          print("Error getting original API name from service: $e");
        }

        // If still null, use current name
        if (originalApiNameToUse == null ||
            originalApiNameToUse.isEmpty ||
            originalApiNameToUse == "null") {
          originalApiNameToUse = favorite.name;
          print("DEBUG: Using current name as original: $originalApiNameToUse");
        }
      }

      // Create updated favorite - preserve original API name
      print("DEBUG: Creating updated favorite model");
      final updatedFavorite = FavoriteModel(
        stationId: favorite.stationId,
        name: newName,
        userId: favorite.userId,
        position: favorite.position,
        color: favorite.color,
        description: favorite.description,
        imgNumber: favorite.imgNumber,
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
        originalApiName: originalApiNameToUse,
        customImagePath: favorite.customImagePath,
        lat: favorite.lat,
        lon: favorite.lon,
        elevation: favorite.elevation,
        city: favorite.city,
        state: favorite.state,
      );
      print(
        "DEBUG: Created updated favorite: ${updatedFavorite.stationId}, name: '${updatedFavorite.name}', originalApiName: '${updatedFavorite.originalApiName}', customImagePath: '${updatedFavorite.customImagePath}'",
      );

      // Update local list first for responsive UI
      print("DEBUG: Updating favorite in local list");
      parent.favorites[favoriteIndex] = updatedFavorite;
      parent.notifyChanges();
      print("DEBUG: Local list updated and UI notified");

      // Always update StreamNameService
      try {
        print("DEBUG: Updating StreamNameService");
        await _streamNameService.updateDisplayName(stationId, newName);
        print("DEBUG: StreamNameService updated successfully");
      } catch (e) {
        print("Warning: Failed to update StreamNameService: $e");
      }

      // Check connectivity
      print("DEBUG: Checking connectivity");
      final bool isConnected = await parent.persistenceManager.isConnected();
      final bool isOfflineMode =
          await parent.persistenceManager.isOfflineMode();
      print("DEBUG: isConnected=$isConnected, isOfflineMode=$isOfflineMode");

      if (!isConnected || isOfflineMode) {
        print("DEBUG: Offline mode detected, using pending operations");
        // Offline mode - add to pending operations
        await parent.persistenceManager.addToPendingOperations(
          'UPDATE',
          updatedFavorite,
        );
        print("DEBUG: Added to pending operations");

        // Update cache
        parent.persistenceManager.cacheFavorites(userId, parent.favorites);
        print("DEBUG: Updated cache in offline mode");
        return true;
      }

      // Update in database
      print("DEBUG: Online mode - calling addFavoriteUseCase");
      final result = await parent.addFavoriteUseCase(updatedFavorite);
      print("DEBUG: Repository result: $result");

      final bool returnValue = result.fold(
        (failure) {
          print("DEBUG: Failure from repository: ${failure.message}");
          return false;
        },
        (_) {
          print("DEBUG: Success from repository");
          // Update cache
          parent.persistenceManager.cacheFavorites(userId, parent.favorites);
          print("DEBUG: Cache updated after successful repository update");
          return true;
        },
      );

      print("DEBUG: Final result of updateFavoriteName: $returnValue");
      return returnValue;
    } catch (e) {
      print('Error updating favorite name: $e');
      return false;
    }
  }

  // Update favorite image number
  Future<bool> updateFavoriteImage(
    String userId,
    String stationId,
    int imgNumber,
  ) async {
    print("🔥 DEBUG: FavoritesDataManager.updateFavoriteImage called!");
    print(
      "🔥 This method is missing location properties and will cause city/state to disappear!",
    );
    if (parent.isProcessing) return false;

    try {
      // Find the favorite to update
      final favoriteIndex = parent.favorites.indexWhere(
        (f) => f.stationId == stationId && f.userId == userId,
      );

      if (favoriteIndex < 0) {
        return false; // Not found
      }

      // Get the current favorite
      final favorite = parent.favorites[favoriteIndex];

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
        originalApiName: favorite.originalApiName,
        customImagePath: favorite.customImagePath,
        lat: favorite.lat,
        lon: favorite.lon,
        elevation: favorite.elevation,
        city: favorite.city,
        state: favorite.state,
      );

      // Update local list first for responsive UI
      parent.favorites[favoriteIndex] = updatedFavorite;
      parent.notifyChanges();

      // Check connectivity
      final bool isConnected = await parent.persistenceManager.isConnected();
      final bool isOfflineMode =
          await parent.persistenceManager.isOfflineMode();

      if (!isConnected || isOfflineMode) {
        // Offline mode - add to pending operations
        await parent.persistenceManager.addToPendingOperations(
          'UPDATE',
          updatedFavorite,
        );

        // Update cache
        parent.persistenceManager.cacheFavorites(userId, parent.favorites);
        return true;
      }

      // Update in database
      final result = await parent.addFavoriteUseCase(updatedFavorite);

      return result.fold(
        (failure) {
          print("Failed to update favorite image: ${failure.message}");
          return false;
        },
        (_) {
          // Update cache
          parent.persistenceManager.cacheFavorites(userId, parent.favorites);
          return true;
        },
      );
    } catch (e) {
      print('Error updating favorite image: $e');
      return false;
    }
  }

  // Update custom image path
  Future<bool> updateFavoriteCustomImage(
    String userId,
    String stationId,
    String customImagePath,
  ) async {
    if (parent.isProcessing) return false;

    try {
      // Find the favorite to update
      final favoriteIndex = parent.favorites.indexWhere(
        (f) => f.stationId == stationId && f.userId == userId,
      );

      if (favoriteIndex < 0) {
        return false; // Not found
      }

      // Get the current favorite
      final favorite = parent.favorites[favoriteIndex];

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
        lat: favorite.lat,
        lon: favorite.lon,
        elevation: favorite.elevation,
        city: favorite.city,
        state: favorite.state,
      );

      // Update local list first for responsive UI
      parent.favorites[favoriteIndex] = updatedFavorite;
      parent.notifyChanges();

      // Check connectivity
      final bool isConnected = await parent.persistenceManager.isConnected();
      final bool isOfflineMode =
          await parent.persistenceManager.isOfflineMode();

      if (!isConnected || isOfflineMode) {
        // Offline mode - add to pending operations
        await parent.persistenceManager.addToPendingOperations(
          'UPDATE',
          updatedFavorite,
        );

        // Update cache
        parent.persistenceManager.cacheFavorites(userId, parent.favorites);
        return true;
      }

      // Update in database
      final result = await parent.addFavoriteUseCase(updatedFavorite);

      return result.fold(
        (failure) {
          print("Failed to update custom image: ${failure.message}");
          return false;
        },
        (_) {
          // Update cache
          parent.persistenceManager.cacheFavorites(userId, parent.favorites);
          return true;
        },
      );
    } catch (e) {
      print('Error updating custom image: $e');
      return false;
    }
  }

  // Fixed reorderFavorites method for FavoritesDataManager class
  Future<void> reorderFavorites(int oldIndex, int newIndex) async {
    print(
      "DEBUG: Starting reorderFavorites in DataManager with oldIndex=$oldIndex, newIndex=$newIndex",
    );
    print(
      "DEBUG: Favorites list types before reordering: ${parent.favorites.map((f) => f.runtimeType).toList()}",
    );
    print("DEBUG: Favorites list length: ${parent.favorites.length}");

    if (parent.isProcessing ||
        oldIndex < 0 ||
        newIndex < 0 ||
        oldIndex >= parent.favorites.length) {
      print("DEBUG: Early return due to invalid state or indices");
      return;
    }

    try {
      // Adjust indices for list operations
      if (oldIndex < newIndex) {
        newIndex -= 1;
        print("DEBUG: Adjusted newIndex to $newIndex");
      }

      // Update the local list first for responsive UI
      final favorite = parent.favorites.removeAt(oldIndex);
      print(
        "DEBUG: Removed favorite type: ${favorite.runtimeType}, id: ${favorite.stationId}",
      );
      parent.favorites.insert(newIndex, favorite);
      parent.notifyChanges();
      print(
        "DEBUG: Favorites list after reordering: ${parent.favorites.map((f) => f.runtimeType).toList()}",
      );

      // Update positions in local list
      print("DEBUG: Creating updatedFavorites list");
      // Use a properly typed list
      final List<FavoriteModel> updatedFavorites = [];
      for (int i = 0; i < parent.favorites.length; i++) {
        final fav = parent.favorites[i];
        print(
          "DEBUG: Processing favorite at index $i, type: ${fav.runtimeType}, id: ${fav.stationId}",
        );

        // FIXED: Always create a new FavoriteModel regardless of source type
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
            originalApiName: fav.originalApiName,
            customImagePath: fav.customImagePath,
            lat: fav.lat,
            lon: fav.lon,
            elevation: fav.elevation,
            city: fav.city,
            state: fav.state,
          ),
        );
      }
      print(
        "DEBUG: updatedFavorites types: ${updatedFavorites.map((f) => f.runtimeType).toList()}",
      );
      print("DEBUG: updatedFavorites length: ${updatedFavorites.length}");

      // Replace the favorites list with the updated one
      print("DEBUG: Clearing parent.favorites");
      parent.favorites.clear();
      print("DEBUG: Adding updatedFavorites to parent.favorites");
      parent.favorites.addAll(updatedFavorites);
      print(
        "DEBUG: parent.favorites after updating: ${parent.favorites.map((f) => f.runtimeType).toList()}",
      );
      print(
        "DEBUG: parent.favorites length after updating: ${parent.favorites.length}",
      );

      // Check connectivity
      print("DEBUG: Checking connectivity");
      final bool isConnected = await parent.persistenceManager.isConnected();
      final bool isOfflineMode =
          await parent.persistenceManager.isOfflineMode();
      print("DEBUG: isConnected=$isConnected, isOfflineMode=$isOfflineMode");

      if (!isConnected || isOfflineMode) {
        print("DEBUG: In offline mode branch");
        // Offline mode - add to pending operations
        print("DEBUG: About to add to pending operations");
        await parent.persistenceManager.addToPendingOperations('REORDER', null);
        print("DEBUG: Added to pending operations");

        // Update cache with new positions
        if (parent.favorites.isNotEmpty) {
          print(
            "DEBUG: About to convert favorites for cacheFavorites in offline mode",
          );
          print(
            "DEBUG: parent.favorites types: ${parent.favorites.map((f) => f.runtimeType).toList()}",
          );
          print("DEBUG: parent.favorites length: ${parent.favorites.length}");

          // Since we've already ensured parent.favorites contains only FavoriteModels,
          // we can pass it directly to cacheFavorites
          print(
            "DEBUG: About to call cacheFavorites with userId=${parent.favorites.first.userId}",
          );

          try {
            await parent.persistenceManager.cacheFavorites(
              parent.favorites.first.userId,
              parent.favorites, // Now guaranteed to be a List<FavoriteModel>
            );
            print(
              "DEBUG: cacheFavorites completed successfully in offline mode",
            );
          } catch (e) {
            print("DEBUG: Error in cacheFavorites offline call: $e");
            print("DEBUG: Error stack trace: ${StackTrace.current}");
          }
        }
        return;
      }

      // Online mode - update positions in database with fewer UI updates
      print("DEBUG: In online mode branch");
      // Group operations to reduce notifications
      final updatePromises = <Future<void>>[];
      for (int i = 0; i < parent.favorites.length; i++) {
        final fav = parent.favorites[i];
        print(
          "DEBUG: Adding updateFavoritePosition promise for ${fav.stationId}, position $i",
        );
        updatePromises.add(
          parent
              .updateFavoritePositionUseCase(fav.userId, fav.stationId, i)
              .then(
                (result) => result.fold(
                  (failure) {
                    print(
                      'DEBUG: Failed to update position for ${fav.stationId}: ${failure.message}',
                    );
                  },
                  (_) {
                    print(
                      "DEBUG: Successfully updated position for ${fav.stationId}",
                    );
                  },
                ),
              ),
        );
      }

      // Wait for all updates to complete
      print("DEBUG: Waiting for all update promises");
      await Future.wait(updatePromises);
      print("DEBUG: All updates completed");

      // Update cache - again, parent.favorites is now guaranteed to be List<FavoriteModel>
      if (parent.favorites.isNotEmpty) {
        print("DEBUG: About to call cacheFavorites in online mode");
        print(
          "DEBUG: parent.favorites types: ${parent.favorites.map((f) => f.runtimeType).toList()}",
        );

        try {
          await parent.persistenceManager.cacheFavorites(
            parent.favorites.first.userId,
            parent.favorites, // Now guaranteed to be a List<FavoriteModel>
          );
          print("DEBUG: cacheFavorites completed successfully in online mode");
        } catch (e) {
          print("DEBUG: Error in cacheFavorites online call: $e");
          print("DEBUG: Error stack trace: ${StackTrace.current}");
        }
      }
    } catch (e) {
      print('DEBUG: Error reordering favorites: $e');
      print('DEBUG: Stack trace: ${StackTrace.current}');

      // Refresh the list from database to ensure consistency
      if (parent.favorites.isNotEmpty) {
        print("DEBUG: Reloading favorites after error");
        parent.loadFavorites(parent.favorites.first.userId);
      }
    }
  }
}
