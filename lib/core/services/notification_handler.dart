// lib/core/services/notification_handler.dart
// Task 4.4: Fixed to integrate with your existing AppRouter structure

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../navigation/app_router.dart';

/// Notification handler integrated with your existing app structure
class NotificationHandler {
  static final NotificationHandler _instance = NotificationHandler._internal();
  factory NotificationHandler() => _instance;
  NotificationHandler._internal();

  // Navigation context - works with your existing navigation
  BuildContext? _context;

  // App state tracking
  AppLifecycleState _currentAppState = AppLifecycleState.resumed;

  // Notification interaction callbacks
  Function(NotificationInteraction)? _onNotificationInteraction;
  Function(RemoteMessage)? _onForegroundMessage;

  /// Initialize with your existing navigation context
  Future<void> initialize({
    required BuildContext context,
    Function(NotificationInteraction)? onInteraction,
    Function(RemoteMessage)? onForegroundMessage,
  }) async {
    _context = context;
    _onNotificationInteraction = onInteraction;
    _onForegroundMessage = onForegroundMessage;

    await _setupMessageHandlers();
    await _setupAppStateTracking();
    await _setupLocalNotifications();

    debugPrint('✅ NotificationHandler initialized with existing AppRouter');
  }

  /// Setup Firebase message handlers for all app states
  Future<void> _setupMessageHandlers() async {
    // 1. FOREGROUND: Handle messages when app is open
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 2. BACKGROUND: Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // 3. TERMINATED: Handle notification taps when app was completely closed
    final RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      debugPrint(
        '🚀 App launched from notification: ${initialMessage.messageId}',
      );
      // Delay to ensure app is fully loaded before navigation
      Future.delayed(const Duration(milliseconds: 1500), () {
        _handleNotificationTap(initialMessage);
      });
    }
  }

  /// Track app lifecycle state for proper notification handling
  Future<void> _setupAppStateTracking() async {
    WidgetsBinding.instance.addObserver(
      _AppLifecycleObserver((state) {
        _currentAppState = state;
        debugPrint('📱 App state changed to: $state');
      }),
    );
  }

  /// Setup local notifications with your app's branding
  Future<void> _setupLocalNotifications() async {
    final FlutterLocalNotificationsPlugin localNotifications =
        FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );
  }

  /// Handle notifications when app is in FOREGROUND
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('📨 Foreground notification received');
    debugPrint('📋 Title: ${message.notification?.title}');
    debugPrint('📄 Body: ${message.notification?.body}');
    debugPrint('📊 Data: ${message.data}');

    // Track reception for thesis metrics
    await _trackNotificationEvent('received_foreground', message);

    // Call external handler if provided
    _onForegroundMessage?.call(message);

    // Show notification based on priority
    final priority = message.data['priority'] ?? 'information';

    if (priority == 'safety') {
      // Safety alerts: Show prominent in-app dialog
      await _showInAppSafetyAlert(message);
    } else {
      // Other alerts: Show as local notification that can be tapped
      await _showLocalNotification(message);
    }
  }

  /// Handle notification taps from BACKGROUND or TERMINATED states
  Future<void> _handleNotificationTap(RemoteMessage message) async {
    debugPrint('👆 Notification tapped - app state: $_currentAppState');
    debugPrint('📋 Message: ${message.notification?.title}');
    debugPrint('📊 Data: ${message.data}');

    // Track interaction for thesis metrics
    await _trackNotificationEvent('tapped', message);

    // Create interaction object for external handling
    final interaction = NotificationInteraction(
      message: message,
      interactionType: 'tap',
      appState: _currentAppState,
      timestamp: DateTime.now(),
    );

    // Call external interaction handler
    _onNotificationInteraction?.call(interaction);

    // Handle deep linking using your existing router
    await _handleDeepLinkNavigation(message.data);
  }

  /// Handle navigation using your existing AppRouter methods
  Future<void> _handleDeepLinkNavigation(Map<String, dynamic> data) async {
    if (_context == null || !_context!.mounted) {
      debugPrint('❌ Context not available for navigation');
      return;
    }

    final deepLink = data['deepLink'] as String?;
    final reachId = data['reachId'] as String?;

    debugPrint(
      '🔗 Processing navigation: deepLink=$deepLink, reachId=$reachId',
    );

    try {
      if (deepLink != null) {
        await _navigateViaDeepLink(deepLink, data);
      } else if (reachId != null) {
        // Direct reach navigation using your existing method
        await AppRouter.navigateToForecast(
          _context!,
          reachId,
          fromNotification: true,
          highlightFlow: true,
          notificationData: data,
        );
      } else {
        // Default: Navigate to notification history
        await AppRouter.navigateToNotificationHistory(_context!);
      }
    } catch (e) {
      debugPrint('❌ Navigation failed: $e');
      // Fallback to home using your existing method
      AppRouter.navigateToHome(_context!);
    }
  }

  /// Navigate based on deep link URL using your AppRouter
  Future<void> _navigateViaDeepLink(
    String deepLink,
    Map<String, dynamic> data,
  ) async {
    final uri = Uri.parse(deepLink);

    switch (uri.host) {
      case 'reach':
        final reachId =
            uri.pathSegments.isNotEmpty ? uri.pathSegments[0] : null;
        if (reachId != null) {
          await AppRouter.navigateToForecast(
            _context!,
            reachId,
            fromNotification: true,
            highlightFlow: true,
            notificationData: data,
          );
        }
        break;

      case 'alerts':
        await AppRouter.navigateToNotificationHistory(
          _context!,
          additionalData: {'fromNotification': true, 'notificationData': data},
        );
        break;

      case 'safety':
        await AppRouter.navigateToSafetyInfo(
          _context!,
          alertLevel: data['category'] ?? 'general',
          reachId: data['reachId'],
          alertData: data,
        );
        break;

      case 'settings':
        if (uri.pathSegments.isNotEmpty &&
            uri.pathSegments[0] == 'notifications') {
          await AppRouter.navigateToNotificationSettings(_context!);
        }
        break;

      case 'test':
        await AppRouter.navigateToNotificationTest(_context!);
        break;

      default:
        debugPrint('🔗 Unknown deep link host: ${uri.host}');
        AppRouter.navigateToHome(_context!);
    }
  }

  /// Show prominent in-app safety alert dialog
  Future<void> _showInAppSafetyAlert(RemoteMessage message) async {
    if (_context == null || !_context!.mounted) return;

    return showDialog<void>(
      context: _context!,
      barrierDismissible: false, // Must tap button to dismiss
      builder: (BuildContext context) {
        return AlertDialog(
          icon: const Icon(Icons.warning, color: Colors.red, size: 48),
          title: Text(
            message.notification?.title ?? 'Safety Alert',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message.notification?.body ?? 'Check flow conditions'),
              const SizedBox(height: 16),
              const Text(
                'Tap "View Details" to see current conditions.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Dismiss'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleDeepLinkNavigation(message.data);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'View Details',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Show local notification for non-critical alerts
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final FlutterLocalNotificationsPlugin localNotifications =
        FlutterLocalNotificationsPlugin();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'rivr_flow_alerts',
          'Flow Alerts',
          channelDescription: 'River flow condition notifications',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          enableVibration: true,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      message.notification?.title ?? 'Flow Update',
      message.notification?.body ?? 'Tap to view details',
      notificationDetails,
      payload: json.encode(message.data),
    );
  }

  /// Handle local notification taps
  Future<void> _onLocalNotificationTap(NotificationResponse response) async {
    debugPrint('👆 Local notification tapped: ${response.id}');

    if (response.payload != null) {
      try {
        final data = json.decode(response.payload!) as Map<String, dynamic>;

        // Track interaction
        await _trackNotificationEvent('local_notification_tapped', null, data);

        // Handle navigation
        await _handleDeepLinkNavigation(data);
      } catch (e) {
        debugPrint('❌ Error parsing local notification payload: $e');
      }
    }
  }

  /// Track notification events for thesis metrics
  Future<void> _trackNotificationEvent(
    String eventType,
    RemoteMessage? message, [
    Map<String, dynamic>? localData,
  ]) async {
    try {
      final Map<String, dynamic> metrics = {
        'eventType': eventType,
        'messageId': message?.messageId ?? 'local',
        'title': message?.notification?.title ?? localData?['title'],
        'category': message?.data['category'] ?? localData?['category'],
        'priority': message?.data['priority'] ?? localData?['priority'],
        'appState': _currentAppState.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };

      debugPrint('📊 Notification event tracked: $eventType');

      // TODO: Store in Firestore for thesis analysis
      // This integrates with your existing Firestore structure
    } catch (e) {
      debugPrint('❌ Error tracking notification event: $e');
    }
  }

  /// Update context (for navigation state changes)
  void updateContext(BuildContext context) {
    _context = context;
  }

  /// Test notification interactions (for development)
  Future<void> testNotificationInteractions() async {
    if (_context == null) {
      debugPrint('❌ Context not available for testing');
      return;
    }

    debugPrint('🧪 Testing notification interactions...');

    // Test different navigation scenarios
    final testScenarios = [
      {
        'name': 'Reach Navigation',
        'data': {
          'reachId': 'test-reach-001',
          'category': 'High',
          'priority': 'safety',
        },
      },
      {
        'name': 'Notification History',
        'data': {'deepLink': 'rivr://alerts', 'priority': 'information'},
      },
      {
        'name': 'Settings Navigation',
        'data': {
          'deepLink': 'rivr://settings/notifications',
          'priority': 'information',
        },
      },
    ];

    for (final scenario in testScenarios) {
      debugPrint('🔗 Testing: ${scenario['name']}');

      // Simulate navigation
      await _handleDeepLinkNavigation(scenario['data'] as Map<String, dynamic>);

      // Wait between tests
      await Future.delayed(const Duration(seconds: 2));
    }

    debugPrint('✅ Notification interaction tests completed');
  }
}

/// Notification interaction data class for external handling
class NotificationInteraction {
  final RemoteMessage message;
  final String interactionType;
  final AppLifecycleState appState;
  final DateTime timestamp;

  const NotificationInteraction({
    required this.message,
    required this.interactionType,
    required this.appState,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'messageId': message.messageId,
      'title': message.notification?.title,
      'interactionType': interactionType,
      'appState': appState.toString(),
      'timestamp': timestamp.toIso8601String(),
      'data': message.data,
    };
  }
}

/// App lifecycle observer for state tracking
class _AppLifecycleObserver with WidgetsBindingObserver {
  final Function(AppLifecycleState) onStateChanged;

  _AppLifecycleObserver(this.onStateChanged);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    onStateChanged(state);
  }
}
