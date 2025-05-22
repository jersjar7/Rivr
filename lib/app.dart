// lib/app.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rivr/core/providers/theme_provider.dart';
import 'package:rivr/core/theme/app_theme.dart';
import 'core/di/service_locator.dart';
import 'core/navigation/app_router.dart';
import 'core/network/connection_monitor.dart';
import 'core/services/offline_manager_service.dart';
import 'core/widgets/offline_mode_banner.dart';
import 'common/providers/reach_provider.dart';

class RivrApp extends StatelessWidget {
  const RivrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Add ConnectionMonitor
        ChangeNotifierProvider(
          create: (_) => ConnectionMonitor(networkInfo: sl()),
        ),
        // Add OfflineManagerService
        ChangeNotifierProvider(create: (_) => sl<OfflineManagerService>()),
        // Add ReachProvider which isn't a global provider
        ChangeNotifierProvider(create: (_) => ReachProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Rivr',
            theme: primaryTheme,
            darkTheme: darkTheme,
            themeMode: themeProvider.themeMode,
            initialRoute: '/',
            onGenerateRoute: AppRouter.generateRoute,
            builder: (context, child) {
              // Optimize the app layout by using a more efficient structure
              return _OptimizedAppLayout(child: child!);
            },
          );
        },
      ),
    );
  }
}

/// An optimized layout wrapper that minimizes rebuilds
class _OptimizedAppLayout extends StatelessWidget {
  final Widget child;

  const _OptimizedAppLayout({required this.child});

  @override
  Widget build(BuildContext context) {
    // Use a Column with a stack to avoid rebuilding the entire app when connection status changes
    return Column(
      children: [
        // Stack for showing banners without causing full rebuilds
        _ConnectionBannersBar(),
        // Main content
        Expanded(child: child),
      ],
    );
  }
}

/// A dedicated widget for connection banners to isolate rebuilds
class _ConnectionBannersBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        // Optimized banners with state preservation logic
        ConnectionStatusBanner(),
        OfflineModeBanner(),
      ],
    );
  }
}
