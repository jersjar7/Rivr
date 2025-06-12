// lib/core/services/notification_debug_utils.dart
// Debug utilities for testing notification functionality

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rivr/core/services/notification_service.dart';

/// Debug utilities for notification testing and troubleshooting
class NotificationDebugUtils {
  static final NotificationService _notificationService = NotificationService();

  /// Run comprehensive notification system check
  static Future<Map<String, dynamic>> runSystemCheck() async {
    debugPrint('🔍 Running notification system diagnostics...');

    final Map<String, dynamic> results = {
      'timestamp': DateTime.now().toIso8601String(),
      'permissions': {},
      'fcm': {},
      'platform': {},
      'recommendations': [],
    };

    // Check permissions
    results['permissions'] = {
      'granted': _notificationService.permissionGranted,
      'status':
          _notificationService.permissionGranted ? 'OK' : 'NEEDS_PERMISSION',
    };

    // Check FCM token
    results['fcm'] = {
      'tokenAvailable': _notificationService.fcmToken != null,
      'token':
          _notificationService.fcmToken != null
              ? '${_notificationService.fcmToken!.substring(0, 20)}...'
              : null,
      'status': _notificationService.fcmToken != null ? 'OK' : 'NO_TOKEN',
    };

    // Platform-specific checks
    results['platform'] = {
      'isAndroid': defaultTargetPlatform == TargetPlatform.android,
      'isIOS': defaultTargetPlatform == TargetPlatform.iOS,
      'isDebug': kDebugMode,
      'isRelease': kReleaseMode,
    };

    // Generate recommendations
    final List<String> recommendations = [];

    if (!_notificationService.permissionGranted) {
      recommendations.add('Request notification permissions from user');
    }

    if (_notificationService.fcmToken == null) {
      recommendations.add('Ensure Firebase is properly initialized');
      recommendations.add(
        'Check google-services.json/GoogleService-Info.plist',
      );
    }

    if (recommendations.isEmpty) {
      recommendations.add('System appears to be working correctly!');
    }

    results['recommendations'] = recommendations;

    _logSystemCheck(results);
    return results;
  }

  /// Test notification delivery with different scenarios
  static Future<void> runDeliveryTest() async {
    debugPrint('🧪 Running notification delivery test...');

    if (!_notificationService.permissionGranted) {
      debugPrint('❌ Cannot run delivery test - permissions not granted');
      return;
    }

    // Test scenarios matching our alert engine
    final List<Map<String, dynamic>> testScenarios = [
      {
        'name': 'Low Flow Information',
        'title': '📊 Flow Update: Test River',
        'body': 'Low flow conditions (120 cfs). Good for fishing.',
        'category': 'Low',
        'priority': 'information',
        'delay': 1,
      },
      {
        'name': 'Activity Threshold Alert',
        'title': '🎯 Activity Alert: Kayaking Conditions',
        'body': 'Perfect kayaking flows detected (280 cfs)!',
        'category': 'Moderate',
        'priority': 'activity',
        'delay': 3,
      },
      {
        'name': 'Safety Alert',
        'title': '⚠️ Safety Alert: High Flow',
        'body': 'Dangerous conditions (650 cfs). Avoid water activities!',
        'category': 'High',
        'priority': 'safety',
        'delay': 5,
      },
      {
        'name': 'Thesis Demo',
        'title': '🎓 Thesis Demo: NOAA Integration',
        'body': 'Real-time NOAA data integration demonstration.',
        'category': 'Normal',
        'priority': 'demonstration',
        'delay': 7,
      },
    ];

    for (final scenario in testScenarios) {
      debugPrint('📱 Sending test: ${scenario['name']}');

      // Add delay between notifications
      await Future.delayed(Duration(seconds: scenario['delay']));

      await _notificationService.sendTestNotification(
        title: scenario['title'],
        body: scenario['body'],
        category: scenario['category'],
        priority: scenario['priority'],
        reachId: 'test-reach-delivery',
      );
    }

    debugPrint('✅ Delivery test completed - check device for notifications');
  }

