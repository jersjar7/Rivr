// lib/features/splash/presentation/pages/splash_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  _SplashPageState createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _checkAuth();

    // Add a timeout as a backup
    Future.delayed(const Duration(seconds: 7), () {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        print("SPLASH: Timeout reached, forcing navigation to auth page");
        Navigator.of(context).pushReplacementNamed('/auth');
      }
    });
  }

  Future<void> _checkAuth() async {
    print("SPLASH: Starting authentication check");
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      print("SPLASH: About to refresh current user");
      // Use a timeout to prevent getting stuck
      await authProvider.refreshCurrentUser().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print("SPLASH: refreshCurrentUser timed out");
          // If timeout occurs, just continue to auth page
          return;
        },
      );

      print(
        "SPLASH: User refresh completed, isAuthenticated=${authProvider.isAuthenticated}",
      );

      if (mounted) {
        print("SPLASH: Component is still mounted, proceeding with navigation");
        // Now check if authenticated and navigate accordingly
        if (authProvider.isAuthenticated) {
          print("SPLASH: User is authenticated, navigating to favorites");
          // Changed from map to favorites
          Navigator.of(context).pushReplacementNamed('/favorites');
        } else {
          print("SPLASH: User is not authenticated, navigating to auth");
          Navigator.of(context).pushReplacementNamed('/auth');
        }
        print("SPLASH: Navigation called");
      }
    } catch (e) {
      print("SPLASH: Exception during auth check: $e");
      if (mounted) {
        // If any error occurs, just go to the auth page
        Navigator.of(context).pushReplacementNamed('/auth');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2B5876),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/img/rivr.png', height: 250),
            const SizedBox(height: 30),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 30),
            const Text(
              'Powered by the National Water Model',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
