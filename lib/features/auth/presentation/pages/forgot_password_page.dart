// lib/features/auth/presentation/pages/forgot_password_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/live_validation_field.dart';
import '../widgets/managed_async_button.dart';
import '../widgets/enhanced_error_display.dart';
import '../../../../core/network/connection_monitor.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ForgotPasswordPageState createState() => ForgotPasswordPageState();
}

class ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // Email validation
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }

    // More thorough email validation
    final emailRegex = RegExp(
      r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$',
    );

    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check network connection
    final connectionMonitor = Provider.of<ConnectionMonitor>(
      context,
      listen: false,
    );

    if (!connectionMonitor.isConnected) {
      if (mounted) {
        final theme = Theme.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'No internet connection. Please check your network.',
            ),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.clearMessages();

    final success = await authProvider.sendPasswordResetEmail(
      _emailController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _emailSent = success;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.onSurface),
      ),
      body: ConnectionAwareWidget(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/img/rivr.png', height: 180),
                    const SizedBox(height: 20),

                    Text('Reset Password', style: textTheme.headlineMedium),
                    const SizedBox(height: 10),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 25.0),
                      child: Text(
                        "We'll send you a password reset link to your email",
                        textAlign: TextAlign.center,
                        style: textTheme.bodyLarge,
                      ),
                    ),
                    const SizedBox(height: 25),

                    // If email was sent successfully, show success state
                    if (_emailSent)
                      _buildSuccessState()
                    else
                      Column(
                        children: [
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

                          if (authProvider.errorMessage.isNotEmpty)
                            EnhancedErrorDisplay(
                              message: authProvider.errorMessage,
                              recoverySuggestion:
                                  "Double-check your email address or try another email if you have multiple accounts.",
                            ),

                          if (authProvider.successMessage.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 25.0,
                                vertical: 8.0,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colors.secondary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: colors.secondary.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline,
                                      color: colors.secondary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        authProvider.successMessage,
                                        style: TextStyle(
                                          color: colors.secondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          const SizedBox(height: 20),

                          // Submit button with loading state
                          ManagedAsyncButton(
                            text: 'Send Reset Link',
                            loadingText: 'Sending...',
                            isLoading: authProvider.isLoading,
                            onPressed: _sendResetLink,
                            icon: Icon(
                              Icons.email_outlined,
                              color: colors.onPrimary,
                            ),
                            color: colors.primary,
                            textColor: colors.onPrimary,
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

  Widget _buildSuccessState() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.secondary),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: colors.secondary,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  'Password Reset Email Sent',
                  style: textTheme.titleLarge?.copyWith(
                    color: colors.secondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'We have sent a password reset link to your email address. Please check your inbox (and spam folder) to reset your password.',
                  style: textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Email: ${_emailController.text}',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Back to Login'),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _emailSent = false;
              });
            },
            icon: Icon(Icons.refresh, size: 16, color: colors.primary),
            label: Text(
              'Try another email',
              style: TextStyle(color: colors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
