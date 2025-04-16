// lib/main.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'core/di/service_locator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  final env = const String.fromEnvironment('ENV', defaultValue: 'development');
  print("MAIN: Loading environment variables from .env.$env");

  try {
    await dotenv.load(fileName: '.env.$env');
    print("MAIN: Environment variables loaded successfully");
    print("MAIN: Available keys: ${dotenv.env.keys.join(', ')}");
  } catch (e) {
    print("MAIN: Error loading environment variables: $e");
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await setupServiceLocator();
  runApp(const RivrApp());
}
