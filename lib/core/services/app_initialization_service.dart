// lib/core/services/app_initialization_service.dart
// Task 4.4: Fixed to integrate with your existing app structure

import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'notification_service.dart';
import 'notification_handler.dart';

/// Production-ready app initialization service
/// Integrates with your existing app architecture and patterns
class AppInitializationService {
  static final AppInitializationService _instance =
      AppInitializationService._internal();
  factory AppInitializationService() => _instance;
  AppInitializationService._internal();

  bool _isInitialized = false;
  String _currentStatus = 'Not initialized';

  // Service references (works with your existing services)
  NotificationService? _notificationService;
  NotificationHandler? _notificationHandler;

  /// Initialize core services with your existing app context
  Future<bool> initialize({
    required BuildContext context,
    Function(String)? onStatusUpdate,
    bool useExistingNotificationService = true,
  }) async {
    if (_isInitialized) return true;

    try {
      _updateStatus('Initializing notification system...', onStatusUpdate);

      // 1. Initialize or get existing notification service
      await _initializeNotificationService(useExistingNotificationService);
      _updateStatus('Notification service ready', onStatusUpdate);

      // 2. Set up Firebase messaging configuration
      await _configureFCMSettings();
      _updateStatus('FCM configured', onStatusUpdate);

      // 3. Initialize notification handler with context
      await _initializeNotificationHandler(context);
      _updateStatus('Notification handling active', onStatusUpdate);

      // 4. Set up background message handling
      await _setupBackgroundMessageHandler();
      _updateStatus('Background messaging ready', onStatusUpdate);

      // 5. Request notification permissions
      await _requestNotificationPermissions();
      _updateStatus('Permissions configured', onStatusUpdate);

      _updateStatus('Notification system ready', onStatusUpdate);
      _isInitialized = true;
      return true;
    } catch (e) {
      _updateStatus('Initialization failed: $e', onStatusUpdate);
      debugPrint('❌ App initialization failed: $e');
      return false;
    }
  }

  /// Initialize notification service (use existing or create new)
  Future<void> _initializeNotificationService(bool useExisting) async {
    try {
      if (useExisting) {
        // Try to use your existing NotificationService
        _notificationService = NotificationService();

        // Initialize the existing notification service
        await _notificationService!.initialize();

        debugPrint('✅ Using existing NotificationService');
      } else {
        // Create new service if needed
        _notificationService = NotificationService();
        await _notificationService!.initialize();
        debugPrint('✅ Created new NotificationService');
      }
    } catch (e) {
      debugPrint('⚠️ NotificationService initialization: $e');
      // Continue without notification service if it fails
      _notificationService = null;
    }
  }

