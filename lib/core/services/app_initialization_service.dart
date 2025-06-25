// lib/core/services/app_initialization_service.dart
// Production app initialization service

import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'notification_service.dart';
import 'notification_handler.dart';

/// Production-ready app initialization service
///
/// Handles clean startup of notification system and other core services
/// without cluttering main.dart or mixing academic concerns
class AppInitializationService {
  static final AppInitializationService _instance =
      AppInitializationService._internal();
  factory AppInitializationService() => _instance;
  AppInitializationService._internal();

  bool _isInitialized = false;
  String _currentStatus = 'Not initialized';

  // Core services
  late final NotificationService _notificationService;
  late final NotificationHandler _notificationHandler;

  /// Initialize all core app services
  Future<bool> initialize({
    required GlobalKey<NavigatorState> navigatorKey,
    Function(String)? onStatusUpdate,
  }) async {
    if (_isInitialized) return true;

    try {
      _updateStatus('Initializing core services...', onStatusUpdate);

      // 1. Initialize notification service
      _notificationService = NotificationService();
      await _notificationService.initialize();
      _updateStatus('Notification service ready', onStatusUpdate);

      // 2. Set up background message handler
      await _setupBackgroundMessageHandler();
      _updateStatus('Background messaging configured', onStatusUpdate);

      // 3. Initialize notification handler
      _notificationHandler = NotificationHandler();
      await _notificationHandler.initialize(
        navigatorKey: navigatorKey,
        onInteraction: _handleNotificationInteraction,
        onForegroundMessage: _handleForegroundMessage,
      );
      _updateStatus('Notification handling active', onStatusUpdate);

      // 4. Additional core services can be initialized here
      // e.g., analytics, crash reporting, user preferences, etc.

      _updateStatus('App ready', onStatusUpdate);
      _isInitialized = true;
      return true;
    } catch (e) {
      _updateStatus('Initialization failed: $e', onStatusUpdate);
      debugPrint('❌ App initialization failed: $e');
      return false;
    }
  }

  /// Set up Firebase background message handler
  Future<void> _setupBackgroundMessageHandler() async {
    // Background message handler must be top-level function
    // This is handled in main.dart, but we configure settings here

    // Configure notification presentation options
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

    debugPrint('✅ Background message handler configured');
  }

  /// Handle notification interactions for production app
  void _handleNotificationInteraction(NotificationInteraction interaction) {
    debugPrint(
      '📱 User interacted with notification: ${interaction.interactionType}',
    );

    // In production, you might:
    // - Track user engagement analytics
    // - Update user preferences based on behavior
    // - Log for app improvement insights

    _logUserInteraction(interaction);
  }

  /// Handle foreground messages for production app
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📨 Foreground notification: ${message.notification?.title}');

    // In production, you might:
    // - Update app badge count
    // - Show subtle in-app indicators
    // - Update notification center

    _logNotificationDelivery(message);
  }

  /// Log user interaction for analytics (production-ready approach)
  void _logUserInteraction(NotificationInteraction interaction) {
    // This would integrate with your analytics service
    // e.g., Firebase Analytics, Mixpanel, etc.

    final eventData = {
      'event_type': 'notification_interaction',
      'interaction_type': interaction.interactionType,
      'app_state': interaction.appState.toString(),
      'message_category': interaction.message.data['category'],
      'message_priority': interaction.message.data['priority'],
      'timestamp': interaction.timestamp.toIso8601String(),
    };

    debugPrint('📊 User interaction logged: ${eventData['interaction_type']}');

    // TODO: Send to your production analytics service
    // AnalyticsService.logEvent('notification_interaction', eventData);
  }

  /// Log notification delivery for analytics
  void _logNotificationDelivery(RemoteMessage message) {
    final deliveryData = {
      'event_type': 'notification_delivered',
      'title': message.notification?.title,
      'category': message.data['category'],
      'priority': message.data['priority'],
      'delivery_time': DateTime.now().toIso8601String(),
    };

    debugPrint('📈 Notification delivery logged: ${deliveryData['title']}');

    // TODO: Send to your production analytics service
    // AnalyticsService.logEvent('notification_delivered', deliveryData);
  }

  /// Update initialization status
  void _updateStatus(String status, Function(String)? onStatusUpdate) {
    _currentStatus = status;
    onStatusUpdate?.call(status);
    debugPrint('🔄 App Status: $status');
  }

  /// Get current initialization status
  String get currentStatus => _currentStatus;

  /// Check if app is fully initialized
  bool get isInitialized => _isInitialized;

  /// Get notification service instance
  NotificationService get notificationService {
    if (!_isInitialized) {
      throw StateError('AppInitializationService not initialized');
    }
    return _notificationService;
  }

  /// Get notification handler instance
  NotificationHandler get notificationHandler {
    if (!_isInitialized) {
      throw StateError('AppInitializationService not initialized');
    }
    return _notificationHandler;
  }

  /// Cleanup on app termination
  Future<void> dispose() async {
    // Cleanup resources if needed
    debugPrint('🧹 App cleanup completed');
  }
}
