// lib/core/navigation/app_router.dart
// Updated to include Task 4.4 notification handling routes
// Enhanced for thesis demonstration and notification system showcase

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rivr/core/debug/developer_tools_page.dart';
import 'package:rivr/core/di/service_locator.dart';
import 'package:rivr/core/navigation/offline_routes.dart';
import 'package:rivr/core/pages/download_current_region_page.dart';
import 'package:rivr/core/pages/offline_manager_page.dart';
import 'package:rivr/features/auth/presentation/pages/auth_page.dart';
import 'package:rivr/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:rivr/features/favorites/presentation/pages/favorites_page.dart';
import 'package:rivr/features/forecast/presentation/pages/forecast_page.dart';
import 'package:rivr/features/map/presentation/pages/map_page.dart';
import 'package:rivr/features/map/presentation/providers/enhanced_clustered_map_provider.dart';
import 'package:rivr/features/map/presentation/providers/map_provider.dart';
import 'package:rivr/features/map/presentation/providers/station_provider.dart';
import 'package:rivr/features/notifications/presentation/pages/notification_history_page.dart';
import 'package:rivr/features/notifications/presentation/pages/notification_test_page.dart';
import 'package:rivr/features/settings/presentation/pages/biometric_settings_page.dart';
import 'package:rivr/features/settings/presentation/pages/notification_settings_page.dart';
import 'package:rivr/features/splash/presentation/pages/splash_page.dart';

/// Router class for handling navigation throughout the app
/// Enhanced with Task 4.4 notification handling capabilities
/// Optimized for thesis demonstration and notification system showcase
class AppRouter {
  /// Route name constants for type safety
  static const String home = '/';
  static const String auth = '/auth';
  static const String favorites = '/favorites';
  static const String map = '/map';
  static const String forecast = '/forecast';
  static const String authSuccess = '/auth_success';
  static const String offlineManager = '/offline_manager';
  static const String downloadCurrentRegion =
      '/offline/download-current-region';
  static const String notificationTest = '/notification-test';

  // Task 4.4: Notification system routes
  static const String notificationHistory = '/notifications';
  static const String notificationSettings = '/settings/notifications';
  static const String quickAlertDemo = '/demo/quick-alert-setup';
  static const String safetyInfo = '/safety-info';
  static const String biometricSettings = '/biometric-settings';
  static const String forgotPassword = '/forgot-password';
  static const String developerTools = '/dev-tools';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    debugPrint('🧭 Navigating to: ${settings.name}');

    // First check if it's an offline route
    final offlineRoutes = OfflineRoutes.getRoutes();
    if (offlineRoutes.containsKey(settings.name)) {
      return MaterialPageRoute(
        builder: offlineRoutes[settings.name]!,
        settings: settings,
      );
    }

    // Handle other routes
    switch (settings.name) {
      case home:
        return MaterialPageRoute(builder: (_) => const SplashPage());

      case auth:
        return MaterialPageRoute(builder: (_) => const AuthPage());

      case biometricSettings:
        return MaterialPageRoute(builder: (_) => const BiometricSettingsPage());

      case forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordPage());

