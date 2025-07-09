// lib/features/simple_notifications/services/favorites_integration_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Service to read from existing favorites system without modifying it
/// Provides clean interface for notification system to access favorite rivers
class FavoritesIntegrationService {
  static final FavoritesIntegrationService _instance =
      FavoritesIntegrationService._internal();
  factory FavoritesIntegrationService() => _instance;
  FavoritesIntegrationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all favorite rivers for a user
  /// Returns list of FavoriteRiver objects with essential data for notifications
  Future<List<FavoriteRiver>> getUserFavoriteRivers(String userId) async {
    try {
      debugPrint('📋 Getting favorite rivers for user: $userId');

      // Query the correct nested favorites structure: favorites/{userId}/stations/{stationId}
      final favoritesSnapshot =
          await _firestore
              .collection('favorites')
              .doc(userId)
              .collection('stations')
              .get();

      debugPrint(
        '📊 Found ${favoritesSnapshot.docs.length} favorite documents',
      );

      final favoriteRivers = <FavoriteRiver>[];

      for (final doc in favoritesSnapshot.docs) {
        try {
          debugPrint('🔍 Processing favorite: ${doc.id}');
          debugPrint('📄 Data: ${doc.data()}');

          final favoriteRiver = FavoriteRiver.fromFirestoreNested(doc, userId);
          favoriteRivers.add(favoriteRiver);
          debugPrint('✅ Successfully added: ${favoriteRiver.riverName}');
        } catch (e) {
          debugPrint('⚠️ Error parsing favorite river: ${doc.id} - $e');
          debugPrint('📄 Raw data: ${doc.data()}');
          // Continue with other favorites even if one fails
        }
      }

      debugPrint('✅ Found ${favoriteRivers.length} valid favorite rivers');
      return favoriteRivers;
    } catch (e) {
      debugPrint('❌ Error getting favorite rivers: $e');
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

  /// Stream of user's favorite rivers (for real-time updates)
  Stream<List<FavoriteRiver>> watchUserFavoriteRivers(String userId) {
    return _firestore
        .collection('favorites')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final favoriteRivers = <FavoriteRiver>[];

          for (final doc in snapshot.docs) {
            try {
              final favoriteRiver = FavoriteRiver.fromFirestore(doc);
              favoriteRivers.add(favoriteRiver);
            } catch (e) {
              debugPrint(
                '⚠️ Error parsing favorite river in stream: ${doc.id} - $e',
              );
            }
          }

          return favoriteRivers;
        });
  }

  /// Get river names for display purposes
  Future<Map<String, String>> getRiverNamesMap(List<String> riverIds) async {
    final riverNames = <String, String>{};

    for (final riverId in riverIds) {
      try {
        // Try to get river name from existing data
        // This might be in stations collection, rivers collection, or cached somewhere
        final riverName = await _getRiverName(riverId);
        if (riverName != null) {
          riverNames[riverId] = riverName;
        }
      } catch (e) {
        debugPrint('⚠️ Could not get name for river $riverId: $e');
        riverNames[riverId] = 'River $riverId'; // Fallback name
      }
    }

    return riverNames;
  }

  /// Helper method to get river name from various possible sources
  Future<String?> _getRiverName(String riverId) async {
    try {
      debugPrint('🔍 Looking for name of river: $riverId');

      // Try stations collection first (most likely to have river names)
      final stationDoc =
          await _firestore.collection('stations').doc(riverId).get();

      if (stationDoc.exists) {
        final data = stationDoc.data();
        final name =
            data?['name'] ?? data?['riverName'] ?? data?['stationName'];
        if (name != null) {
          debugPrint('✅ Found name in stations: $name');
          return name;
        }
      }

      // Try rivers collection if it exists
      final riverDoc = await _firestore.collection('rivers').doc(riverId).get();

      if (riverDoc.exists) {
        final data = riverDoc.data();
        final name = data?['name'] ?? data?['riverName'];
        if (name != null) {
          debugPrint('✅ Found name in rivers: $name');
          return name;
        }
      }

      // Try getting from NOAA cache if it exists
      final noaaDoc =
          await _firestore.collection('noaaFlowCache').doc(riverId).get();

      if (noaaDoc.exists) {
        final data = noaaDoc.data();
        final name = data?['riverName'] ?? data?['name'];
        if (name != null) {
          debugPrint('✅ Found name in NOAA cache: $name');
          return name;
        }
      }

      // Try getting from returnPeriodCache if it exists
      final returnPeriodDoc =
          await _firestore.collection('returnPeriodCache').doc(riverId).get();

      if (returnPeriodDoc.exists) {
        final data = returnPeriodDoc.data();
        final name = data?['riverName'] ?? data?['name'];
        if (name != null) {
          debugPrint('✅ Found name in return period cache: $name');
          return name;
        }
      }

      debugPrint('⚠️ No name found for river: $riverId');
      return null;
    } catch (e) {
      debugPrint('❌ Error getting river name for $riverId: $e');
      return null;
    }
  }

