// lib/features/map/presentation/helpers/stream_info_helper.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rivr/common/data/remote/reach_service.dart';
import 'package:rivr/core/error/error_handler.dart';
import 'package:rivr/core/repositories/offline_storage_repository.dart';
import 'package:rivr/core/services/stream_name_service.dart';
import 'package:rivr/features/auth/presentation/providers/auth_provider.dart';
import 'package:rivr/features/favorites/presentation/providers/favorites_provider.dart';
import 'package:rivr/features/map/domain/entities/map_station.dart';
import 'package:rivr/features/map/presentation/widgets/dialogs/stream_name_dialog.dart';

/// Helper class for handling business logic related to stream information
class StreamInfoHelper {
  final StreamNameService _streamNameService;
  final OfflineStorageRepository _offlineStorage;

  StreamInfoHelper({
    required StreamNameService streamNameService,
    OfflineStorageRepository? offlineStorage,
  }) : _streamNameService = streamNameService,
       _offlineStorage = offlineStorage ?? OfflineStorageRepository();

  /// Fetch reach data from API or cache
  Future<Map<String, dynamic>?> fetchReachData(MapStation station) async {
    print("DEBUG START: fetchReachData for station ID: ${station.stationId}");

    // First check if we have cached data for this station
    try {
      print("DEBUG: Checking for cached data");
      final cachedData = await _offlineStorage.getCachedStation(
        station.stationId,
      );

      if (cachedData != null && cachedData['apiData'] != null) {
        print("DEBUG: Found cached data: ${cachedData['apiData']}");

        // Update the StreamNameService with the name from cache
        if (cachedData['apiData'] is Map &&
            cachedData['apiData']['name'] != null) {
          print("DEBUG: Cached name: ${cachedData['apiData']['name']}");
          await _streamNameService.setOriginalApiName(
            station.stationId.toString(),
            cachedData['apiData']['name'].toString(),
          );
        } else {
          print("DEBUG: No name found in cached data");
        }

        print("DEBUG: Using cached data");
        return cachedData['apiData'];
      } else {
        print("DEBUG: No cached data found or data is invalid");
      }
    } catch (e) {
      print("DEBUG ERROR: Error checking cached data: $e");
      // Continue to fetch from API if cache check fails
    }

    // Fetch fresh data from API
    try {
      print(
        "DEBUG: Fetching fresh data from API for station ID: ${station.stationId}",
      );
      final reachService = ReachService();
      final reachId = station.stationId.toString();

      final data = await reachService.fetchReach(reachId);
      print("DEBUG: API response received: $data");

      // Update the StreamNameService with the name from API
      if (data != null &&
          data is Map &&
          data['name'] != null &&
          data['name'].toString().isNotEmpty) {
        print("DEBUG: API returned name: ${data['name']}");
        await _streamNameService.setOriginalApiName(
          reachId,
          data['name'].toString(),
        );
      }

      // Cache the data for offline use
      await _offlineStorage.cacheStation(station, data);
      print("DEBUG: Cached data for station ${station.stationId}");

      return data;
    } catch (e) {
      print("DEBUG ERROR: Error fetching reach data: $e");
      throw ErrorHandler.handleError(e);
    } finally {
      print("DEBUG END: fetchReachData");
    }
  }

  /// Get a reliable display name using StreamNameService
  Future<String> getDisplayName(
    MapStation station,
    String? providedName,
  ) async {
    // First priority: Use name from StreamNameService
    try {
      final nameInfo = await _streamNameService.getNameInfo(
        station.stationId.toString(),
      );
      if (nameInfo.displayName != 'Stream ${station.stationId}') {
        return nameInfo.displayName;
      }
    } catch (e) {
      print("Error getting name from StreamNameService: $e");
    }

    // Second priority: Use the provided display name
    if (providedName != null && providedName.isNotEmpty) {
      return providedName;
    }

    // Third priority: Use station name
    if (station.name != null && station.name!.isNotEmpty) {
      return station.name!;
    }

    // Ultimate fallback: Use ID-based name
    return 'Stream ${station.stationId}';
  }

