// lib/main.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rivr/core/formatters/flow_value_formatter.dart';
import 'package:rivr/core/services/flow_units_service.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'core/di/service_locator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'common/data/local/database_helper.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/favorites/presentation/providers/favorites_provider.dart';
import 'features/forecast/presentation/providers/forecast_provider.dart';
import 'features/forecast/presentation/providers/return_period_provider.dart';
import 'core/services/stream_name_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  final env = const String.fromEnvironment('ENV', defaultValue: 'development');
  print("MAIN: Loading environment variables from .env.$env");

  try {
    // Force reload the environment file and wait for it to complete
    await dotenv.load(fileName: '.env.$env');

    // Verify that we have the token and print its value (helpful for debugging)
    final token = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? 'NOT FOUND';
    final tokenLength = token.length;
    final maskedToken =
        token.isNotEmpty
            ? '${token.substring(0, 5)}...${token.substring(token.length - 5)}'
            : 'EMPTY';

    print("MAIN: Environment variables loaded successfully");
    print("MAIN: MAPBOX_ACCESS_TOKEN = $maskedToken (length: $tokenLength)");
    print("MAIN: Available keys: ${dotenv.env.keys.join(', ')}");
  } catch (e) {
    print("MAIN: Error loading environment variables: $e");
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize database first and ensure all tables exist
  final databaseHelper = DatabaseHelper();
  try {
    final db = await databaseHelper.database;

    // Ensure all required tables are created
    await databaseHelper.ensureAllTablesExist();

    // Check for Geolocations table
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='Geolocations'",
    );
    if (tables.isEmpty) {
      print("MAIN: ERROR! Geolocations table not found in database!");
    } else {
      // Check if there are any records
      final count = await db.rawQuery(
        "SELECT COUNT(*) as count FROM Geolocations",
      );
      print(
        "MAIN: Found ${count.first['count']} stations in Geolocations table",
      );

      // Check column names
      final columns = await db.rawQuery("PRAGMA table_info(Geolocations)");
      print(
        "MAIN: Geolocations table has columns: ${columns.map((c) => c['name']).toList()}",
      );

      // Check first few records if available
      if ((count.first['count'] as int) > 0) {
        final sample = await db.query('Geolocations', limit: 3);
        print("MAIN: Sample records: $sample");
      }
    }
  } catch (e) {
    print("MAIN: Error initializing database: $e");
  }

  await setupServiceLocator();

  // Initialize the StreamNameService and migrate data from favorites
  try {
    print("MAIN: Initializing StreamNameService");
    final streamNameService = sl<StreamNameService>();
    await streamNameService.initialize();

    // Import names from existing favorites
    print("MAIN: Migrating names from existing favorites");
    final favoritesDb = await databaseHelper.database;
    if (await databaseHelper.tableExists(DatabaseHelper.tableFavorites)) {
      final favorites = await favoritesDb.query(DatabaseHelper.tableFavorites);
      if (favorites.isNotEmpty) {
        print("MAIN: Found ${favorites.length} favorites to import");
        await streamNameService.importFromFavorites(favorites);
        print("MAIN: Favorites migration completed");
      } else {
        print("MAIN: No favorites found to import");
      }
    } else {
      print("MAIN: Favorites table does not exist yet, skipping migration");
    }
  } catch (e) {
    print("MAIN: Error initializing StreamNameService: $e");
    // Non-fatal error, continue with app startup
  }

  runApp(
    MultiProvider(
      providers: [
        // Existing providers
        ChangeNotifierProvider<AuthProvider>(create: (_) => sl<AuthProvider>()),
        ChangeNotifierProvider<FavoritesProvider>(
          create: (_) => sl<FavoritesProvider>(),
        ),
        ChangeNotifierProvider<ForecastProvider>(
          create: (_) => sl<ForecastProvider>(),
        ),
        ChangeNotifierProxyProvider<ForecastProvider, ReturnPeriodProvider>(
          create: (_) => sl<ReturnPeriodProvider>(),
          update:
              (_, forecastProvider, previousReturnPeriodProvider) =>
                  previousReturnPeriodProvider!
                    ..updateForecastProvider(forecastProvider),
        ),
        Provider<StreamNameService>(create: (_) => sl<StreamNameService>()),

        ChangeNotifierProvider<FlowUnitsService>(
          create: (_) => sl<FlowUnitsService>(),
        ),
        Provider<FlowValueFormatter>(create: (_) => sl<FlowValueFormatter>()),
      ],
      child: const RivrApp(),
    ),
  );
}
