// lib/features/auth/presentation/pages/login_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../../../../core/widgets/live_validation_field.dart';
import '../../../../core/widgets/managed_async_button.dart';
import '../../../../core/widgets/enhanced_error_display.dart';
import '../../../../core/network/connection_monitor.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/validators/password_validator.dart';
import '../../../../core/theme/app_theme.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback onRegisterTap;
  final VoidCallback? onLoginSuccess; // Add callback for successful login

  const LoginPage({
    super.key,
    required this.onRegisterTap,
    this.onLoginSuccess, // Optional parameter
  });

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
  bool _showBiometricButton = false; // Flag to show biometric button
  bool _isBiometricLoading =
      false; // For biometric authentication loading state
  Map<String, dynamic>?
  _pendingLoginAttempt; // For storing login attempt during offline

  @override
  void initState() {
    super.initState();

    // Check for biometric availability
    _checkBiometricAvailability();

    // Load saved email if available
    _loadSavedEmail();

    // Check if we need to process a pending login attempt
    _checkPendingLoginAttempt();

    // Set up connection monitor callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final connectionMonitor = Provider.of<ConnectionMonitor>(
        context,
        listen: false,
      );
      if (connectionMonitor.justReconnected) {
        _processPendingLoginAttempt();
      }
    });
  }

  Future<void> _checkBiometricAvailability() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final isBiometricAvailable = await authProvider.isBiometricAvailable;
    final isBiometricEnabled = await authProvider.isBiometricEnabled;

    if (mounted) {
      setState(() {
        _showBiometricButton = isBiometricAvailable && isBiometricEnabled;
      });
    }
  }

  Future<void> _loadSavedEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('last_login_email');

      if (savedEmail != null && savedEmail.isNotEmpty && mounted) {
        setState(() {
          _emailController.text = savedEmail;
        });
      }
    } catch (e) {
      // Silently fail - this is a non-critical feature
      print('Error loading saved email: $e');
    }
  }

  Future<void> _saveEmail(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_login_email', email);
    } catch (e) {
      // Silently fail - this is a non-critical feature
      print('Error saving email: $e');
    }
  }

  Future<void> _checkPendingLoginAttempt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasPendingLogin = prefs.getBool('has_pending_login') ?? false;

      if (hasPendingLogin) {
        final email = prefs.getString('pending_login_email') ?? '';
        final password = prefs.getString('pending_login_password') ?? '';

        if (email.isNotEmpty && password.isNotEmpty) {
          _pendingLoginAttempt = {'email': email, 'password': password};

          // Clear the stored pending login
          await prefs.remove('has_pending_login');
          await prefs.remove('pending_login_email');
          await prefs.remove('pending_login_password');
        }
      }
    } catch (e) {
      print('Error checking pending login: $e');
    }
  }

  Future<void> _processPendingLoginAttempt() async {
    if (_pendingLoginAttempt == null) return;

    final email = _pendingLoginAttempt!['email'] as String;
    final password = _pendingLoginAttempt!['password'] as String;

    // Retry the login
    _emailController.text = email;
    _passwordController.text = password;

    // Show a snackbar to inform the user
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Retrying previous login attempt...'),
        duration: Duration(seconds: 2),
      ),
    );

    // Clear pending attempt
    _pendingLoginAttempt = null;

    // Execute login after a short delay
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _login();
      }
    });
  }

  void _storePendingLoginAttempt(String email, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_pending_login', true);
      await prefs.setString('pending_login_email', email);
      await prefs.setString('pending_login_password', password);
    } catch (e) {
      print('Error storing pending login: $e');
    }
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
    print("LOGIN: Starting login process");
    // Clear previous error messages
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.clearMessages();

    print("LOGIN: Cleared messages, setting attempted state");
    setState(() {
      attempted = true;
    });

    // Run validation manually first
    if (!_formKey.currentState!.validate()) {
      print("LOGIN: Form validation failed, returning");
      return;
    }
    print("LOGIN: Form validation successful");

    // Save email for future logins
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    await _saveEmail(email);

    // Check network connection
    final connectionMonitor = Provider.of<ConnectionMonitor>(
      context,
      listen: false,
    );
    if (!connectionMonitor.isConnected) {
      print("LOGIN: Network connection check failed");

      // Store login attempt to retry when connection is available
      _storePendingLoginAttempt(email, password);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No internet connection. Your login will be retried when connection is restored.',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }
    print("LOGIN: Network connection check passed");

    print("LOGIN: Calling authProvider.login");
    final user = await authProvider.login(email, password);
    print(
      "LOGIN: authProvider.login returned, user is ${user != null ? 'not null' : 'null'}",
    );

    if (user != null && mounted) {
      print("LOGIN: User not null and component still mounted");
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login successful!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
      print("LOGIN: SnackBar shown, about to navigate");

      // Use the success callback if provided
      if (widget.onLoginSuccess != null) {
        widget.onLoginSuccess!();
      } else {
        // Default navigation to favorites page
        print("LOGIN: Navigating to favorites page");
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/favorites', (route) => false);
      }
    } else {
      print("LOGIN: User is null or component unmounted");
      if (user == null) {
        print("LOGIN: User is null from authProvider.login");
      }
      if (!mounted) {
        print("LOGIN: Component is not mounted");
      }
    }
  }

  Future<void> _loginWithBiometric() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Set biometric loading state
    setState(() {
      _isBiometricLoading = true;
    });

    try {
      final user = await authProvider.loginWithBiometric();

      if (mounted) {
        setState(() {
          _isBiometricLoading = false;
        });
      }

      if (user != null && mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login successful!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );

        // Use the success callback if provided
        if (widget.onLoginSuccess != null) {
          widget.onLoginSuccess!();
        } else {
          // Default navigation to favorites page
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/favorites', (route) => false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBiometricLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Biometric authentication failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Enhanced method to get detailed recovery suggestions based on error message
  String? _getDetailedRecoverySuggestion(String errorMessage) {
    final lowerCaseError = errorMessage.toLowerCase();

    if (lowerCaseError.contains('wrong password') ||
        lowerCaseError.contains('invalid password')) {
      return 'Double-check your password. If you\'ve forgotten it, use the "Forgot Password" option below.';
    } else if (lowerCaseError.contains('user not found') ||
        lowerCaseError.contains('no user record')) {
      return 'This email isn\'t registered. Check for typos or register for a new account.';
    } else if (lowerCaseError.contains('too many attempts') ||
        lowerCaseError.contains('too many requests')) {
      return 'Too many login attempts. Please wait about 15 minutes before trying again.';
    } else if (lowerCaseError.contains('network') ||
        lowerCaseError.contains('connection')) {
      return 'Check your internet connection and try again. We\'ll retry automatically when connection is restored.';
    } else if (lowerCaseError.contains('disabled')) {
      return 'This account has been disabled. Please contact support for assistance.';
    } else if (lowerCaseError.contains('expired') ||
        lowerCaseError.contains('timeout')) {
      return 'Your login request timed out. Please try again with a better connection.';
    }

    // Use the standard recovery suggestions as fallback
    return ErrorRecoverySuggestions.getForAuthError(errorMessage);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final connectionMonitor = Provider.of<ConnectionMonitor>(context);

    return Scaffold(
      backgroundColor: Colors.grey[300],
      body: ConnectionAwareWidget(
        onReconnect: _processPendingLoginAttempt,
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
                    // Show this if we have a pending login attempt
                    if (_pendingLoginAttempt != null)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'We\'ll try to sign you in automatically when connection is restored.',
                          style: TextStyle(color: Colors.orange.shade800),
                          textAlign: TextAlign.center,
                        ),
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

                    // Enhanced error display with more detailed recovery suggestions
                    if (authProvider.errorMessage.isNotEmpty)
                      EnhancedErrorDisplay(
                        message: authProvider.errorMessage,
                        recoverySuggestion: _getDetailedRecoverySuggestion(
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

                    // Biometric login button with loading state
                    if (_showBiometricButton) ...[
                      const SizedBox(height: 16),
                      _isBiometricLoading
                          ? Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Column(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.primaryColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Verifying biometric...',
                                  style: TextStyle(
                                    color: AppColors.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          )
                          : TextButton.icon(
                            onPressed: _loginWithBiometric,
                            icon: const Icon(Icons.fingerprint, size: 24),
                            label: const Text('Sign in with biometrics'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primaryColor,
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 24,
                              ),
                            ),
                          ),
                    ],

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

                    // Option to setup biometric authentication
                    if (!_showBiometricButton) ...[
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          Navigator.of(
                            context,
                          ).pushNamed('/biometric-settings');
                        },
                        child: const Text('Set up biometric login'),
                      ),
                    ],
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