  /// Check if name is custom (different from original API name)
  Future<bool> isCustomName(String stationId, String displayName) async {
    try {
      final nameInfo = await _streamNameService.getNameInfo(stationId);
      return nameInfo.originalApiName != null &&
          nameInfo.originalApiName!.isNotEmpty &&
          displayName != nameInfo.originalApiName;
    } catch (e) {
      print("Error checking if name is custom: $e");
      return false;
    }
  }

  /// Add a station to favorites
  Future<bool> addToFavorites(
    BuildContext context,
    MapStation station, {
    String? customDisplayName,
    String? description,
  }) async {
    final stationId = station.stationId.toString();

    // Get the current display name
    String displayName =
        customDisplayName ?? await getDisplayName(station, null);
    String? originalApiName;

    // Check if we need to prompt for a name (if using default ID-based name)
    final bool isDefaultName = displayName == 'Stream $stationId';

    // Try to get original API name
    try {
      final nameInfo = await _streamNameService.getNameInfo(stationId);
      originalApiName = nameInfo.originalApiName;
    } catch (e) {
      print("Error getting original API name: $e");
    }

    // If using the default name pattern, show name input dialog
    if (isDefaultName) {
      final customName = await showStreamNameDialog(
        context,
        stationId: stationId,
      );

      // If user canceled the name dialog, abort the process
      if (customName == null) return false;

      // Use the provided name
      displayName = customName;

      // Update the StreamNameService with the new name
      try {
        await _streamNameService.updateDisplayName(stationId, customName);

        // If we have an original API name, ensure it's set
        if (originalApiName != null && originalApiName.isNotEmpty) {
          await _streamNameService.setOriginalApiName(
            stationId,
            originalApiName,
          );
        }
      } catch (e) {
        print("Warning: Failed to update StreamNameService with new name: $e");
      }

      // Also update the cached data for backward compatibility
      try {
        final cachedData = await _offlineStorage.getCachedStation(
          station.stationId,
        );
        if (cachedData != null && cachedData['apiData'] != null) {
          final Map<String, dynamic> updatedData = Map.from(
            cachedData['apiData'],
          );
          updatedData['name'] = customName;
          await _offlineStorage.cacheStation(station, updatedData);
        } else {
          // If no data exists yet, create a basic one with the name
          final Map<String, dynamic> newData = {'name': customName};
          await _offlineStorage.cacheStation(station, newData);
        }
      } catch (e) {
        print("Warning: Failed to update cached data with new name: $e");
      }
    }

    // After handling the name, proceed with adding to favorites
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final favoritesProvider = Provider.of<FavoritesProvider>(
      context,
      listen: false,
    );

    // Check if user is logged in
    final user = authProvider.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to add favorites')),
      );
      return false;
    }

    try {
      // Add station to favorites with the display name and original API name
      final success = await favoritesProvider.addFavoriteFromStation(
        user.uid,
        stationId,
        displayName: displayName,
        description: description,
        originalApiName: originalApiName,
      );

      if (success) {
        // Show confirmation snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added $displayName to favorites'),
            duration: const Duration(seconds: 1),
          ),
        );
        return true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to add to favorites. Please try again.'),
          ),
        );
        return false;
      }
    } catch (e) {
      print("Error adding to favorites: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      return false;
    }
  }

  /// Update the display name
  Future<bool> updateDisplayName(
    BuildContext context,
    String stationId,
    MapStation station,
  ) async {
    try {
      final currentName = await getDisplayName(station, null);

      // Show dialog to get new name
      final newName = await showStreamNameDialog(
        context,
        initialName: currentName,
      );

      // If user canceled or entered the same name, do nothing
      if (newName == null || newName == currentName) {
        return false;
      }

      // Update the name in StreamNameService
      final success = await _streamNameService.updateDisplayName(
        stationId,
        newName,
      );

      if (success) {
        // Also update the cached data for backward compatibility
        try {
          final cachedData = await _offlineStorage.getCachedStation(
            station.stationId,
          );
          if (cachedData != null && cachedData['apiData'] != null) {
            final Map<String, dynamic> updatedData = Map.from(
              cachedData['apiData'],
            );
            updatedData['name'] = newName;
            await _offlineStorage.cacheStation(station, updatedData);
          }
        } catch (e) {
          print("Warning: Failed to update cached data with new name: $e");
        }

        return true;
      }

      return false;
    } catch (e) {
      print("Error updating display name: $e");
      return false;
    }
  }
}
