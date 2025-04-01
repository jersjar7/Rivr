// lib/features/auth/presentation/pages/register_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/network/connection_monitor.dart';
import '../../../../core/validators/password_validator.dart'; // Add this import

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
  bool _obscureText = true;
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;

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

  // Updated to use the PasswordValidator
  String? _validatePassword(String? value) {
    return PasswordValidator.validate(value);
  }

  // Updated to use the PasswordValidator for confirmation
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
    if (!_formKey.currentState!.validate()) {
      // Form has errors
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

    setState(() {
      _submitting = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final user = await authProvider.register(
      _emailController.text.trim(),
      _passwordController.text.trim(),
      _firstNameController.text.trim(),
      _lastNameController.text.trim(),
      _professionController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _submitting = false;
      });

      if (user != null) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration successful! Logging you in...'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );

        // Navigate to favorites page
        Navigator.of(context).pushReplacementNamed('/favorites');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: Colors.grey[300],
      body: ConnectionAwareWidget(
        child: SafeArea(
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
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 15),

                    CustomTextField(
                      controller: _firstNameController,
                      hintText: 'First Name',
                      prefixIcon: Icons.person,
                      validator: _validateName,
                    ),

                    CustomTextField(
                      controller: _lastNameController,
                      hintText: 'Last Name',
                      prefixIcon: Icons.person,
                      validator: _validateName,
                    ),

                    CustomTextField(
                      controller: _professionController,
                      hintText: 'Profession',
                      prefixIcon: Icons.work,
                    ),

                    CustomTextField(
                      controller: _emailController,
                      hintText: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.email,
                      validator: _validateEmail,
                    ),

                    CustomTextField(
                      controller: _passwordController,
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
                      onChanged: (value) {
                        // Force rebuild to update password strength indicator
                        setState(() {});
                      },
                    ),

                    // Add password strength indicator
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 25.0),
                      child: PasswordValidator.buildStrengthIndicator(
                        _passwordController.text,
                      ),
                    ),

                    CustomTextField(
                      controller: _confirmPasswordController,
                      hintText: 'Confirm Password',
                      obscureText: _obscureText,
                      prefixIcon: Icons.lock,
                      validator: _validateConfirmPassword,
                    ),

                    if (authProvider.errorMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 25.0),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  authProvider.errorMessage,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 20),

                    // Registration button with loading state
                    _submitting
                        ? const LoadingIndicator(
                          message: 'Creating your account...',
                          withBackground: true,
                        )
                        : CustomButton(
                          text: 'Register',
                          isLoading: authProvider.isLoading,
                          onPressed: _register,
                        ),

                    const SizedBox(height: 20),

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
