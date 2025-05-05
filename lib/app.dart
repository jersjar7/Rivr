// lib/app.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
        // Note: We don't need to register AuthProvider, FavoritesProvider, ForecastProvider,
        // or ReturnPeriodProvider here because they are already provided in main.dart

        // Add ReachProvider which isn't a global provider
        ChangeNotifierProvider(create: (_) => ReachProvider()),
        // Any other providers that are not registered in main.dart
      ],
      child: Consumer<OfflineManagerService>(
        builder: (context, offlineManager, child) {
          // Initialize offline manager on first build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            offlineManager.refreshCacheStats();
          });

          return MaterialApp(
            title: 'Rivr',
            theme: ThemeData(
              primaryColor: const Color(0xFF2B5876),
              colorScheme: ColorScheme.fromSwatch().copyWith(
                primary: const Color(0xFF2B5876),
                secondary: const Color(0xFF4E4376),
              ),
            ),
            initialRoute: '/',
            onGenerateRoute: AppRouter.generateRoute,
            builder: (context, child) {
              // Add global banners at the top of the app (connection status and offline mode)
              return Column(
                children: [
                  // Network connection banner
                  const ConnectionStatusBanner(),
                  // Offline mode banner
                  const OfflineModeBanner(),
                  // Main content
                  Expanded(child: child!),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
