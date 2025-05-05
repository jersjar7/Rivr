// lib/core/navigation/app_router.dart
// Updated to include enhanced favorites components and offline capabilities

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
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
      case '/':
        return MaterialPageRoute(builder: (_) => const SplashPage());

      case '/auth':
        return MaterialPageRoute(builder: (_) => const AuthPage());

      case '/biometric-settings':
        return MaterialPageRoute(builder: (_) => const BiometricSettingsPage());

      case '/forgot-password':
        return MaterialPageRoute(builder: (_) => const ForgotPasswordPage());

      case '/favorites':
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder:
              (_) => FavoritesPage(
                lat: args?['lat'] ?? 0.0,
                lon: args?['lon'] ?? 0.0,
              ),
        );

      case '/map':
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

      case '/forecast':
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder:
              (_) => ForecastPage(
                reachId: args['reachId'],
                stationName: args['stationName'],
              ),
        );

      // Add a route for after successful authentication - goes to favorites
      case '/auth_success':
        return MaterialPageRoute(builder: (_) => const FavoritesPage());

      // Offline manager route
      case '/offline_manager':
        return MaterialPageRoute(builder: (_) => const OfflineManagerPage());

      // Download current region route
      case '/offline/download-current-region':
        return MaterialPageRoute(
          builder: (_) => const DownloadCurrentRegionPage(),
        );

      default:
        return MaterialPageRoute(
          builder:
              (_) => Scaffold(
                body: Center(
                  child: Text('No route defined for ${settings.name}'),
                ),
              ),
        );
    }
  }
}