  /// Copy FCM token to clipboard for testing
  static Future<void> copyFCMTokenToClipboard() async {
    final String? token = _notificationService.fcmToken;

    if (token == null) {
      debugPrint('❌ No FCM token available to copy');
      return;
    }

    try {
      await Clipboard.setData(ClipboardData(text: token));
      debugPrint('📋 FCM token copied to clipboard');
      debugPrint('🎫 Token: $token');
    } catch (e) {
      debugPrint('❌ Error copying token to clipboard: $e');
    }
  }

  /// Simulate Cloud Function alert for testing
  static Future<void> simulateCloudFunctionAlert() async {
    debugPrint('☁️ Simulating Cloud Function alert...');

    // This simulates the payload that would come from our Cloud Function
    final Map<String, dynamic> simulatedFCMData = {
      'reachId': 'sim-reach-001',
      'flowValue': '450.0',
      'flowUnit': 'cfs',
      'category': 'Elevated',
      'priority': 'activity',
      'timestamp': DateTime.now().toIso8601String(),
      'deepLink': 'rivr://reach/sim-reach-001',
    };

    await _notificationService.sendTestNotification(
      title: '☁️ Simulated Cloud Function Alert',
      body: 'This simulates an alert from your Cloud Function (450 cfs)',
      category: simulatedFCMData['category'],
      priority: simulatedFCMData['priority'],
      reachId: simulatedFCMData['reachId'],
    );

    debugPrint('✅ Cloud Function simulation sent');
    debugPrint('📊 Simulated data: $simulatedFCMData');
  }

  /// Test deep linking functionality
  static Future<void> testDeepLinking() async {
    debugPrint('🔗 Testing deep linking functionality...');

    final List<Map<String, String>> deepLinkTests = [
      {
        'name': 'Reach Deep Link',
        'link': 'rivr://reach/12345',
        'description': 'Should navigate to reach details',
      },
      {
        'name': 'Demo Deep Link',
        'link': 'rivr://demo',
        'description': 'Should navigate to thesis demo screen',
      },
    ];

    for (final test in deepLinkTests) {
      debugPrint('🔗 Testing: ${test['name']} - ${test['link']}');

      await _notificationService.sendTestNotification(
        title: '🔗 Deep Link Test: ${test['name']}',
        body: 'Tap to test ${test['description']}',
        category: 'Normal',
        priority: 'information',
        reachId: 'deep-link-test',
      );

      // Small delay between tests
      await Future.delayed(const Duration(seconds: 2));
    }

    debugPrint('✅ Deep link tests sent - tap notifications to test navigation');
  }

  /// Generate thesis-specific test data
  static Future<void> generateThesisTestData() async {
    debugPrint('🎓 Generating thesis test data...');

    // Simulate different NOAA data scenarios for thesis demonstration
    final List<Map<String, dynamic>> thesisScenarios = [
      {
        'scenario': 'Normal Operations',
        'title': '📊 NOAA Data: Normal Conditions',
        'body': 'Green River: 240 cfs (Normal). Ideal for recreation.',
        'flowValue': 240,
        'category': 'Normal',
      },
      {
        'scenario': 'Snowmelt Peak',
        'title': '📈 NOAA Data: Spring Runoff',
        'body': 'Colorado River: 580 cfs (High). Spring snowmelt peak.',
        'flowValue': 580,
        'category': 'High',
      },
      {
        'scenario': 'Flash Flood Warning',
        'title': '⚠️ NOAA Alert: Flash Flood',
        'body': 'Rapid Creek: 950 cfs (Extreme). Flash flood in progress!',
        'flowValue': 950,
        'category': 'Extreme',
      },
      {
        'scenario': 'Drought Conditions',
        'title': '📉 NOAA Data: Low Water',
        'body': 'Verde River: 45 cfs (Low). Drought conditions persist.',
        'flowValue': 45,
        'category': 'Low',
      },
    ];

    for (int i = 0; i < thesisScenarios.length; i++) {
      final scenario = thesisScenarios[i];

      debugPrint('🎬 Thesis scenario ${i + 1}: ${scenario['scenario']}');

      await Future.delayed(Duration(seconds: i * 3));

      await _notificationService.sendTestNotification(
        title: scenario['title'],
        body: scenario['body'],
        category: scenario['category'],
        priority: 'demonstration',
        reachId: 'thesis-demo-${i + 1}',
      );
    }

    debugPrint('✅ Thesis test data generated');
  }