  /// Validate that river IDs exist and are accessible
  Future<List<String>> validateRiverIds(List<String> riverIds) async {
    final validIds = <String>[];

    for (final riverId in riverIds) {
      try {
        final name = await _getRiverName(riverId);
        if (name != null) {
          validIds.add(riverId);
        }
      } catch (e) {
        debugPrint('⚠️ River ID $riverId is not valid: $e');
      }
    }

    return validIds;
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

  /// Create from nested Firestore favorites structure: favorites/{userId}/stations/{stationId}
  factory FavoriteRiver.fromFirestoreNested(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String userId,
  ) {
    final data = doc.data()!;
    final stationId = doc.id; // The document ID is the station ID

    debugPrint('🔍 Parsing nested favorite river from doc ID: $stationId');
    debugPrint('📄 Raw data: $data');

    // Get river name - try multiple possible field names
    String riverName = 'Unknown River';
    if (data['customName'] != null &&
        data['customName'].toString().isNotEmpty) {
      riverName = data['customName'] as String;
    } else if (data['name'] != null && data['name'].toString().isNotEmpty) {
      riverName = data['name'] as String;
    } else if (data['stationName'] != null &&
        data['stationName'].toString().isNotEmpty) {
      riverName = data['stationName'] as String;
    } else {
      // Fallback: try to get name from station ID or use a generic name
      riverName = 'Station $stationId';
    }

    // Get location information
    final location =
        data['location'] as String? ??
        data['state'] as String? ??
        data['city'] as String?;

    // Get timestamp - try different field names
    DateTime addedAt = DateTime.now();
    if (data['addedAt'] is Timestamp) {
      addedAt = (data['addedAt'] as Timestamp).toDate();
    } else if (data['createdAt'] is Timestamp) {
      addedAt = (data['createdAt'] as Timestamp).toDate();
    } else if (data['timestamp'] is Timestamp) {
      addedAt = (data['timestamp'] as Timestamp).toDate();
    }

    debugPrint('✅ Parsed: $riverName at $location (added: $addedAt)');

    return FavoriteRiver(
      favoriterId: doc.id,
      userId:
          userId, // Use the passed userId since it's not stored in nested docs
      riverId: stationId,
      riverName: riverName,
      location: location,
      addedAt: addedAt,
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  /// Create from existing Firestore favorites document (legacy flat structure)
  /// Adapts to your existing favorites data structure
  factory FavoriteRiver.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;

    // Adapt to different possible field names in your existing favorites
    final riverId =
        data['riverId'] ?? data['stationId'] ?? data['reachId'] ?? doc.id;

    final riverName =
        data['riverName'] ??
        data['name'] ??
        data['stationName'] ??
        'River $riverId';

    final location =
        data['location'] ?? data['locationDescription'] ?? data['state'];

    final addedAt =
        data['addedAt'] is Timestamp
            ? (data['addedAt'] as Timestamp).toDate()
            : data['createdAt'] is Timestamp
            ? (data['createdAt'] as Timestamp).toDate()
            : DateTime.now();

    return FavoriteRiver(
      favoriterId: doc.id,
      userId: data['userId'] as String,
      riverId: riverId,
      riverName: riverName,
      location: location,
      addedAt: addedAt,
      isActive: data['isActive'] as bool? ?? true,
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
