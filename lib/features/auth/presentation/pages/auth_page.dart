// lib/features/auth/presentation/pages/auth_page.dart
import 'package:flutter/material.dart';
import 'login_page.dart';
import 'register_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  AuthPageState createState() => AuthPageState();
}

class AuthPageState extends State<AuthPage>
    with SingleTickerProviderStateMixin {
  bool _showLoginPage = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Configure animation for smooth transitions
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleView() {
    setState(() {
      // Restart animation and toggle view
      _animationController.reset();
      _showLoginPage = !_showLoginPage;
      _animationController.forward();
    });
  }

  // Handle successful authentication
  void _onAuthSuccess() {
    // Navigate to favorites page after successful authentication
    // This replaces the entire navigation stack to prevent going back to login
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil('/favorites', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    // Use FadeTransition for smooth page transitions
    return FadeTransition(
      opacity: _fadeAnimation,
      child:
          _showLoginPage
              ? LoginPage(
                onRegisterTap: _toggleView,
                onLoginSuccess: _onAuthSuccess,
              )
              : RegisterPage(
                onLoginTap: _toggleView,
                onRegisterSuccess: _onAuthSuccess,
              ),
    );
  }
}
