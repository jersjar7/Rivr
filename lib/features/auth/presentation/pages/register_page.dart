// lib/features/auth/presentation/pages/register_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../../../../core/widgets/live_validation_field.dart';
import '../../../../core/widgets/managed_async_button.dart';
import '../../../../core/widgets/enhanced_error_display.dart';
import '../../../../core/network/connection_monitor.dart';
import '../../../../core/validators/password_validator.dart';

class RegisterPage extends StatefulWidget {
  final VoidCallback onLoginTap;

  const RegisterPage({super.key, required this.onLoginTap});

  @override
  RegisterPageState createState() => RegisterPageState();
}

class RegisterPageState extends State<RegisterPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _professionController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _obscureText = true;
  bool _obscureConfirmText = true;
  bool attempted = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _professionController.dispose();
    super.dispose();
  }

  // Validation methods
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    return PasswordValidator.validate(value);
  }

  String? _validateConfirmPassword(String? value) {
    return PasswordValidator.validateConfirmPassword(
      value,
      _passwordController.text,
    );
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'This field is required';
    }
    return null;
  }

  Future<void> _register() async {
    // Clear previous error messages
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.clearMessages();

    setState(() {
      attempted = true;
    });

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

    final user = await authProvider.register(
      _emailController.text.trim(),
      _passwordController.text.trim(),
      _firstNameController.text.trim(),
      _lastNameController.text.trim(),
      _professionController.text.trim(),
    );

    if (user != null && mounted) {
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration successful! Logging you in...'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );

      // Navigate to favorites page
      Navigator.of(context).pushReplacementNamed('/map');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: Colors.grey[300],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/img/rivr.png', height: 150),
                  const SizedBox(height: 10),

                  const Text(
                    'Register',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
                  ),
                  const SizedBox(height: 15),

                  // Personal information fields
                  LiveValidationField(
                    controller: _firstNameController,
                    hintText: 'First Name',
                    prefixIcon: Icons.person,
                    validator: _validateName,
                  ),

                  LiveValidationField(
                    controller: _lastNameController,
                    hintText: 'Last Name',
                    prefixIcon: Icons.person,
                    validator: _validateName,
                  ),

                  LiveValidationField(
                    controller: _professionController,
                    hintText: 'Profession (Optional)',
                    prefixIcon: Icons.work,
                  ),

                  // Account credentials
                  LiveValidationField(
                    controller: _emailController,
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

                  // Password with strength indicator
                  LiveValidationField(
                    controller: _passwordController,
                    hintText: 'Password',
                    obscureText: _obscureText,
                    prefixIcon: Icons.lock,
                    validator: _validatePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureText ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureText = !_obscureText;
                        });
                      },
                    ),
                    onChanged: (value) {
                      // Update confirm password validation when password changes
                      setState(() {});

                      // Clear auth provider errors when user types
                      if (authProvider.errorMessage.isNotEmpty) {
                        authProvider.clearMessages();
                      }
                    },
                  ),

                  // Password strength indicator
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25.0),
                    child: PasswordValidator.buildStrengthIndicator(
                      _passwordController.text,
                    ),
                  ),

                  LiveValidationField(
                    controller: _confirmPasswordController,
                    hintText: 'Confirm Password',
                    obscureText: _obscureConfirmText,
                    prefixIcon: Icons.lock_clock,
                    validator: _validateConfirmPassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmText
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmText = !_obscureConfirmText;
                        });
                      },
                    ),
                  ),

                  // Error display
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

                  // Register button with managed loading state
                  ManagedAsyncButton(
                    text: 'Register',
                    loadingText: 'Creating account...',
                    isLoading: authProvider.isLoading,
                    onPressed: _register,
                    icon: const Icon(Icons.person_add, color: Colors.white),
                  ),

                  const SizedBox(height: 20),

                  // Login link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Already a member? '),
                      GestureDetector(
                        onTap: widget.onLoginTap,
                        child: const Text(
                          'Login now',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
