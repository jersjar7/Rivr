// lib/app.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/di/service_locator.dart';
import 'core/navigation/app_router.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/forecast/presentation/providers/forecast_provider.dart';
import 'features/forecast/presentation/providers/return_period_provider.dart';
import 'common/providers/reach_provider.dart';

class RivrApp extends StatelessWidget {
  const RivrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => sl<AuthProvider>()),
        ChangeNotifierProvider(create: (_) => sl<ForecastProvider>()),
        ChangeNotifierProxyProvider<ForecastProvider, ReturnPeriodProvider>(
          create: (_) => sl<ReturnPeriodProvider>(),
          update:
              (_, forecastProvider, previousReturnPeriodProvider) =>
                  previousReturnPeriodProvider!
                    ..updateForecastProvider(forecastProvider),
        ),
        ChangeNotifierProvider(create: (_) => ReachProvider()),
        // Add other providers here
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
      ),
    );
  }
}
