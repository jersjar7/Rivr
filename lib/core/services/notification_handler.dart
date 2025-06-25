// lib/core/services/notification_handler.dart
// Task 4.4: Comprehensive Notification Handling System

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Comprehensive notification handling for foreground, background, and deep linking
///
/// This handler extends the existing NotificationService to provide:
/// - Foreground notification processing
/// - Background/terminated state handling
/// - Deep linking to flow screens
/// - Interaction tracking for thesis metrics
class NotificationHandler {
  static final NotificationHandler _instance = NotificationHandler._internal();
  factory NotificationHandler() => _instance;
  NotificationHandler._internal();

  // Navigation context and routing
  GlobalKey<NavigatorState>? _navigatorKey;

  // App state tracking
  AppLifecycleState _currentAppState = AppLifecycleState.resumed;

  // Notification interaction callbacks
  Function(NotificationInteraction)? _onNotificationInteraction;
  Function(RemoteMessage)? _onForegroundMessage;

  /// Initialize the notification handler with navigation context
  Future<void> initialize({
    required GlobalKey<NavigatorState> navigatorKey,
    Function(NotificationInteraction)? onInteraction,
    Function(RemoteMessage)? onForegroundMessage,
  }) async {
    _navigatorKey = navigatorKey;
    _onNotificationInteraction = onInteraction;
    _onForegroundMessage = onForegroundMessage;

    await _setupMessageHandlers();
    await _setupAppStateTracking();

    debugPrint('✅ NotificationHandler initialized');
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
      Future.delayed(const Duration(milliseconds: 1000), () {
        _handleNotificationTap(initialMessage);
      });
    }

    // 4. LOCAL NOTIFICATIONS: Handle taps on local notifications
    await _setupLocalNotificationTap();
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

    // Show in-app notification or local notification based on priority
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

    // Handle deep linking
    await _handleDeepLink(message.data);
  }

  /// Handle deep linking to specific app screens
  Future<void> _handleDeepLink(Map<String, dynamic> data) async {
    if (_navigatorKey?.currentState == null) {
      debugPrint('❌ Navigator not available for deep linking');
      return;
    }

    final navigator = _navigatorKey!.currentState!;
    final deepLink = data['deepLink'] as String?;
    final reachId = data['reachId'] as String?;

    debugPrint('🔗 Processing deep link: $deepLink');

    try {
      if (deepLink != null) {
        await _navigateToDeepLink(navigator, deepLink, data);
      } else if (reachId != null) {
        // Fallback: Navigate to reach details
        await _navigateToReachDetails(navigator, reachId, data);
      } else {
        // Default: Navigate to notifications/alerts section
        await _navigateToNotifications(navigator);
      }
    } catch (e) {
      debugPrint('❌ Deep link navigation failed: $e');
      // Fallback to home screen
      navigator.pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  /// Navigate based on deep link URL
  Future<void> _navigateToDeepLink(
    NavigatorState navigator,
    String deepLink,
    Map<String, dynamic> data,
  ) async {
    final uri = Uri.parse(deepLink);

    switch (uri.host) {
      case 'reach':
        final reachId =
            uri.pathSegments.isNotEmpty ? uri.pathSegments[0] : null;
        if (reachId != null) {
          await _navigateToReachDetails(navigator, reachId, data);
        }
        break;

      case 'demo':
        await _navigateToDemo(navigator);
        break;

      case 'alerts':
        await _navigateToNotifications(navigator);
        break;

      case 'safety':
        await _navigateToSafetyInfo(navigator, data);
        break;

      default:
        debugPrint('🔗 Unknown deep link host: ${uri.host}');
        navigator.pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  /// Navigate to reach details screen
  Future<void> _navigateToReachDetails(
    NavigatorState navigator,
    String reachId,
    Map<String, dynamic> data,
  ) async {
    debugPrint('🌊 Navigating to reach details: $reachId');

    // Navigate to reach details with notification context
    await navigator.pushNamed(
      '/reach-details',
      arguments: {
        'reachId': reachId,
        'fromNotification': true,
        'notificationData': data,
        'highlightFlow': true, // Highlight current flow info
      },
    );
  }

  /// Navigate to thesis demo screen
  Future<void> _navigateToDemo(NavigatorState navigator) async {
    debugPrint('🎓 Navigating to thesis demo');
    await navigator.pushNamed('/demo');
  }

  /// Navigate to notifications/alerts screen
  Future<void> _navigateToNotifications(NavigatorState navigator) async {
    debugPrint('🔔 Navigating to notifications screen');
    await navigator.pushNamed('/notifications');
  }

  /// Navigate to safety information screen
  Future<void> _navigateToSafetyInfo(
    NavigatorState navigator,
    Map<String, dynamic> data,
  ) async {
    debugPrint('⚠️ Navigating to safety information');
    await navigator.pushNamed(
      '/safety-info',
      arguments: {'alertData': data, 'fromNotification': true},
    );
  }

  /// Show prominent in-app safety alert dialog
  Future<void> _showInAppSafetyAlert(RemoteMessage message) async {
    if (_navigatorKey?.currentContext == null) return;

    final context = _navigatorKey!.currentContext!;

    return showDialog<void>(
      context: context,
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
                _handleDeepLink(message.data);
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

  /// Setup local notification tap handling
  Future<void> _setupLocalNotificationTap() async {
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

  /// Handle local notification taps
  Future<void> _onLocalNotificationTap(NotificationResponse response) async {
    debugPrint('👆 Local notification tapped: ${response.id}');

    if (response.payload != null) {
      try {
        final data = json.decode(response.payload!) as Map<String, dynamic>;

        // Track interaction
        await _trackNotificationEvent('local_notification_tapped', null, data);

        // Handle deep linking
        await _handleDeepLink(data);
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
      // final Map<String, dynamic> metrics = {
      //   'eventType': eventType,
      //   'messageId': message?.messageId ?? 'local',
      //   'title': message?.notification?.title ?? localData?['title'],
      //   'category': message?.data['category'] ?? localData?['category'],
      //   'priority': message?.data['priority'] ?? localData?['priority'],
      //   'appState': _currentAppState.toString(),
      //   'timestamp': DateTime.now().toIso8601String(),
      // };

      debugPrint('📊 Notification event tracked: $eventType');

      // TODO: Store in Firestore for thesis analysis
      // await FirebaseFirestore.instance
      //     .collection('thesisMetrics')
      //     .collection('notificationEvents')
      //     .add(metrics);
    } catch (e) {
      debugPrint('❌ Error tracking notification event: $e');
    }
  }

  /// Test notification interactions (for development)
  Future<void> testNotificationInteractions() async {
    debugPrint('🧪 Testing notification interactions...');

    // Test different deep link scenarios
    final testScenarios = [
      {
        'name': 'Reach Deep Link',
        'data': {
          'deepLink': 'rivr://reach/test-reach-001',
          'reachId': 'test-reach-001',
          'category': 'High',
          'priority': 'safety',
        },
      },
      {
        'name': 'Demo Deep Link',
        'data': {'deepLink': 'rivr://demo', 'priority': 'demonstration'},
      },
      {
        'name': 'Safety Alert',
        'data': {
          'deepLink': 'rivr://safety',
          'priority': 'safety',
          'category': 'Extreme',
        },
      },
    ];

    for (final scenario in testScenarios) {
      debugPrint('🔗 Testing: ${scenario['name']}');

      // Simulate notification tap
      await _handleDeepLink(scenario['data'] as Map<String, dynamic>);

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
