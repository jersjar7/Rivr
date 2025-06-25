// lib/core/navigation/app_router.dart
// Updated to include Task 4.4 notification handling routes
// while preserving existing offline capabilities and StreamNameService integration

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rivr/features/notifications/presentation/pages/notification_test_page.dart';
import '../di/service_locator.dart';
import '../../features/auth/presentation/pages/auth_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/favorites/presentation/pages/favorites_page.dart';
import '../../features/map/presentation/pages/map_page.dart';
import '../../features/map/presentation/providers/enhanced_clustered_map_provider.dart';
import '../../features/map/presentation/providers/map_provider.dart';
import '../../features/map/presentation/providers/station_provider.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../../features/forecast/presentation/pages/forecast_page.dart';
import '../../features/settings/presentation/pages/biometric_settings_page.dart';
import '../pages/offline_manager_page.dart';
import '../pages/download_current_region_page.dart';
import 'offline_routes.dart';

// Task 4.4: Import new notification pages
import '../../features/notifications/presentation/pages/notification_history_page.dart';
import '../../features/settings/presentation/pages/notification_settings_page.dart';

/// Router class for handling navigation throughout the app
/// Enhanced with Task 4.4 notification handling capabilities
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

  // Task 4.4: New notification routes
  static const String notificationHistory = '/notifications';
  static const String notificationSettings = '/settings/notifications';
  static const String safetyInfo = '/safety-info';
  static const String biometricSettings = '/biometric-settings';
  static const String forgotPassword = '/forgot-password';

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
        // Add a callback parameter for when a station is added to favorites
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

        // Pass only the reachId/stationId as required parameter
        // stationName is now optional - the ForecastPage should fetch the name
        // from StreamNameService using the reachId
        return MaterialPageRoute(
          builder:
              (_) => ForecastPage(
                reachId: args['reachId'],
                // For backward compatibility, still accept stationName if provided
                // but the page should prefer to get it from StreamNameService
                stationName: args['stationName'],
                // Task 4.4: Add notification context support
                fromNotification: args['fromNotification'] ?? false,
                highlightFlow: args['highlightFlow'] ?? false,
                notificationData: args['notificationData'],
              ),
        );

      // Add a route for after successful authentication - goes to favorites
      case authSuccess:
        return MaterialPageRoute(builder: (_) => const FavoritesPage());

      // Offline manager route
      case offlineManager:
        return MaterialPageRoute(builder: (_) => const OfflineManagerPage());

      // Download current region route
      case downloadCurrentRegion:
        return MaterialPageRoute(
          builder: (_) => const DownloadCurrentRegionPage(),
        );

      case notificationTest:
        return MaterialPageRoute(
          builder: (context) => const NotificationTestPage(),
        );

      // Task 4.4: New notification routes
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

      case safetyInfo:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => SafetyInfoPage(arguments: args),
          settings: settings,
        );

      default:
        debugPrint('❌ Unknown route: ${settings.name}');
        return MaterialPageRoute(
          builder:
              (_) => Scaffold(
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
                              _,
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

  // Task 4.4: Navigation helper methods for type safety and convenience

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

  /// Navigate to forecast page (your existing main content page)
  /// Task 4.4: Enhanced to support notification context
  static Future<dynamic> navigateToForecast(
    BuildContext context,
    String reachId, {
    String? stationName,
    bool fromNotification = false,
    bool highlightFlow = false,
    Map<String, dynamic>? notificationData,
  }) {
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

  /// Task 4.4: Navigate to notification history
  static Future<dynamic> navigateToNotificationHistory(
    BuildContext context, {
    String? filterType,
    Map<String, dynamic>? additionalData,
  }) {
    return Navigator.pushNamed(
      context,
      notificationHistory,
      arguments: {
        if (filterType != null) 'filterType': filterType,
        ...?additionalData,
      },
    );
  }

  /// Task 4.4: Navigate to notification settings
  static Future<dynamic> navigateToNotificationSettings(BuildContext context) {
    return Navigator.pushNamed(context, notificationSettings);
  }

  /// Task 4.4: Navigate to safety information
  static Future<dynamic> navigateToSafetyInfo(
    BuildContext context, {
    String? alertLevel,
    String? reachId,
    Map<String, dynamic>? alertData,
  }) {
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

  /// Navigate to notification test page (existing)
  static Future<dynamic> navigateToNotificationTest(BuildContext context) {
    return Navigator.pushNamed(context, notificationTest);
  }

  /// Navigate to offline manager
  static Future<dynamic> navigateToOfflineManager(BuildContext context) {
    return Navigator.pushNamed(context, offlineManager);
  }

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
      safetyInfo,
      biometricSettings,
      forgotPassword,
    ];
    return validRoutes.contains(routeName);
  }

  /// Task 4.4: Get route name for deep linking
  static String? getRouteNameForReach(String reachId) {
    // Your app uses /forecast for reach details
    return forecast;
  }

  /// Task 4.4: Build arguments for reach navigation from notifications
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
}

/// Task 4.4: Placeholder SafetyInfoPage (you can replace with your own implementation)
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
