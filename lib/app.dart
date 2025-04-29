// lib/app.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/di/service_locator.dart';
import 'core/navigation/app_router.dart';
import 'core/network/connection_monitor.dart';
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
        // Note: We don't need to register AuthProvider, FavoritesProvider, ForecastProvider,
        // or ReturnPeriodProvider here because they are already provided in main.dart

        // Add ReachProvider which isn't a global provider
        ChangeNotifierProvider(create: (_) => ReachProvider()),
        // Any other providers that are not registered in main.dart
      ],
      child: MaterialApp(
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
          // Add global connection status banner at the top of the app
          return Column(
            children: [const ConnectionStatusBanner(), Expanded(child: child!)],
          );
        },
      ),
    );
  }
}
