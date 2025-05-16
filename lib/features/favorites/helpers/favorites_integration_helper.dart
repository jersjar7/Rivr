// lib/features/favorites/helpers/favorites_integration_helper.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rivr/core/di/service_locator.dart';
import 'package:rivr/core/services/geocoding_service.dart';
import 'package:rivr/core/services/stream_name_service.dart';
import 'package:rivr/features/map/presentation/helpers/stream_info_helper.dart';
import '../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../features/favorites/presentation/providers/favorites_provider.dart';
import '../../../features/map/domain/entities/map_station.dart';

/// A helper class that integrates favorites functionality across the app
class FavoritesIntegrationHelper {
  /// Add a station to favorites
  /// Returns true if successful, false otherwise
  static Future<bool> addStationToFavorites(
    BuildContext context,
    MapStation station, {
    String? description,
    String? displayName,
    bool showSnackbar = true,
  }) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final favoritesProvider = Provider.of<FavoritesProvider>(
      context,
      listen: false,
    );

    // Get the StreamNameService from service locator
    final streamNameService = sl<StreamNameService>();

    // Create a helper instance for name-related operations
    final streamInfoHelper = StreamInfoHelper(
      streamNameService: streamNameService,
    );

    final user = authProvider.currentUser;
    if (user == null) {
      if (showSnackbar) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('You need to be logged in to add favorites'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return false;
    }

    try {
      // Get proper display name from StreamNameService
      String nameToUse;
      if (displayName != null && displayName.isNotEmpty) {
        nameToUse = displayName;
      } else {
        nameToUse = await streamInfoHelper.getDisplayName(station, null);
      }

      // Get original API name if available
      String? originalApiName;
      try {
        final nameInfo = await streamNameService.getNameInfo(
          station.stationId.toString(),
        );
        originalApiName = nameInfo.originalApiName;
      } catch (e) {
        print('Error getting original API name: $e');
        // Continue without original API name
      }

      // Get location information using GeocodingService
      String? city;
      String? state;
      try {
        print('Getting location info for station ${station.stationId}');
        final geocodingService = sl<GeocodingService>();
        final locationInfo = await geocodingService.getLocationInfo(
          station.lat,
          station.lon,
        );

        if (locationInfo != null) {
          city = locationInfo.city;
          state = locationInfo.state;
          print('Found location: ${locationInfo.formattedLocation}');
        }
      } catch (e) {
        print('Error getting location info: $e');
        // Continue without location info
      }

      // Add to favorites with proper name information, coordinates, and location
      final success = await favoritesProvider.addFavoriteFromStation(
        user.uid,
        station.stationId.toString(),
        displayName: nameToUse,
        description: description,
        originalApiName: originalApiName,
        lat: station.lat,
        lon: station.lon,
        elevation: station.elevation,
        city: city, // Include city
        state: state, // Include state
      );

      if (success && showSnackbar) {
        String message = '$nameToUse added to favorites';
        if (city != null && state != null) {
          message = '$nameToUse in $city, $state added to favorites';
        }

        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      return success;
    } catch (e) {
      print('Error adding station to favorites: $e');

      if (showSnackbar) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Failed to add to favorites: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      return false;
    }
  }

  /// Remove a station from favorites
  /// Returns true if successful, false otherwise
  static Future<bool> removeStationFromFavorites(
    BuildContext context,
    String stationId, {
    bool showSnackbar = true,
    bool showUndoOption = true,
  }) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final favoritesProvider = Provider.of<FavoritesProvider>(
      context,
      listen: false,
    );

    final user = authProvider.currentUser;
    if (user == null) {
      return false;
    }

    try {
      // Find favorite details before deletion for the snackbar message
      final favoriteIndex = favoritesProvider.favorites.indexWhere(
        (f) => f.stationId == stationId && f.userId == user.uid,
      );

      if (favoriteIndex < 0) {
        return false; // Not found
      }

      final favorite = favoritesProvider.favorites[favoriteIndex];

      // Remove favorite
      await favoritesProvider.deleteFavorite(user.uid, stationId);

      // Show a snackbar with undo option
      if (showSnackbar) {
        scaffoldMessenger.clearSnackBars();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('${favorite.name} removed from favorites'),
            action:
                showUndoOption
                    ? SnackBarAction(
                      label: 'UNDO',
                      onPressed: () {
                        // Undo the deletion
                        favoritesProvider.undoDelete(stationId);
                      },
                    )
                    : null,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      return true;
    } catch (e) {
      print('Error removing station from favorites: $e');

      if (showSnackbar) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Failed to remove from favorites: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      return false;
    }
  }

  /// Check if a station is a favorite
  /// Returns true if it is, false otherwise
  static Future<bool> isStationFavorite(
    BuildContext context,
    String stationId,
  ) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final favoritesProvider = Provider.of<FavoritesProvider>(
      context,
      listen: false,
    );

    final user = authProvider.currentUser;
    if (user == null) {
      return false;
    }

    try {
      return await favoritesProvider.checkIsFavorite(user.uid, stationId);
    } catch (e) {
      print('Error checking if station is favorite: $e');
      return false;
    }
  }

  /// Get display name for a station using StreamNameService
  static Future<String> getStationDisplayName(
    String stationId,
    String? fallbackName,
  ) async {
    try {
      final streamNameService = sl<StreamNameService>();
      final displayName = await streamNameService.getDisplayName(stationId);
      return displayName;
    } catch (e) {
      print('Error getting station display name: $e');
      return fallbackName ?? 'Stream $stationId';
    }
  }

  /// Navigate to the favorites page with an optional callback
  static void navigateToFavorites(
    BuildContext context, {
    double lat = 0.0,
    double lon = 0.0,
    bool replaceScreen = false,
  }) {
    if (replaceScreen) {
      Navigator.pushReplacementNamed(
        context,
        '/favorites',
        arguments: {'lat': lat, 'lon': lon},
      );
    } else {
      Navigator.pushNamed(
        context,
        '/favorites',
        arguments: {'lat': lat, 'lon': lon},
      );
    }
  }

  /// Navigate to the map to add a new favorite
  static void navigateToMapForFavorite(
    BuildContext context, {
    double lat = 0.0,
    double lon = 0.0,
    Function? onStationAddedToFavorites,
  }) {
    Navigator.pushNamed(
      context,
      '/map',
      arguments: {
        'lat': lat,
        'lon': lon,
        'onStationAddedToFavorites': onStationAddedToFavorites,
      },
    );
  }

  /// Navigate to the forecast page for a station
  static void navigateToForecast(
    BuildContext context,
    String reachId,
    String stationName,
  ) {
    Navigator.pushNamed(
      context,
      '/forecast',
      arguments: {'reachId': reachId, 'stationName': stationName},
    );
  }
}
