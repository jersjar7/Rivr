// lib/core/navigation/app_router.dart

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
import '../../features/favorites/presentation/providers/favorites_provider.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/forecast/presentation/providers/forecast_provider.dart';
import '../../features/forecast/presentation/providers/return_period_provider.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
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
              (context) => MultiProvider(
                providers: [
                  ChangeNotifierProvider<FavoritesProvider>(
                    create: (_) => sl<FavoritesProvider>(),
                  ),
                  // Add any other providers needed by FavoritesPage
                  ChangeNotifierProvider<AuthProvider>(
                    create: (_) => sl<AuthProvider>(),
                  ),
                ],
                child: FavoritesPage(
                  lat: args?['lat'] ?? 0.0,
                  lon: args?['lon'] ?? 0.0,
                ),
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
                  // Also add FavoritesProvider if the map page accesses it
                  ChangeNotifierProvider<FavoritesProvider>(
                    create: (context) => sl<FavoritesProvider>(),
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
              (context) => MultiProvider(
                providers: [
                  ChangeNotifierProvider<ForecastProvider>(
                    create: (_) => sl<ForecastProvider>(),
                  ),
                  ChangeNotifierProxyProvider<
                    ForecastProvider,
                    ReturnPeriodProvider
                  >(
                    create: (_) => sl<ReturnPeriodProvider>(),
                    update:
                        (_, forecastProvider, previousReturnPeriodProvider) =>
                            previousReturnPeriodProvider!
                              ..updateForecastProvider(forecastProvider),
                  ),
                ],
                child: ForecastPage(
                  reachId: args['reachId'],
                  stationName: args['stationName'],
                ),
              ),
        );

      // Add a route for after successful authentication - goes to favorites
      case '/auth_success':
        return MaterialPageRoute(
          builder:
              (context) => MultiProvider(
                providers: [
                  ChangeNotifierProvider<FavoritesProvider>(
                    create: (_) => sl<FavoritesProvider>(),
                  ),
                  ChangeNotifierProvider<AuthProvider>(
                    create: (_) => sl<AuthProvider>(),
                  ),
                ],
                child: const FavoritesPage(),
              ),
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
