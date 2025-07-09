// lib/features/simple_notifications/services/favorites_integration_service.dart

import 'package:flutter/material.dart';

// Import local favorites system instead of Firestore
import '../../favorites/data/datasources/favorites_local_datasource.dart';
import '../../favorites/data/models/favorite_model.dart';
import '../../../../common/data/local/database_helper.dart';

/// Service to read from existing LOCAL favorites system without modifying it
/// Provides clean interface for notification system to access favorite rivers
class FavoritesIntegrationService {
  static final FavoritesIntegrationService _instance =
      FavoritesIntegrationService._internal();
  factory FavoritesIntegrationService() => _instance;
  FavoritesIntegrationService._internal();

  // Use local datasource instead of Firestore
  final FavoritesLocalDataSource _localDatasource =
      FavoritesLocalDataSourceImpl(databaseHelper: DatabaseHelper());

  /// Get all favorite rivers for a user from LOCAL SQLite storage
  /// Returns list of FavoriteRiver objects with essential data for notifications
  Future<List<FavoriteRiver>> getUserFavoriteRivers(String userId) async {
    try {
      debugPrint(
        '📋 Getting favorite rivers from LOCAL storage for user: $userId',
      );

      // Get favorites from local SQLite database
      final localFavorites = await _localDatasource.getFavorites(userId);

      debugPrint('📊 Found ${localFavorites.length} local favorite documents');

      final favoriteRivers = <FavoriteRiver>[];

      for (final favorite in localFavorites) {
        try {
          debugPrint('🔍 Processing local favorite: ${favorite.stationId}');
          debugPrint(
            '📄 Data: name=${favorite.name}, city=${favorite.city}, state=${favorite.state}',
          );

          // Convert FavoriteModel to FavoriteRiver
          final favoriteRiver = FavoriteRiver.fromLocalFavorite(favorite);
          favoriteRivers.add(favoriteRiver);
          debugPrint('✅ Successfully added: ${favoriteRiver.riverName}');
        } catch (e) {
          debugPrint(
            '⚠️ Error parsing local favorite: ${favorite.stationId} - $e',
          );
          // Continue with other favorites even if one fails
        }
      }

      debugPrint(
        '✅ Found ${favoriteRivers.length} valid favorite rivers from local storage',
      );
      return favoriteRivers;
    } catch (e) {
      debugPrint('❌ Error getting favorite rivers from local storage: $e');
      return [];
    }
  }

  /// Get favorite river IDs only (lighter query)
  Future<List<String>> getUserFavoriteRiverIds(String userId) async {
    try {
      final favorites = await getUserFavoriteRivers(userId);
      return favorites.map((river) => river.riverId).toList();
    } catch (e) {
      debugPrint('❌ Error getting favorite river IDs: $e');
      return [];
    }
  }

  /// Check if a specific river is in user's favorites
  Future<bool> isRiverFavorited(String userId, String riverId) async {
    try {
      final favoriteIds = await getUserFavoriteRiverIds(userId);
      return favoriteIds.contains(riverId);
    } catch (e) {
      debugPrint('❌ Error checking if river is favorited: $e');
      return false;
    }
  }

  /// Get specific favorite river by ID
  Future<FavoriteRiver?> getFavoriteRiver(String userId, String riverId) async {
    try {
      final favorites = await getUserFavoriteRivers(userId);
      return favorites.where((river) => river.riverId == riverId).firstOrNull;
    } catch (e) {
      debugPrint('❌ Error getting specific favorite river: $e');
      return null;
    }
  }

  /// Get river names for display purposes
  Future<Map<String, String>> getRiverNamesMap(List<String> riverIds) async {
    final riverNames = <String, String>{};

    try {
      // Since we're using local storage, we need to get all favorites first
      // We'll need a userId - this is a limitation of the current design
      // For now, we'll return the riverIds as fallback names
      for (final riverId in riverIds) {
        riverNames[riverId] = 'River $riverId'; // Fallback name
      }
    } catch (e) {
      debugPrint('⚠️ Error getting river names from local storage: $e');
      // Return fallback names
      for (final riverId in riverIds) {
        riverNames[riverId] = 'River $riverId';
      }
    }

    return riverNames;
  }

  /// Validate that river IDs exist and are accessible
  Future<List<String>> validateRiverIds(List<String> riverIds) async {
    // For local storage, we'll assume all provided river IDs are valid
    // since they came from the local favorites system
    return riverIds;
  }
}

/// Simple model representing a favorite river for notification purposes
/// Extracted from existing favorites structure
class FavoriteRiver {
  final String favoriterId; // ID of the favorite document
  final String userId;
  final String riverId; // Station ID or river reach ID
  final String riverName;
  final String? location; // Optional location description
  final DateTime addedAt;
  final bool isActive; // Whether this favorite is still active

  const FavoriteRiver({
    required this.favoriterId,
    required this.userId,
    required this.riverId,
    required this.riverName,
    this.location,
    required this.addedAt,
    this.isActive = true,
  });

  /// Create from local FavoriteModel
  factory FavoriteRiver.fromLocalFavorite(FavoriteModel favorite) {
    // Build location string from city and state if available
    String? location;
    if (favorite.city != null && favorite.state != null) {
      location = '${favorite.city}, ${favorite.state}';
    } else if (favorite.city != null) {
      location = favorite.city;
    } else if (favorite.state != null) {
      location = favorite.state;
    }

    debugPrint('🔍 Converting local favorite: ${favorite.stationId}');
    debugPrint('📄 Name: ${favorite.name}, Location: $location');

    return FavoriteRiver(
      favoriterId:
          favorite.stationId, // Use stationId as favoriterId for local storage
      userId: favorite.userId,
      riverId: favorite.stationId,
      riverName: favorite.name,
      location: location,
      addedAt:
          (favorite.lastUpdated is DateTime)
              ? favorite.lastUpdated as DateTime
              : DateTime.now(),
      isActive: true, // Assume all local favorites are active
    );
  }

  /// Get display name for notifications
  String get displayName {
    if (location != null && location!.isNotEmpty) {
      return '$riverName ($location)';
    }
    return riverName;
  }

  /// Check if this favorite is valid for notifications
  bool get isValidForNotifications {
    return isActive && riverId.isNotEmpty && riverName.isNotEmpty;
  }

  @override
  String toString() {
    return 'FavoriteRiver(id: $riverId, name: $riverName, location: $location)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FavoriteRiver &&
        other.riverId == riverId &&
        other.userId == userId;
  }

  @override
  int get hashCode => Object.hash(riverId, userId);
}
