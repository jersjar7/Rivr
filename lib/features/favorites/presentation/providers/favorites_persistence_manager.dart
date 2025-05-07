// lib/features/favorites/presentation/providers/favorites_persistence_manager.dart

import 'dart:async';

import '../../domain/entities/favorite.dart';
import '../../data/models/favorite_model.dart';
import '../../../../features/map/domain/entities/map_station.dart';
import '../../../../core/services/offline_manager_service.dart';
import '../../../../core/network/network_info.dart';
import './favorites_provider.dart';

/// Manages persistence operations for favorites
class FavoritesPersistenceManager {
  // Reference to parent provider
  final FavoritesProvider parent;

  // Services for offline functionality
  final OfflineManagerService _offlineManager;
  final NetworkInfo _networkInfo;

  // Debounce timer to prevent rapid state changes
  Timer? _debounceTimer;

  // Fake station ID for storing favorites
  static const String _fakePendingOpsStationId = "12345678";

  FavoritesPersistenceManager({
    required this.parent,
    required OfflineManagerService offlineManager,
    required NetworkInfo networkInfo,
  }) : _offlineManager = offlineManager,
       _networkInfo = networkInfo;

  // Cache favorites for offline use
  Future<void> cacheFavorites(String userId, List<Favorite> favorites) async {
    try {
      final Map<String, dynamic> favoritesData = {
        'userId': userId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'favorites': favorites.map((f) => _favoriteToJson(f)).toList(),
      };

      // Create a fake "station" that contains our favorites data
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

  // Retrieve cached favorites from offline storage
  Future<List<Favorite>> getCachedFavorites(String userId) async {
    try {
      // Create the same fake station ID we used in cacheFavorites
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

          // Update last sync time
          if (apiData['timestamp'] != null) {
            final lastSyncTime = DateTime.fromMillisecondsSinceEpoch(
              apiData['timestamp'],
            );
            // We can't update parent's private _lastSyncTime directly,
            // but this is available when needed
          }

          return favorites;
        }
      }
    } catch (e) {
      print("Error retrieving cached favorites: $e");
    }
    return [];
  }

  // Store pending operations for later sync
  Future<void> addToPendingOperations(
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
      final fakeStation = MapStation(
        stationId: int.parse(_fakePendingOpsStationId),
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

  // Get pending operations from cache
  Future<List<Map<String, dynamic>>> _getPendingOperations() async {
    try {
      // Get cached data
      final cachedData = await _offlineManager.getCachedStation(
        int.parse(_fakePendingOpsStationId),
      );

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
    if (parent.isProcessing) return;

    // Check if we're online
    final bool isConnected = await _networkInfo.isConnected;
    if (!isConnected) return;

    try {
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
              final result = await parent.addFavoriteUseCase(
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
              final result = await parent.removeFavoriteUseCase(
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
              final result = await parent.addFavoriteUseCase(
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
            for (final fav in parent.favorites) {
              final result = await parent.updateFavoritePositionUseCase(
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
        final fakeStation = MapStation(
          stationId: int.parse(_fakePendingOpsStationId),
          name: 'pending_operations',
          lat: 0,
          lon: 0,
        );

        await _offlineManager.cacheStation(fakeStation, {
          'operations': pendingOps,
        });
      }

      // Refresh favorites to ensure consistency
      if (parent.favorites.isNotEmpty && processedIndices.isNotEmpty) {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 300), () {
          parent.loadFavorites(parent.favorites.first.userId);
        });
      }

      // Only notify if there were actual changes
      if (processedIndices.isNotEmpty) {
        parent.notifyListeners();
      }
    } catch (e) {
      print("Error syncing pending operations: $e");
    }
  }

  // Check for connectivity and try to sync if needed
  Future<void> checkConnectionAndSync() async {
    // Prevent redundant connection checks
    if (parent.isProcessing) return;

    final bool isConnected = await _networkInfo.isConnected;
    final bool wasUsingOfflineData = parent.isUsingOfflineData;

    if (isConnected && wasUsingOfflineData) {
      // We just got back online after using offline data
      await syncPendingOperations();

      // Refresh favorites
      if (parent.favorites.isNotEmpty) {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 300), () {
          parent.loadFavorites(parent.favorites.first.userId);
        });
      }
    }
  }

  // Helper methods for connectivity checks
  Future<bool> isConnected() async {
    return await _networkInfo.isConnected;
  }

  Future<bool> isOfflineMode() async {
    return _offlineManager.offlineModeEnabled;
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
      'customImagePath': favorite.customImagePath,
    };

    // Only add originalApiName if it's not null and not "null"
    if (favorite.originalApiName != null &&
        favorite.originalApiName != "null") {
      json['originalApiName'] = favorite.originalApiName;
    }

    return json;
  }

  // Create Favorite from JSON
  Favorite _favoriteFromJson(Map<String, dynamic> json) {
    // Check if originalApiName is the string "null" and convert to actual null
    final originalApiName =
        json['originalApiName'] == "null" ? null : json['originalApiName'];

    return FavoriteModel(
      stationId: json['stationId'],
      name: json['name'],
      userId: json['userId'],
      position: json['position'],
      color: json['color'],
      description: json['description'],
      imgNumber: json['imgNumber'] ?? 1,
      lastUpdated: json['lastUpdated'],
      originalApiName: originalApiName,
      customImagePath: json['customImagePath'],
    );
  }

  // Clean up resources
  void dispose() {
    _debounceTimer?.cancel();
  }
}
