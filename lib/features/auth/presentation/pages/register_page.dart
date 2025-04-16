// lib/features/auth/presentation/pages/register_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../../../../core/widgets/live_validation_field.dart';
import '../../../../core/widgets/managed_async_button.dart';
import '../../../../core/widgets/enhanced_error_display.dart';
import '../../../../core/network/connection_monitor.dart';
import '../../../../core/validators/password_validator.dart';
import 'package:lottie/lottie.dart'; // New package for animations

class RegisterPage extends StatefulWidget {
  final VoidCallback onLoginTap;

  const RegisterPage({super.key, required this.onLoginTap});

  @override
  RegisterPageState createState() => RegisterPageState();
}

class RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _professionController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  final _firstNameFocusNode = FocusNode();
  final _lastNameFocusNode = FocusNode();
  final _professionFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  bool _obscureText = true;
  bool _obscureConfirmText = true;
  bool _isFirstNameValid = false;
  bool _isLastNameValid = false;
  bool _isEmailValid = false;
  bool _isPasswordValid = false;
  bool _isConfirmPasswordValid = false;

  bool _registrationSuccess = false;
  late AnimationController _successAnimController;

  // Track if field has been edited
  bool _firstNameTouched = false;
  bool _lastNameTouched = false;
  bool _emailTouched = false;
  bool _passwordTouched = false;
  bool _confirmPasswordTouched = false;

  @override
  void initState() {
    super.initState();

    // Set up focus listeners for real-time validation
    _firstNameFocusNode.addListener(_onFirstNameFocusChange);
    _lastNameFocusNode.addListener(_onLastNameFocusChange);
    _emailFocusNode.addListener(_onEmailFocusChange);
    _passwordFocusNode.addListener(_onPasswordFocusChange);
    _confirmPasswordFocusNode.addListener(_onConfirmPasswordFocusChange);

    // Text field change listeners for password strength
    _passwordController.addListener(_updatePasswordStrength);
    _confirmPasswordController.addListener(_updateConfirmPasswordValidation);

    // Success animation controller
    _successAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void dispose() {
    // Dispose controllers
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _professionController.dispose();

    // Dispose focus nodes
    _firstNameFocusNode.removeListener(_onFirstNameFocusChange);
    _lastNameFocusNode.removeListener(_onLastNameFocusChange);
    _emailFocusNode.removeListener(_onEmailFocusChange);
    _passwordFocusNode.removeListener(_onPasswordFocusChange);
    _confirmPasswordFocusNode.removeListener(_onConfirmPasswordFocusChange);

    _firstNameFocusNode.dispose();
    _lastNameFocusNode.dispose();
    _professionFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();

    // Dispose animation controller
    _successAnimController.dispose();

    super.dispose();
  }

  // Focus change listeners for progressive validation
  void _onFirstNameFocusChange() {
    if (!_firstNameFocusNode.hasFocus && !_firstNameTouched) {
      setState(() {
        _firstNameTouched = true;
        _isFirstNameValid = _validateName(_firstNameController.text) == null;
      });
    }
  }

  void _onLastNameFocusChange() {
    if (!_lastNameFocusNode.hasFocus && !_lastNameTouched) {
      setState(() {
        _lastNameTouched = true;
        _isLastNameValid = _validateName(_lastNameController.text) == null;
      });
    }
  }

  void _onEmailFocusChange() {
    if (!_emailFocusNode.hasFocus && !_emailTouched) {
      setState(() {
        _emailTouched = true;
        _isEmailValid = _validateEmail(_emailController.text) == null;
      });
    }
  }

  void _onPasswordFocusChange() {
    if (!_passwordFocusNode.hasFocus && !_passwordTouched) {
      setState(() {
        _passwordTouched = true;
        _isPasswordValid = _validatePassword(_passwordController.text) == null;
      });
    }
  }

  void _onConfirmPasswordFocusChange() {
    if (!_confirmPasswordFocusNode.hasFocus && !_confirmPasswordTouched) {
      setState(() {
        _confirmPasswordTouched = true;
        _isConfirmPasswordValid =
            _validateConfirmPassword(_confirmPasswordController.text) == null;
      });
    }
  }

  // Live update methods
  void _updatePasswordStrength() {
    // Update UI when password changes, regardless of validation
    if (_passwordTouched) {
      setState(() {
        _isPasswordValid = _validatePassword(_passwordController.text) == null;
      });
    }
  }

  void _updateConfirmPasswordValidation() {
    // Update UI when confirm password changes, regardless of validation
    if (_confirmPasswordTouched) {
      setState(() {
        _isConfirmPasswordValid =
            _validateConfirmPassword(_confirmPasswordController.text) == null;
      });
    }
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
    print("REGISTER: Starting registration process");
    // Clear previous error messages
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.clearMessages();

    print("REGISTER: Cleared messages");

    // Mark all fields as touched for validation
    setState(() {
      _firstNameTouched = true;
      _lastNameTouched = true;
      _emailTouched = true;
      _passwordTouched = true;
      _confirmPasswordTouched = true;
    });

    // Run validation manually first
    if (!_formKey.currentState!.validate()) {
      print("REGISTER: Form validation failed, returning");
      return;
    }
    print("REGISTER: Form validation successful");

    // Check network connection
    final connectionMonitor = Provider.of<ConnectionMonitor>(
      context,
      listen: false,
    );
    if (!connectionMonitor.isConnected) {
      print("REGISTER: Network connection check failed");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No internet connection. Please check your network.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    print("REGISTER: Network connection check passed");

    print("REGISTER: Calling authProvider.register");
    try {
      final user = await authProvider.register(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _firstNameController.text.trim(),
        _lastNameController.text.trim(),
        _professionController.text.trim(),
      );
      print(
        "REGISTER: authProvider.register returned, user is ${user != null ? 'not null' : 'null'}",
      );

      if (user != null && mounted) {
        print("REGISTER: User not null and component still mounted");

        // Show success state instead of immediately navigating
        setState(() {
          _registrationSuccess = true;
        });

        // Start success animation
        _successAnimController.forward();

        // Delay navigation to show success animation
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            // Navigate to map page
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/map',
              (route) => false,
              arguments: {'lat': 0.0, 'lon': 0.0},
            );
          }
        });
      } else {
        print("REGISTER: User is null or component unmounted");
        if (user == null) {
          print("REGISTER: User is null from authProvider.register");
        }
        if (!mounted) {
          print("REGISTER: Component is not mounted");
        }
      }
    } catch (e) {
      print("REGISTER: Exception during registration: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Build the success state UI
  Widget _buildSuccessState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Success animation (replace with your preferred Lottie animation)
          Lottie.asset(
            'assets/animations/registration_success.json',
            controller: _successAnimController,
            width: 200,
            height: 200,
            repeat: false,
          ),
          const SizedBox(height: 20),
          const Text(
            'Registration Successful!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Welcome, ${_firstNameController.text}!',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 20),
          const Text(
            'Setting up your account...',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          const CircularProgressIndicator(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // Show success state if registration was successful
    if (_registrationSuccess) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: _buildSuccessState(),
      );
    }

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

                  // Personal information fields with progressive validation
                  LiveValidationField(
                    controller: _firstNameController,
                    hintText: 'First Name',
                    prefixIcon: Icons.person,
                    validator: _validateName,
                    focusNode: _firstNameFocusNode,
                    isValid: _isFirstNameValid,
                    isTouched: _firstNameTouched,
                    onChanged: (value) {
                      setState(() {
                        _firstNameTouched = true;
                        _isFirstNameValid = _validateName(value) == null;
                      });
                    },
                  ),

                  LiveValidationField(
                    controller: _lastNameController,
                    hintText: 'Last Name',
                    prefixIcon: Icons.person,
                    validator: _validateName,
                    focusNode: _lastNameFocusNode,
                    isValid: _isLastNameValid,
                    isTouched: _lastNameTouched,
                    onChanged: (value) {
                      setState(() {
                        _lastNameTouched = true;
                        _isLastNameValid = _validateName(value) == null;
                      });
                    },
                  ),

                  // Profession field with optional styling
                  Stack(
                    children: [
                      LiveValidationField(
                        controller: _professionController,
                        hintText: 'Profession',
                        prefixIcon: Icons.work,
                        focusNode: _professionFocusNode,
                      ),
                      Positioned(
                        top: 8,
                        right: 25,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                          child: const Text(
                            'Optional',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Account credentials with progressive validation
                  LiveValidationField(
                    controller: _emailController,
                    hintText: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.email,
                    validator: _validateEmail,
                    focusNode: _emailFocusNode,
                    isValid: _isEmailValid,
                    isTouched: _emailTouched,
                    onChanged: (value) {
                      setState(() {
                        _emailTouched = true;
                        _isEmailValid = _validateEmail(value) == null;

                        // Clear auth provider errors when user types
                        if (authProvider.errorMessage.isNotEmpty) {
                          authProvider.clearMessages();
                        }
                      });
                    },
                  ),

                  // Password with real-time strength indicator
                  LiveValidationField(
                    controller: _passwordController,
                    hintText: 'Password',
                    obscureText: _obscureText,
                    prefixIcon: Icons.lock,
                    validator: _validatePassword,
                    focusNode: _passwordFocusNode,
                    isValid: _isPasswordValid,
                    isTouched: _passwordTouched,
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
                      setState(() {
                        _passwordTouched = true;
                        _isPasswordValid = _validatePassword(value) == null;

                        // Also update confirm password validation when password changes
                        if (_confirmPasswordTouched) {
                          _isConfirmPasswordValid =
                              _validateConfirmPassword(
                                _confirmPasswordController.text,
                              ) ==
                              null;
                        }

                        // Clear auth provider errors when user types
                        if (authProvider.errorMessage.isNotEmpty) {
                          authProvider.clearMessages();
                        }
                      });
                    },
                  ),

                  // Enhanced password strength indicator with live updates
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Show strength indicator only when user starts typing
                        if (_passwordController.text.isNotEmpty) ...[
                          _buildEnhancedStrengthIndicator(
                            _passwordController.text,
                          ),
                        ],
                      ],
                    ),
                  ),

                  LiveValidationField(
                    controller: _confirmPasswordController,
                    hintText: 'Confirm Password',
                    obscureText: _obscureConfirmText,
                    prefixIcon: Icons.lock_clock,
                    validator: _validateConfirmPassword,
                    focusNode: _confirmPasswordFocusNode,
                    isValid: _isConfirmPasswordValid,
                    isTouched: _confirmPasswordTouched,
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
                    onChanged: (value) {
                      setState(() {
                        _confirmPasswordTouched = true;
                        _isConfirmPasswordValid =
                            _validateConfirmPassword(value) == null;
                      });
                    },
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

  // Enhanced strength indicator that updates in real-time
  Widget _buildEnhancedStrengthIndicator(String password) {
    final strength = PasswordValidator.getPasswordStrength(password);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Password Strength: ${strength.label}',
              style: TextStyle(
                fontSize: 12,
                color: strength.color,
                fontWeight: FontWeight.bold,
              ),
            ),
            // Visual strength indicator (emoji)
            Text(
              _getStrengthEmoji(strength),
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 4),

        // Animated progress bar
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          tween: Tween<double>(begin: 0, end: strength.value),
          builder:
              (context, value, _) => LinearProgressIndicator(
                value: value,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(strength.color),
                minHeight: 5,
              ),
        ),

        const SizedBox(height: 8),

        // Requirements list with live updates
        _buildRequirementsList(password),
      ],
    );
  }

  String _getStrengthEmoji(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.empty:
        return '⚪';
      case PasswordStrength.weak:
        return '😟';
      case PasswordStrength.medium:
        return '😐';
      case PasswordStrength.strong:
        return '😀';
    }
  }

  Widget _buildRequirementsList(String password) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAnimatedRequirementItem(
          'At least ${PasswordValidator.minLength} characters long',
          password.length >= PasswordValidator.minLength,
          _passwordTouched,
        ),
        if (PasswordValidator.requireUppercase)
          _buildAnimatedRequirementItem(
            'Contains uppercase letter',
            PasswordValidator.containsUppercase(password),
            _passwordTouched,
          ),
        if (PasswordValidator.requireLowercase)
          _buildAnimatedRequirementItem(
            'Contains lowercase letter',
            PasswordValidator.containsLowercase(password),
            _passwordTouched,
          ),
        if (PasswordValidator.requireNumber)
          _buildAnimatedRequirementItem(
            'Contains number',
            PasswordValidator.containsNumber(password),
            _passwordTouched,
          ),
        if (PasswordValidator.requireSpecialChar)
          _buildAnimatedRequirementItem(
            'Contains special character',
            PasswordValidator.containsSpecialChar(password),
            _passwordTouched,
          ),
      ],
    );
  }

  Widget _buildAnimatedRequirementItem(
    String text,
    bool isMet,
    bool shouldAnimate,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.only(bottom: 4.0),
      curve: Curves.easeInOut,
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: Icon(
              isMet ? Icons.check_circle : Icons.cancel,
              key: ValueKey<bool>(isMet),
              color: isMet ? Colors.green : Colors.grey,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isMet ? Colors.black87 : Colors.grey.shade700,
              fontWeight: isMet ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
