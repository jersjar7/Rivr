// lib/core/navigation/app_router.dart
import 'package:flutter/material.dart';
import '../../features/auth/presentation/pages/auth_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/favorites/presentation/pages/favorites_page.dart';
import '../../features/map/presentation/pages/map_page.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../../features/forecast/presentation/pages/forecast_page.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => const SplashPage());
      case '/auth':
        return MaterialPageRoute(builder: (_) => const AuthPage());
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
        return MaterialPageRoute(
          builder:
              (_) =>
                  MapPage(lat: args?['lat'] ?? 0.0, lon: args?['lon'] ?? 0.0),
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
