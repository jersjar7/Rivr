// lib/features/auth/presentation/pages/login_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../../../../core/widgets/live_validation_field.dart';
import '../../../../core/widgets/managed_async_button.dart';
import '../../../../core/widgets/enhanced_error_display.dart';
import '../../../../core/network/connection_monitor.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/validators/password_validator.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback onRegisterTap;

  const LoginPage({super.key, required this.onRegisterTap});

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _obscureText = true;
  final _formKey = GlobalKey<FormState>();
  bool attempted = false; // Track if login was attempted

  @override
  void initState() {
    super.initState();

    // Pre-fill fields in debug mode
    // assert(() {
    //   _emailController.text = 'test@example.com';
    //   _passwordController.text = 'Password123!';
    //   return true;
    // }());
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  // Validate form fields
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  // Updated password validation using the PasswordValidator
  String? _validatePassword(String? value) {
    return PasswordValidator.validateForLogin(value);
  }

  Future<void> _login() async {
    // Clear previous error messages
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.clearMessages();

    setState(() {
      attempted = true;
    });

    // Run validation manually first
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check network connection
    final connectionMonitor = Provider.of<ConnectionMonitor>(
      context,
      listen: false,
    );
    if (!connectionMonitor.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No internet connection. Please check your network.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final user = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (user != null && mounted) {
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login successful!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );

      // Navigate to favorites page
      Navigator.of(context).pushReplacementNamed('/favorites');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final connectionMonitor = Provider.of<ConnectionMonitor>(context);

    return Scaffold(
      backgroundColor: Colors.grey[300],
      body: ConnectionAwareWidget(
        offlineBuilder:
            (context, status) => SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const ConnectionStatusBanner(),
                    const SizedBox(height: 20),
                    Image.asset('assets/img/rivr.png', height: 200),
                    const SizedBox(height: 30),
                    NetworkErrorView(
                      isPermanentlyOffline: !status.isConnected,
                      onRetry: () => connectionMonitor.resetOfflineStatus(),
                    ),
                  ],
                ),
              ),
            ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/img/rivr.png', height: 200),
                    const SizedBox(height: 20),

                    const Text(
                      'Sign In',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 25),

                    // Enhanced email field with live validation
                    LiveValidationField(
                      controller: _emailController,
                      focusNode: _emailFocusNode,
                      hintText: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.email,
                      validator: _validateEmail,
                      onChanged: (_) {
                        // Clear auth provider errors when user types
                        if (authProvider.errorMessage.isNotEmpty) {
                          authProvider.clearMessages();
                        }
                      },
                    ),

                    // Enhanced password field with live validation
                    LiveValidationField(
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      hintText: 'Password',
                      obscureText: _obscureText,
                      prefixIcon: Icons.lock,
                      validator: _validatePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureText
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureText = !_obscureText;
                          });
                        },
                      ),
                      onChanged: (_) {
                        // Clear auth provider errors when user types
                        if (authProvider.errorMessage.isNotEmpty) {
                          authProvider.clearMessages();
                        }
                      },
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 25.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(context, '/forgot-password');
                            },
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Enhanced error display with recovery suggestions
                    if (authProvider.errorMessage.isNotEmpty)
                      EnhancedErrorDisplay(
                        message: authProvider.errorMessage,
                        recoverySuggestion:
                            ErrorRecoverySuggestions.getForAuthError(
                              authProvider.errorMessage,
                            ),
                        collapsible: true,
                      ),

                    const SizedBox(height: 20),

                    // Managed async button for login
                    ManagedAsyncButton(
                      text: 'Sign In',
                      loadingText: 'Signing in...',
                      isLoading: authProvider.isLoading,
                      onPressed: _login,
                      icon: const Icon(Icons.login, color: Colors.white),
                    ),

                    const SizedBox(height: 30),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Not a member? '),
                        GestureDetector(
                          onTap: widget.onRegisterTap,
                          child: const Text(
                            'Register now',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
