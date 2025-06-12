// lib/core/services/notification_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notification Service for handling Firebase Cloud Messaging and local notifications
///
/// This service integrates with the alert system created in Task 4.2
/// and provides notification handling for the Rivr app.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Firebase Messaging instance
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  // Local notifications plugin
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Notification permission status
  bool _permissionGranted = false;
  String? _fcmToken;

  // Getters
  bool get permissionGranted => _permissionGranted;
  String? get fcmToken => _fcmToken;

  /// Initialize the notification service
  /// Call this in your main.dart after Firebase initialization
  Future<void> initialize() async {
    debugPrint('🔔 Initializing Notification Service...');

    try {
      // Initialize local notifications
      await _initializeLocalNotifications();

      // Request permissions
      await _requestPermissions();

      // Set up FCM message handlers
      await _setupMessageHandlers();

      // Get FCM token
      await _getFCMToken();

      // Configure notification settings
      await _configureNotificationSettings();

      debugPrint('✅ Notification Service initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing Notification Service: $e');
    }
  }

  /// Initialize local notifications plugin
  Future<void> _initializeLocalNotifications() async {
    // Android initialization
    const AndroidInitializationSettings androidInitSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization
    const DarwinInitializationSettings iosInitSettings =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

    // Combined initialization settings
    const InitializationSettings initSettings = InitializationSettings(
      android: androidInitSettings,
      iOS: iosInitSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    debugPrint('📱 Local notifications initialized');
  }

  /// Request notification permissions from the user
  Future<void> _requestPermissions() async {
    debugPrint('🔐 Requesting notification permissions...');

    // Request FCM permissions
    final NotificationSettings settings = await _firebaseMessaging
        .requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: true, // For safety alerts
          provisional: false,
          sound: true,
        );

    _permissionGranted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    debugPrint('📋 Permission status: ${settings.authorizationStatus}');
    debugPrint('🔔 Notifications enabled: $_permissionGranted');

    // Request local notification permissions for Android 13+
    if (Platform.isAndroid) {
      final bool? granted =
          await _localNotifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission();

      debugPrint('📱 Android local notification permission: $granted');
    }
  }

  /// Set up Firebase Cloud Messaging handlers
  Future<void> _setupMessageHandlers() async {
    debugPrint('🔧 Setting up FCM message handlers...');

    // Handle messages when app is in foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(
      _handleBackgroundNotificationTap,
    );

    // Handle notification taps when app is terminated
    final RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      debugPrint(
        '📩 App launched from notification: ${initialMessage.messageId}',
      );
      _handleBackgroundNotificationTap(initialMessage);
    }

    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    debugPrint('✅ FCM message handlers configured');
  }

  /// Get FCM token for sending targeted notifications
  Future<void> _getFCMToken() async {
    try {
      _fcmToken = await _firebaseMessaging.getToken();
      debugPrint('🎫 FCM Token: $_fcmToken');

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((String token) {
        debugPrint('🔄 FCM Token refreshed: $token');
        _fcmToken = token;
        // TODO: Update token in Firestore for the current user
        _updateTokenInDatabase(token);
      });
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
    }
  }

  /// Configure notification presentation options
  Future<void> _configureNotificationSettings() async {
    // iOS: Set foreground notification presentation options
    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint('🔧 Notification settings configured');
  }

  /// Handle foreground messages (app is open)
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('📨 Foreground message received: ${message.messageId}');
    debugPrint('📋 Title: ${message.notification?.title}');
    debugPrint('📄 Body: ${message.notification?.body}');
    debugPrint('📊 Data: ${message.data}');

    // Show local notification for foreground messages
    await _showLocalNotification(message);

    // Track notification for thesis metrics
    await _trackNotificationReceived(message, 'foreground');
  }

  /// Handle background notification taps
  Future<void> _handleBackgroundNotificationTap(RemoteMessage message) async {
    debugPrint('👆 Background notification tapped: ${message.messageId}');

    // Track notification interaction
    await _trackNotificationInteraction(message, 'background_tap');

    // Handle deep linking based on notification data
    await _handleDeepLink(message.data);
  }

  /// Handle notification tap from local notifications
  Future<void> _onNotificationTapped(NotificationResponse response) async {
    debugPrint('👆 Local notification tapped: ${response.id}');

    // Parse payload for deep linking
    if (response.payload != null) {
      try {
        final Map<String, dynamic> data = json.decode(response.payload!);
        await _handleDeepLink(data);
        await _trackNotificationInteraction(null, 'local_tap', data);
      } catch (e) {
        debugPrint('❌ Error parsing notification payload: $e');
      }
    }
  }

  /// Show local notification for foreground messages
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final String title = message.notification?.title ?? 'Rivr Flow Alert';
    final String body =
        message.notification?.body ?? 'New flow conditions detected';

    // Determine notification importance based on alert type
    final String? priority = message.data['priority'];
    final Importance importance = _getNotificationImportance(priority);
    final Priority androidPriority = _getAndroidPriority(priority);

    // Android notification details
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'rivr_flow_alerts', // Channel ID
          'Flow Alerts', // Channel name
          channelDescription:
              'Notifications for river flow conditions and safety alerts',
          importance: importance,
          priority: androidPriority,
          showWhen: true,
          enableVibration: true,
          enableLights: true,
          color: _getNotificationColor(message.data['category']),
          icon: '@mipmap/ic_launcher',
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        );

    // iOS notification details
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    // Combined notification details
    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Show the notification
    await _localNotifications.show(
      message.hashCode, // Unique notification ID
      title,
      body,
      notificationDetails,
      payload: json.encode(message.data), // Include data for deep linking
    );

    debugPrint('📱 Local notification shown: $title');
  }

  /// Handle deep linking based on notification data
  Future<void> _handleDeepLink(Map<String, dynamic> data) async {
    try {
      final String? reachId = data['reachId'];
      final String? deepLink = data['deepLink'];

      if (deepLink != null) {
        // Handle custom deep link format: rivr://reach/12345
        final Uri uri = Uri.parse(deepLink);

        if (uri.scheme == 'rivr') {
          switch (uri.host) {
            case 'reach':
              final String? id =
                  uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
              if (id != null) {
                await _navigateToReachDetails(id);
              }
              break;
            case 'demo':
              await _navigateToDemoScreen();
              break;
            default:
              debugPrint('🤷 Unknown deep link host: ${uri.host}');
          }
        }
      } else if (reachId != null) {
        // Fallback: navigate to reach details if we have a reachId
        await _navigateToReachDetails(reachId);
      }
    } catch (e) {
      debugPrint('❌ Error handling deep link: $e');
    }
  }

  /// Navigate to reach details screen
  Future<void> _navigateToReachDetails(String reachId) async {
    debugPrint('🚀 Navigating to reach details: $reachId');

    // TODO: Integrate with your existing navigation system
    // You can replace this with your actual navigation logic
    // Examples:
    // - Navigator.pushNamed(context, '/reach-details', arguments: reachId);
    // - GoRouter.of(context).go('/reach/$reachId');
    // - Your existing routing solution

    // For now, just log the navigation intent
    debugPrint('📍 Would navigate to reach: $reachId');
    debugPrint('💡 Integrate this with your existing navigation in your app');
  }

  /// Navigate to demo/thesis screen
  Future<void> _navigateToDemoScreen() async {
    debugPrint('🎓 Navigating to thesis demo screen');

    // TODO: Navigate to your thesis demo screen
    // Replace with your actual demo screen navigation

    debugPrint('🎬 Would navigate to demo screen');
    debugPrint('💡 You can add this navigation in your app');
  }

  /// Update FCM token in database
  Future<void> _updateTokenInDatabase(String token) async {
    try {
      // TODO: Update the user's FCM token in Firestore
      // This will be used by the Cloud Functions to send targeted notifications

      debugPrint('💾 Would update FCM token in database: $token');

      // Example implementation:
      // final user = FirebaseAuth.instance.currentUser;
      // if (user != null) {
      //   await FirebaseFirestore.instance
      //       .collection('users')
      //       .doc(user.uid)
      //       .update({'fcmToken': token});
      // }
    } catch (e) {
      debugPrint('❌ Error updating FCM token: $e');
    }
  }

  /// Track notification received for thesis metrics
  Future<void> _trackNotificationReceived(
    RemoteMessage message,
    String state,
  ) async {
    try {
      // TODO: Track notification metrics for thesis
      final Map<String, dynamic> metrics = {
        'messageId': message.messageId,
        'title': message.notification?.title,
        'category': message.data['category'],
        'priority': message.data['priority'],
        'receivedAt': DateTime.now().toIso8601String(),
        'appState': state,
      };

      debugPrint('📊 Notification received metrics: $metrics');

      // Example: Store in Firestore for thesis analysis
      // await FirebaseFirestore.instance
      //     .collection('thesisMetrics')
      //     .collection('notificationDelivery')
      //     .add(metrics);
    } catch (e) {
      debugPrint('❌ Error tracking notification: $e');
    }
  }

  /// Track notification interaction for thesis metrics
  Future<void> _trackNotificationInteraction(
    RemoteMessage? message,
    String interactionType, [
    Map<String, dynamic>? localData,
  ]) async {
    try {
      final Map<String, dynamic> metrics = {
        'messageId': message?.messageId ?? 'local',
        'interactionType': interactionType,
        'category': message?.data['category'] ?? localData?['category'],
        'priority': message?.data['priority'] ?? localData?['priority'],
        'interactedAt': DateTime.now().toIso8601String(),
      };

      debugPrint('👆 Notification interaction metrics: $metrics');

      // Store for thesis analysis
      // await FirebaseFirestore.instance
      //     .collection('thesisMetrics')
      //     .collection('notificationInteractions')
      //     .add(metrics);
    } catch (e) {
      debugPrint('❌ Error tracking interaction: $e');
    }
  }

  /// Get notification importance based on priority
  Importance _getNotificationImportance(String? priority) {
    switch (priority) {
      case 'safety':
        return Importance.max; // Critical safety alerts
      case 'activity':
        return Importance.high; // Activity threshold alerts
      case 'demonstration':
        return Importance.high; // Thesis demo
      case 'information':
      default:
        return Importance.defaultImportance; // General flow updates
    }
  }

  /// Get Android priority based on alert priority
  Priority _getAndroidPriority(String? priority) {
    switch (priority) {
      case 'safety':
        return Priority.max;
      case 'activity':
      case 'demonstration':
        return Priority.high;
      case 'information':
      default:
        return Priority.defaultPriority;
    }
  }

  /// Get notification color based on flow category
  Color? _getNotificationColor(String? category) {
    switch (category) {
      case 'Low':
        return Colors.blue.shade200;
      case 'Normal':
        return Colors.green;
      case 'Moderate':
        return Colors.yellow.shade700;
      case 'Elevated':
        return Colors.orange;
      case 'High':
        return Colors.deepOrange;
      case 'Very High':
        return Colors.red;
      case 'Extreme':
        return Colors.purple;
      default:
        return Colors.blue; // Default Rivr blue
    }
  }

  /// Test notification delivery (for development)
  Future<void> sendTestNotification({
    String title = '🧪 Test Notification',
    String body = 'Testing Rivr notification system',
    String category = 'Normal',
    String priority = 'information',
    String? reachId = 'test-reach',
  }) async {
    if (!_permissionGranted) {
      debugPrint('❌ Cannot send test notification - permissions not granted');
      return;
    }

    // Create test notification data
    final Map<String, dynamic> testData = {
      'reachId': reachId ?? 'test-reach',
      'flowValue': '250.0',
      'flowUnit': 'cfs',
      'category': category,
      'priority': priority,
      'timestamp': DateTime.now().toIso8601String(),
      'deepLink': 'rivr://reach/${reachId ?? 'test-reach'}',
    };

    // Android notification details
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'rivr_flow_alerts',
          'Flow Alerts',
          channelDescription:
              'Notifications for river flow conditions and safety alerts',
          importance: _getNotificationImportance(priority),
          priority: _getAndroidPriority(priority),
          showWhen: true,
          enableVibration: true,
          color: _getNotificationColor(category),
          icon: '@mipmap/ic_launcher',
        );

    // iOS notification details
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Show test notification
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
      payload: json.encode(testData),
    );

    debugPrint('🧪 Test notification sent: $title');
  }

  /// Dispose resources
  void dispose() {
    // Clean up resources if needed
    debugPrint('🔔 NotificationService disposed');
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if needed
  // await Firebase.initializeApp();

  debugPrint('📨 Background message received: ${message.messageId}');
  debugPrint('📋 Title: ${message.notification?.title}');
  debugPrint('📄 Body: ${message.notification?.body}');

  // Handle background processing if needed
  // Note: This runs in a separate isolate, so state is not shared
}
