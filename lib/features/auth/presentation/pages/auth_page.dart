// lib/features/auth/presentation/pages/auth_page.dart
import 'package:flutter/material.dart';
import 'login_page.dart';
import 'register_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  _AuthPageState createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _showLoginPage = true;

  void _toggleView() {
    setState(() {
      _showLoginPage = !_showLoginPage;
    });
  }

  // Add this method to handle successful authentication
  void _onAuthSuccess() {
    // Navigate to favorites page after successful authentication
    // This replaces the entire navigation stack to prevent going back to login
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil('/favorites', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_showLoginPage) {
      return LoginPage(
        onRegisterTap: _toggleView,
        onLoginSuccess: _onAuthSuccess, // Pass the callback to LoginPage
      );
    } else {
      return RegisterPage(
        onLoginTap: _toggleView,
        onRegisterSuccess: _onAuthSuccess, // Pass the callback to RegisterPage
      );
    }
  }
}