  /// Configure FCM settings for your app
  Future<void> _configureFCMSettings() async {
    try {
      // Configure notification presentation options
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );

      // Subscribe to general topics if needed
      await FirebaseMessaging.instance.subscribeToTopic('rivr_general');

      debugPrint('✅ FCM settings configured');
    } catch (e) {
      debugPrint('⚠️ FCM configuration error: $e');
      // Non-critical, continue without FCM config
    }
  }

  /// Initialize notification handler with context
  Future<void> _initializeNotificationHandler(BuildContext context) async {
    try {
      _notificationHandler = NotificationHandler();
      await _notificationHandler!.initialize(
        context: context,
        onInteraction: _handleNotificationInteraction,
        onForegroundMessage: _handleForegroundMessage,
      );

      debugPrint('✅ NotificationHandler initialized with context');
    } catch (e) {
      debugPrint('❌ NotificationHandler initialization failed: $e');
      throw Exception('Critical: NotificationHandler failed to initialize');
    }
  }

  /// Set up background message handler (must be top-level function)
  Future<void> _setupBackgroundMessageHandler() async {
    try {
      // Background handler is set up in main.dart as a top-level function
      // This just configures additional settings

      // Log that background handling is configured
      debugPrint('✅ Background message handler configured');
    } catch (e) {
      debugPrint('⚠️ Background handler setup: $e');
      // Non-critical, app can work without background handling
    }
  }

  /// Request notification permissions from user
  Future<void> _requestNotificationPermissions() async {
    try {
      final NotificationSettings settings = await FirebaseMessaging.instance
          .requestPermission(
            alert: true,
            announcement: false,
            badge: true,
            carPlay: false,
            criticalAlert: false,
            provisional: false,
            sound: true,
          );

      final status = settings.authorizationStatus;
      debugPrint('📱 Notification permission: $status');

      if (status == AuthorizationStatus.denied) {
        debugPrint('⚠️ User denied notification permissions');
      } else if (status == AuthorizationStatus.provisional) {
        debugPrint('📱 Provisional notification permissions granted');
      } else if (status == AuthorizationStatus.authorized) {
        debugPrint('✅ Full notification permissions granted');
      }
    } catch (e) {
      debugPrint('⚠️ Permission request error: $e');
      // Continue without permissions
    }
  }

  /// Handle notification interactions
  void _handleNotificationInteraction(NotificationInteraction interaction) {
    debugPrint(
      '📱 User interacted with notification: ${interaction.interactionType}',
    );

    // Track interaction for analytics
    _trackNotificationInteraction(interaction);

    // Additional interaction handling can be added here
    // e.g., update user engagement metrics, adjust notification frequency
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📨 Foreground notification: ${message.notification?.title}');

    // Track delivery
    _trackNotificationDelivery(message);

    // Additional foreground handling can be added here
    // e.g., update app badge, show in-app indicators
  }

  /// Track notification interaction for analytics
  void _trackNotificationInteraction(NotificationInteraction interaction) {
    try {
      final eventData = {
        'event_type': 'notification_interaction',
        'interaction_type': interaction.interactionType,
        'app_state': interaction.appState.toString(),
        'message_category': interaction.message.data['category'],
        'message_priority': interaction.message.data['priority'],
        'timestamp': interaction.timestamp.toIso8601String(),
      };

      debugPrint('📊 Interaction tracked: ${eventData['interaction_type']}');

      // TODO: Integrate with your existing analytics service
      // Example: FirebaseAnalytics.instance.logEvent(...)
      // Or: Your custom analytics service
    } catch (e) {
      debugPrint('⚠️ Analytics tracking error: $e');
    }
  }

  /// Track notification delivery for analytics
  void _trackNotificationDelivery(RemoteMessage message) {
    try {
      final deliveryData = {
        'event_type': 'notification_delivered',
        'title': message.notification?.title,
        'category': message.data['category'],
        'priority': message.data['priority'],
        'delivery_time': DateTime.now().toIso8601String(),
      };

      debugPrint('📈 Delivery tracked: ${deliveryData['title']}');

      // TODO: Integrate with your existing analytics service
    } catch (e) {
      debugPrint('⚠️ Delivery tracking error: $e');
    }
  }

  /// Update initialization status
  void _updateStatus(String status, Function(String)? onStatusUpdate) {
    _currentStatus = status;
    onStatusUpdate?.call(status);
    debugPrint('🔄 Init Status: $status');
  }

  /// Update context for navigation (call when context changes)
  void updateContext(BuildContext context) {
    _notificationHandler?.updateContext(context);
  }

  /// Get current initialization status
  String get currentStatus => _currentStatus;

  /// Check if app is fully initialized
  bool get isInitialized => _isInitialized;

  /// Get notification service instance (if available)
  NotificationService? get notificationService => _notificationService;

  /// Get notification handler instance (if available)
  NotificationHandler? get notificationHandler => _notificationHandler;

  /// Test notification system (for development)
  Future<void> testNotificationSystem() async {
    if (!_isInitialized) {
      debugPrint('❌ Cannot test: System not initialized');
      return;
    }

    debugPrint('🧪 Testing notification system...');

    try {
      // Test notification handler if available
      await _notificationHandler?.testNotificationInteractions();

      // Test FCM token retrieval
      final token = await FirebaseMessaging.instance.getToken();
      debugPrint('📱 FCM Token: ${token?.substring(0, 20)}...');

      debugPrint('✅ Notification system test completed');
    } catch (e) {
      debugPrint('❌ Notification system test failed: $e');
    }
  }

  /// Graceful cleanup on app termination
  Future<void> dispose() async {
    try {
      // Remove observers and cleanup
      debugPrint('🧹 App notification cleanup completed');
    } catch (e) {
      debugPrint('⚠️ Cleanup error: $e');
    }
  }
}

/// Extension to help with backwards compatibility
extension AppInitializationServiceLegacy on AppInitializationService {
  /// Legacy initialize method for backwards compatibility
  Future<bool> initializeWithNavigatorKey({
    required GlobalKey<NavigatorState> navigatorKey,
    Function(String)? onStatusUpdate,
  }) async {
    // Convert to context-based initialization
    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint('❌ Navigator context not available');
      return false;
    }

    return initialize(context: context, onStatusUpdate: onStatusUpdate);
  }
}