      case favorites:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder:
              (_) => FavoritesPage(
                lat: args?['lat'] ?? 0.0,
                lon: args?['lon'] ?? 0.0,
              ),
        );

      case map:
        final args = settings.arguments as Map<String, dynamic>?;
        final onStationAddedToFavorites =
            args?['onStationAddedToFavorites'] as Function?;

        return MaterialPageRoute(
          builder:
              (context) => MultiProvider(
                providers: [
                  ChangeNotifierProvider<MapProvider>(
                    create: (context) => sl<MapProvider>(),
                  ),
                  ChangeNotifierProvider<StationProvider>(
                    create: (context) => sl<StationProvider>(),
                  ),
                  ChangeNotifierProvider<EnhancedClusteredMapProvider>(
                    create: (context) => sl<EnhancedClusteredMapProvider>(),
                  ),
                ],
                child: OptimizedMapPage(
                  key: UniqueKey(),
                  lat: args?['lat'] ?? 0.0,
                  lon: args?['lon'] ?? 0.0,
                  onStationAddedToFavorites: onStationAddedToFavorites,
                ),
              ),
        );

      case forecast:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder:
              (_) => ForecastPage(
                reachId: args['reachId'],
                stationName: args['stationName'],
                // Task 4.4: Notification context support
                fromNotification: args['fromNotification'] ?? false,
                highlightFlow: args['highlightFlow'] ?? false,
                notificationData: args['notificationData'],
              ),
        );

      case authSuccess:
        return MaterialPageRoute(builder: (_) => const FavoritesPage());

      case offlineManager:
        return MaterialPageRoute(builder: (_) => const OfflineManagerPage());

      case downloadCurrentRegion:
        return MaterialPageRoute(
          builder: (_) => const DownloadCurrentRegionPage(),
        );

      case notificationTest:
        return MaterialPageRoute(
          builder: (context) => const NotificationTestPage(),
        );

      // Task 4.4: Notification system routes
      case notificationHistory:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => NotificationHistoryPage(arguments: args),
          settings: settings,
        );

      case notificationSettings:
        return MaterialPageRoute(
          builder: (_) => const NotificationSettingsPage(),
          settings: settings,
        );

      case quickAlertDemo:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => QuickAlertDemoPage(arguments: args),
          settings: settings,
        );

      case safetyInfo:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => SafetyInfoPage(arguments: args),
          settings: settings,
        );

      case developerTools:
        return MaterialPageRoute(builder: (_) => const DeveloperToolsPage());

      default:
        debugPrint('❌ Unknown route: ${settings.name}');
        return MaterialPageRoute(
          builder:
              (context) => Scaffold(
                appBar: AppBar(title: const Text('Page Not Found')),
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text('No route defined for ${settings.name}'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed:
                            () => Navigator.pushNamedAndRemoveUntil(
                              context,
                              home,
                              (route) => false,
                            ),
                        child: const Text('Go Home'),
                      ),
                    ],
                  ),
                ),
              ),
        );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NAVIGATION HELPER METHODS - Task 4.4 Enhanced
  // ═══════════════════════════════════════════════════════════════════════════

  /// Navigate to home/splash page
  static Future<dynamic> navigateToHome(BuildContext context) {
    return Navigator.pushNamedAndRemoveUntil(context, home, (route) => false);
  }

  /// Navigate to favorites page
  static Future<dynamic> navigateToFavorites(
    BuildContext context, {
    double lat = 0.0,
    double lon = 0.0,
  }) {
    return Navigator.pushNamed(
      context,
      favorites,
      arguments: {'lat': lat, 'lon': lon},
    );
  }

  /// Navigate to map page
  static Future<dynamic> navigateToMap(
    BuildContext context, {
    double lat = 0.0,
    double lon = 0.0,
    Function? onStationAddedToFavorites,
  }) {
    return Navigator.pushNamed(
      context,
      map,
      arguments: {
        'lat': lat,
        'lon': lon,
        'onStationAddedToFavorites': onStationAddedToFavorites,
      },
    );
  }

  /// Navigate to forecast page - Enhanced for notification context
  static Future<dynamic> navigateToForecast(
    BuildContext context,
    String reachId, {
    String? stationName,
    bool fromNotification = false,
    bool highlightFlow = false,
    Map<String, dynamic>? notificationData,
  }) {
    debugPrint(
      '🔗 Navigating to forecast: $reachId (fromNotification: $fromNotification)',
    );
    return Navigator.pushNamed(
      context,
      forecast,
      arguments: {
        'reachId': reachId,
        'stationName': stationName,
        'fromNotification': fromNotification,
        'highlightFlow': highlightFlow,
        'notificationData': notificationData,
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NOTIFICATION SYSTEM NAVIGATION - Task 4.4
  // ═══════════════════════════════════════════════════════════════════════════

  /// Navigate to notification history page
  static Future<dynamic> navigateToNotificationHistory(
    BuildContext context, {
    String? filterType,
    Map<String, dynamic>? additionalData,
  }) {
    debugPrint('📜 Opening notification history (filter: $filterType)');
    return Navigator.pushNamed(
      context,
      notificationHistory,
      arguments: {
        if (filterType != null) 'filterType': filterType,
        ...?additionalData,
      },
    );
  }

  /// Navigate to notification settings page
  static Future<dynamic> navigateToNotificationSettings(BuildContext context) {
    debugPrint('⚙️ Opening notification settings');
    return Navigator.pushNamed(context, notificationSettings);
  }

  /// Navigate to quick alert demo page (thesis demonstration)
  static Future<dynamic> navigateToQuickAlertDemo(
    BuildContext context, {
    String? preselectedStation,
    Map<String, dynamic>? demoData,
  }) {
    debugPrint('🚧 Opening quick alert demo (station: $preselectedStation)');
    return Navigator.pushNamed(
      context,
      quickAlertDemo,
      arguments: {
        if (preselectedStation != null)
          'preselectedStation': preselectedStation,
        if (demoData != null) 'demoData': demoData,
      },
    );
  }

  /// Navigate to safety information page
  static Future<dynamic> navigateToSafetyInfo(
    BuildContext context, {
    String? alertLevel,
    String? reachId,
    Map<String, dynamic>? alertData,
  }) {
    debugPrint('⚠️ Opening safety info (level: $alertLevel, reach: $reachId)');
    return Navigator.pushNamed(
      context,
      safetyInfo,
      arguments: {
        if (alertLevel != null) 'alertLevel': alertLevel,
        if (reachId != null) 'reachId': reachId,
        if (alertData != null) 'alertData': alertData,
      },
    );
  }

  /// Navigate to notification test page
  static Future<dynamic> navigateToNotificationTest(BuildContext context) {
    debugPrint('🧪 Opening notification test page');
    return Navigator.pushNamed(context, notificationTest);
  }

  /// Navigate to offline manager
  static Future<dynamic> navigateToOfflineManager(BuildContext context) {
    return Navigator.pushNamed(context, offlineManager);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UTILITY METHODS - Task 4.4
  // ═══════════════════════════════════════════════════════════════════════════

  /// Check if a route exists
  static bool routeExists(String routeName) {
    const validRoutes = [
      home,
      auth,
      favorites,
      map,
      forecast,
      authSuccess,
      offlineManager,
      downloadCurrentRegion,
      notificationTest,
      notificationHistory,
      notificationSettings,
      quickAlertDemo,
      safetyInfo,
      biometricSettings,
      forgotPassword,
      developerTools,
    ];
    return validRoutes.contains(routeName);
  }

  /// Get route name for deep linking
  static String? getRouteNameForReach(String reachId) {
    return forecast;
  }

  /// Build arguments for reach navigation from notifications
  static Map<String, dynamic> buildForecastArgsFromNotification({
    required String reachId,
    String? stationName,
    Map<String, dynamic>? notificationData,
  }) {
    return {
      'reachId': reachId,
      'stationName': stationName,
      'fromNotification': true,
      'highlightFlow': true,
      'notificationData': notificationData,
    };
  }

  /// Quick method for thesis demonstrations - navigate with context
  static Future<dynamic> demonstrateNotificationFlow(
    BuildContext context,
    String reachId, {
    String demoType = 'safety',
  }) {
    final Map<String, dynamic> demoData = {
      'demoType': demoType,
      'timestamp': DateTime.now().toIso8601String(),
      'source': 'thesis_demonstration',
    };

    return navigateToForecast(
      context,
      reachId,
      fromNotification: true,
      highlightFlow: true,
      notificationData: demoData,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PLACEHOLDER PAGES FOR THESIS DEMONSTRATION
// ═══════════════════════════════════════════════════════════════════════════

/// Quick Alert Demo Page - Placeholder for thesis demonstration
class QuickAlertDemoPage extends StatelessWidget {
  final Map<String, dynamic>? arguments;

  const QuickAlertDemoPage({super.key, this.arguments});

  @override
  Widget build(BuildContext context) {
    final preselectedStation = arguments?['preselectedStation'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Alert Setup'),
        backgroundColor: Colors.orange.shade50,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.construction,
                  color: Colors.orange.shade700,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  'Demo',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Demo Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.construction, color: Colors.orange.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thesis Demonstration',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'This page demonstrates the custom threshold alert setup interface. '
                          'In the full implementation, users would create personalized flow alerts here.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Mock Form Interface
            const Text(
              'Create Custom Alert',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Station Selection
            const Text(
              'Select Station:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(preselectedStation ?? 'Snake River at Alpine, WY'),
                  const Spacer(),
                  const Icon(Icons.keyboard_arrow_down),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Threshold Input
            const Text(
              'Alert Threshold:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: '1500',
                      border: OutlineInputBorder(),
                      enabled: false,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('CFS'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Activity Type
            const Text(
              'Activity Type:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  label: Text('Fishing'),
                  backgroundColor: Colors.blue.shade100,
                ),
                Chip(label: Text('Kayaking')),
                Chip(label: Text('Rafting')),
                Chip(label: Text('Safety')),
              ],
            ),
            const SizedBox(height: 24),

            // Preview Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Alert Preview',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '"🎣 Fishing Alert: Snake River at Alpine, WY has reached optimal flow of 1,500 CFS"',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            const Spacer(),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Demo: Alert would be created in full implementation',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                      Navigator.of(context).pop();
                    },
                    child: const Text('Create Alert'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Safety Information Page - Enhanced for thesis demonstration
class SafetyInfoPage extends StatelessWidget {
  final Map<String, dynamic>? arguments;

  const SafetyInfoPage({super.key, this.arguments});

  @override
  Widget build(BuildContext context) {
    final alertLevel = arguments?['alertLevel'] ?? 'general';
    final reachId = arguments?['reachId'];
    final alertData = arguments?['alertData'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety Information'),
        backgroundColor: Colors.red.shade100,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Alert Level: ${alertLevel.toUpperCase()}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                  if (reachId != null) ...[
                    const SizedBox(height: 8),
                    Text('Location: $reachId'),
                  ],
                  if (alertData != null) ...[
                    const SizedBox(height: 8),
                    Text('Details: ${alertData.toString()}'),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Important Safety Guidelines:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              '• Always check current conditions before entering the water',
            ),
            const Text(
              '• Never rely solely on notifications for safety decisions',
            ),
            const Text('• Be aware of changing weather and water conditions'),
            const Text(
              '• Inform others of your planned activities and timeline',
            ),
            const Text('• Carry appropriate safety equipment'),
            const SizedBox(height: 24),
            if (reachId != null)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  AppRouter.navigateToForecast(
                    context,
                    reachId,
                    fromNotification: true,
                  );
                },
                child: const Text('View Current Conditions'),
              ),
          ],
        ),
      ),
    );
  }
}
