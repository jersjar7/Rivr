// lib/features/simple_notifications/services/simple_notification_service.dart

import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/flow_alert.dart';

/// Simple notification service for flow alerts
/// Focused only on basic FCM setup and sending notifications
class SimpleNotificationService {
  static final SimpleNotificationService _instance =
      SimpleNotificationService._internal();
  factory SimpleNotificationService() => _instance;
  SimpleNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _permissionGranted = false;
  String? _fcmToken;

  /// Initialize the service - call this once at app startup
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      debugPrint('🔔 Initializing Simple Notification Service...');

      // Initialize local notifications for foreground display
      await _initializeLocalNotifications();

      // Request permissions
      await _requestPermissions();

      // Get FCM token
      await _getFCMToken();

      // Set up basic message handlers
      await _setupMessageHandlers();

      _initialized = true;
      debugPrint('✅ Simple Notification Service initialized');
    } catch (e) {
      debugPrint('❌ Error initializing Simple Notification Service: $e');
    }
  }

  /// Check if notifications are enabled and ready
  bool get isReady => _initialized && _permissionGranted;

  /// Get current FCM token
  String? get fcmToken => _fcmToken;

  /// Request notification permissions from user
  Future<bool> requestPermissions() async {
    try {
      debugPrint('🔐 Requesting notification permissions...');

      // Request FCM permissions
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );

      _permissionGranted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      debugPrint('📱 Permission granted: $_permissionGranted');

      // Request Android 13+ local notification permissions if needed
      if (Platform.isAndroid && _permissionGranted) {
        await _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
      }

      return _permissionGranted;
    } catch (e) {
      debugPrint('❌ Error requesting permissions: $e');
      return false;
    }
  }

  /// Send a flow alert notification
  Future<bool> sendFlowAlert(FlowAlert alert) async {
    if (!isReady) {
      debugPrint('⚠️ Cannot send notification - service not ready');
      return false;
    }

    try {
      debugPrint('📤 Sending flow alert for ${alert.riverName}...');

      // For testing/demo - send local notification immediately
      // In production, this would be handled by Cloud Functions
      await _showLocalNotification(
        title: alert.notificationTitle,
        body: alert.notificationBody,
        data: alert.notificationData,
        priority: alert.severity.notificationPriority,
      );

      debugPrint('✅ Flow alert sent successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error sending flow alert: $e');
      return false;
    }
  }

  /// Send a test notification (for user testing)
  Future<bool> sendTestNotification({
    required String riverName,
    required String testType,
  }) async {
    if (!isReady) {
      debugPrint('⚠️ Cannot send test notification - service not ready');
      return false;
    }

    try {
      await _showLocalNotification(
        title: 'Test Alert: $riverName',
        body:
            'This is a test $testType notification for river flow monitoring.',
        data: {'type': 'test', 'riverName': riverName, 'testType': testType},
        priority: 'default',
      );

      debugPrint('✅ Test notification sent');
      return true;
    } catch (e) {
      debugPrint('❌ Error sending test notification: $e');
      return false;
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false, // We'll request this manually
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// Request initial permissions
  Future<void> _requestPermissions() async {
    await requestPermissions();
  }

  /// Get FCM token for this device
  Future<void> _getFCMToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      debugPrint('📱 FCM Token: ${_fcmToken?.substring(0, 20)}...');

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((token) {
        _fcmToken = token;
        debugPrint('🔄 FCM Token refreshed');
        // TODO: Update token in Firestore for this user
      });
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
    }
  }

  /// Set up basic message handlers
  Future<void> _setupMessageHandlers() async {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Handle notification taps when app was completely closed
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // Configure foreground notification options
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    required Map<String, String> data,
    required String priority,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'flow_alerts',
      'Flow Alerts',
      channelDescription: 'Notifications for river flow alerts',
      importance: _getAndroidImportance(priority),
      priority: _getAndroidPriority(priority),
      icon: '@mipmap/ic_launcher',
      color: _getNotificationColor(data['severity']),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      notificationDetails,
      payload: data.toString(),
    );
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📨 Foreground message: ${message.notification?.title}');

    // Show local notification for foreground messages
    if (message.notification != null) {
      _showLocalNotification(
        title: message.notification!.title ?? 'Flow Alert',
        body: message.notification!.body ?? 'Check your river conditions',
        data: message.data.cast<String, String>(),
        priority: message.data['priority'] ?? 'default',
      );
    }
  }

  /// Handle notification taps
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('👆 Notification tapped: ${message.data}');

    // TODO: Navigate to specific river page if riverId is provided
    final riverId = message.data['riverId'];
    if (riverId != null) {
      // Navigate to river details page
      // This will be implemented when we integrate with navigation
    }
  }

  /// Handle local notification taps
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('👆 Local notification tapped: ${response.payload}');

    // TODO: Parse payload and navigate appropriately
    // This will be implemented when we integrate with navigation
  }

  /// Get Android importance level
  Importance _getAndroidImportance(String priority) {
    switch (priority) {
      case 'max':
        return Importance.max;
      case 'high':
        return Importance.high;
      case 'default':
      default:
        return Importance.defaultImportance;
    }
  }

  /// Get Android priority level
  Priority _getAndroidPriority(String priority) {
    switch (priority) {
      case 'max':
        return Priority.max;
      case 'high':
        return Priority.high;
      case 'default':
      default:
        return Priority.defaultPriority;
    }
  }

  /// Get notification color based on severity
  Color? _getNotificationColor(String? severity) {
    switch (severity) {
      case 'moderate':
        return Colors.blue;
      case 'significant':
        return Colors.orange;
      case 'major':
        return Colors.deepOrange;
      case 'severe':
        return Colors.red;
      case 'extreme':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }

  /// Dispose resources
  void dispose() {
    // Clean up if needed
    debugPrint('🧹 Simple Notification Service disposed');
  }
}

/// Top-level function for background message handling
/// This must be outside the class for Firebase to call it
@pragma('vm:entry-point')
Future<void> simpleNotificationBackgroundHandler(RemoteMessage message) async {
  debugPrint('📨 Background message: ${message.notification?.title}');
  // Handle background processing if needed
  // For now, just log the message
}
