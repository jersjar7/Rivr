// lib/core/services/notification_shadow_service.dart
// Simple service to push favorites to Firestore ONLY for notifications

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../../features/favorites/domain/entities/favorite.dart';

class NotificationShadowService {
  static final NotificationShadowService _instance =
      NotificationShadowService._internal();
  factory NotificationShadowService() => _instance;
  NotificationShadowService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Simple push of favorites to Firestore (one-way, just for notifications)
  Future<void> pushFavoritesToFirestore(
    String userId,
    List<Favorite> favorites,
  ) async {
    try {
      // Only push - don't read back or sync
      debugPrint(
        '📤 Pushing ${favorites.length} favorites to Firestore for notifications...',
      );

      final batch = _firestore.batch();

      // Delete old favorites for this user
      final existingQuery =
          await _firestore
              .collection('favorites')
              .where('userId', isEqualTo: userId)
              .get();

      for (final doc in existingQuery.docs) {
        batch.delete(doc.reference);
      }

      // Add current favorites
      for (final favorite in favorites) {
        final docRef = _firestore.collection('favorites').doc();
        batch.set(docRef, {
          'userId': userId,
          'reachId': favorite.stationId, // Cloud function expects this field
          'name': favorite.name,
          'pushedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      debugPrint('✅ Pushed ${favorites.length} favorites for notifications');
    } catch (e) {
      debugPrint('❌ Failed to push favorites for notifications: $e');
      // Don't throw - this shouldn't break the main app
    }
  }

  /// Set up user for notifications (FCM token + enabled flag)
  Future<void> setupUserForNotifications(String userId) async {
    try {
      debugPrint('🔔 Setting up user for notifications...');

      // Get FCM token
      final fcmToken = await _getFCMToken();
      if (fcmToken == null) {
        debugPrint('❌ No FCM token - notifications disabled');
        return;
      }

      // Simple user setup in Firestore
      await _firestore.collection('users').doc(userId).set({
        'notificationsEnabled': true,
        'fcmToken': fcmToken,
        'setupAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ User ready for notifications');
    } catch (e) {
      debugPrint('❌ Failed to setup user for notifications: $e');
    }
  }

  /// Get real FCM token - no dummy values
  Future<String?> _getFCMToken() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        debugPrint('❌ Notification permission denied');
        return null;
      }

      final token = await _messaging.getToken();
      if (token != null) {
        debugPrint('✅ Real FCM token obtained: ${token.substring(0, 10)}...');
        return token;
      } else {
        debugPrint('❌ Failed to get FCM token - notifications will not work');
        return null;
      }
    } catch (e) {
      debugPrint('❌ FCM token error: $e');
      debugPrint('   This needs to be fixed for notifications to work');
      return null;
    }
  }

  /// Complete setup: user + current favorites
  Future<void> initializeNotifications(
    String userId,
    List<Favorite> currentFavorites,
  ) async {
    await Future.wait([
      setupUserForNotifications(userId),
      pushFavoritesToFirestore(userId, currentFavorites),
    ]);
  }
}
