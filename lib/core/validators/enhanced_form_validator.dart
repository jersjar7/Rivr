// lib/core/validators/enhanced_form_validator.dart

import 'package:flutter/material.dart';
import 'package:rivr/core/validators/password_validator.dart';

/// Enhanced form validation approach
class EnhancedFormValidator {
  /// Provides real-time validation feedback for form fields
  static FormFieldValidator<String> liveValidator({
    required String Function(String?) baseValidator,
    Duration? debounceDuration,
  }) {
    return (String? value) {
      // Immediate basic validation
      final validationResult = baseValidator(value);

      // If there's an error, return it immediately
      return validationResult;

      // Optional: Add more complex or async validation logic here
      return null;
    };
  }

  /// Creates an error display widget with expandable details
  static Widget buildErrorDisplay(String errorMessage) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _truncateAndFormatErrorMessage(errorMessage),
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// Truncates and formats error messages for better readability
  static String _truncateAndFormatErrorMessage(String message) {
    // Limit message length
    const maxLength = 150;
    final truncatedMessage =
        message.length > maxLength
            ? '${message.substring(0, maxLength)}...'
            : message;

    // Capitalize first letter and ensure proper punctuation
    return truncatedMessage[0].toUpperCase() +
        truncatedMessage.substring(1) +
        (truncatedMessage.endsWith('.') ? '' : '.');
  }

  /// Provides contextual recovery suggestions for common errors
  static String? getRecoverySuggestion(String errorMessage) {
    errorMessage = errorMessage.toLowerCase();

    // Password-related suggestions
    if (errorMessage.contains('password')) {
      return 'Tip: Use a mix of uppercase, lowercase, numbers, and special characters.';
    }

    // Email-related suggestions
    if (errorMessage.contains('email')) {
      return 'Double-check your email format. It should look like example@domain.com';
    }

    // Network-related suggestions
    if (errorMessage.contains('network') ||
        errorMessage.contains('connection')) {
      return 'Check your internet connection and try again.';
    }

    // Authentication-related suggestions
    if (errorMessage.contains('user not found')) {
      return 'No account found. Would you like to register?';
    }

    // Generic fallback
    return null;
  }

  /// Provides a comprehensive loading indicator with optional message
  static Widget buildLoadingIndicator({
    String? message,
    Color? color,
    double size = 50.0,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(color ?? Colors.blue),
              strokeWidth: 4.0,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: color ?? Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Manages loading states to prevent race conditions
  static Future<T> managedAsyncOperation<T>({
    required Future<T> Function() operation,
    required VoidCallback onStart,
    required VoidCallback onComplete,
    VoidCallback? onError,
  }) async {
    try {
      onStart();
      final result = await operation();
      onComplete();
      return result;
    } catch (e) {
      onComplete();
      onError?.call();
      rethrow;
    }
  }
}

// Example usage in form validation
class ImprovedFormField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final bool obscureText;

  const ImprovedFormField({
    super.key,
    required this.controller,
    required this.hintText,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
  });

  @override
  ImprovedFormFieldState createState() => ImprovedFormFieldState();
}

class ImprovedFormFieldState extends State<ImprovedFormField> {
  String? _errorText;
  bool _isValidating = false;

  void _validate(String value) {
    if (widget.validator == null) return;

    setState(() {
      _isValidating = true;
    });

    // Simulate potential async validation
    Future.delayed(const Duration(milliseconds: 300), () {
      final error = widget.validator!(value);
      setState(() {
        _errorText = error;
        _isValidating = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          decoration: InputDecoration(
            hintText: widget.hintText,
            errorText: _errorText,
            suffixIcon:
                _isValidating
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : null,
          ),
          onChanged: _validate,
        ),
        // Optional: Add recovery suggestion
        if (_errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 12),
            child: Text(
              EnhancedFormValidator.getRecoverySuggestion(_errorText!) ?? '',
              style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
