// lib/main.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'core/di/service_locator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables - First important change
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
  await setupServiceLocator();
  runApp(const RivrApp());
}