  /// Log system check results in a readable format
  static void _logSystemCheck(Map<String, dynamic> results) {
    debugPrint('\n${'=' * 50}');
    debugPrint('📊 NOTIFICATION SYSTEM DIAGNOSTICS');
    debugPrint('=' * 50);

    debugPrint('🔔 Permissions: ${results['permissions']['status']}');
    debugPrint('🎫 FCM Token: ${results['fcm']['status']}');
    debugPrint(
      '📱 Platform: ${results['platform']['isAndroid'] ? 'Android' : 'iOS'}',
    );
    debugPrint(
      '🔧 Build Mode: ${results['platform']['isDebug'] ? 'Debug' : 'Release'}',
    );

    debugPrint('\n📋 Recommendations:');
    for (final rec in results['recommendations']) {
      debugPrint('  • $rec');
    }

    debugPrint('=' * 50 + '\n');
  }

  /// Quick status check for development
  static void quickStatusCheck() {
    debugPrint('\n🔍 Quick Notification Status:');
    debugPrint(
      '  Permissions: ${_notificationService.permissionGranted ? '✅' : '❌'}',
    );
    debugPrint(
      '  FCM Token: ${_notificationService.fcmToken != null ? '✅' : '❌'}',
    );
    debugPrint(
      '  Ready: ${_notificationService.permissionGranted && _notificationService.fcmToken != null ? '✅' : '❌'}\n',
    );
  }
}

// Extension to add debug methods to NotificationService
extension NotificationServiceDebug on NotificationService {
  /// Get detailed status for debugging
  Map<String, dynamic> getDebugStatus() {
    return {
      'permissionsGranted': permissionGranted,
      'fcmTokenAvailable': fcmToken != null,
      'fcmTokenPrefix': fcmToken?.substring(0, 20),
      'platform': defaultTargetPlatform.toString(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Print current configuration
  void printConfiguration() {
    debugPrint('\n🔧 NotificationService Configuration:');
    debugPrint(
      '  Permissions: ${permissionGranted ? 'Granted' : 'Not Granted'}',
    );
    debugPrint(
      '  FCM Token: ${fcmToken != null ? 'Available' : 'Not Available'}',
    );
    debugPrint('  Platform: ${defaultTargetPlatform.toString()}');
    debugPrint(
      '  Ready for notifications: ${permissionGranted && fcmToken != null}\n',
    );
  }
}

// Widget for embedding debug controls in development
class NotificationDebugWidget extends StatelessWidget {
  const NotificationDebugWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Only show in debug mode
    if (!kDebugMode) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.yellow.shade100,
        border: Border.all(color: Colors.orange),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '🛠️ Debug: Notification Testing',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _DebugButton(
                label: '🔍 Check',
                onTap: () => NotificationDebugUtils.runSystemCheck(),
              ),
              _DebugButton(
                label: '🧪 Test',
                onTap: () => NotificationDebugUtils.runDeliveryTest(),
              ),
              _DebugButton(
                label: '📋 Copy Token',
                onTap: () => NotificationDebugUtils.copyFCMTokenToClipboard(),
              ),
              _DebugButton(
                label: '🎓 Thesis',
                onTap: () => NotificationDebugUtils.generateThesisTestData(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DebugButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DebugButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.shade200,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}
