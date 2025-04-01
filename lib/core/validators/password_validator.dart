// lib/core/validators/password_validator.dart
import 'package:flutter/material.dart';

/// Validates passwords and provides detailed feedback for password requirements
class PasswordValidator {
  /// Minimum required password length
  static const int minLength = 8;

  /// Whether to require at least one uppercase letter
  static const bool requireUppercase = true;

  /// Whether to require at least one lowercase letter
  static const bool requireLowercase = true;

  /// Whether to require at least one number
  static const bool requireNumber = true;

  /// Whether to require at least one special character
  static const bool requireSpecialChar = true;

  /// Validates a password according to all requirements
  /// Returns null if valid, otherwise returns an error message
  static String? validate(String? password) {
    if (password == null || password.isEmpty) {
      return 'Password is required';
    }

    if (password.length < minLength) {
      return 'Password must be at least $minLength characters long';
    }

    if (requireUppercase && !_containsUppercase(password)) {
      return 'Password must contain at least one uppercase letter';
    }

    if (requireLowercase && !_containsLowercase(password)) {
      return 'Password must contain at least one lowercase letter';
    }

    if (requireNumber && !_containsNumber(password)) {
      return 'Password must contain at least one number';
    }

    if (requireSpecialChar && !_containsSpecialChar(password)) {
      return 'Password must contain at least one special character';
    }

    return null;
  }

  /// Validates a password for login (less strict)
  /// Only checks if password is not empty and meets minimum length
  static String? validateForLogin(String? password) {
    if (password == null || password.isEmpty) {
      return 'Password is required';
    }

    if (password.length < minLength) {
      return 'Password must be at least $minLength characters long';
    }

    return null;
  }

  /// Validates password confirmation matches the original password
  static String? validateConfirmPassword(
    String? confirmPassword,
    String? password,
  ) {
    if (confirmPassword == null || confirmPassword.isEmpty) {
      return 'Please confirm your password';
    }

    if (confirmPassword != password) {
      return 'Passwords do not match';
    }

    return null;
  }

  /// Gets a password strength assessment (weak, medium, strong)
  static PasswordStrength getPasswordStrength(String password) {
    if (password.isEmpty) {
      return PasswordStrength.empty;
    }

    int score = 0;

    // Add points for length
    if (password.length >= minLength) score++;
    if (password.length >= 12) score++;

    // Add points for character variety
    if (_containsUppercase(password)) score++;
    if (_containsLowercase(password)) score++;
    if (_containsNumber(password)) score++;
    if (_containsSpecialChar(password)) score++;

    // Convert score to strength
    if (score <= 2) return PasswordStrength.weak;
    if (score <= 4) return PasswordStrength.medium;
    return PasswordStrength.strong;
  }

  /// Displays password strength as a UI indicator
  static Widget buildStrengthIndicator(String password) {
    final strength = getPasswordStrength(password);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Password Strength: ${strength.label}',
              style: TextStyle(
                fontSize: 12,
                color: strength.color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: strength.value,
          backgroundColor: Colors.grey.shade300,
          valueColor: AlwaysStoppedAnimation<Color>(strength.color),
          minHeight: 5,
        ),
        const SizedBox(height: 8),
        if (password.isNotEmpty) _buildRequirementsList(password),
      ],
    );
  }

  /// Builds a list of requirements with check/cross icons
  static Widget _buildRequirementsList(String password) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRequirementItem(
          'At least $minLength characters long',
          password.length >= minLength,
        ),
        if (requireUppercase)
          _buildRequirementItem(
            'Contains uppercase letter',
            _containsUppercase(password),
          ),
        if (requireLowercase)
          _buildRequirementItem(
            'Contains lowercase letter',
            _containsLowercase(password),
          ),
        if (requireNumber)
          _buildRequirementItem('Contains number', _containsNumber(password)),
        if (requireSpecialChar)
          _buildRequirementItem(
            'Contains special character',
            _containsSpecialChar(password),
          ),
      ],
    );
  }

  /// Builds a single requirement item with check/cross icon
  static Widget _buildRequirementItem(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.cancel,
            color: isMet ? Colors.green : Colors.grey,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isMet ? Colors.black87 : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods for checking password criteria
  static bool _containsUppercase(String password) {
    return password.contains(RegExp(r'[A-Z]'));
  }

  static bool _containsLowercase(String password) {
    return password.contains(RegExp(r'[a-z]'));
  }

  static bool _containsNumber(String password) {
    return password.contains(RegExp(r'[0-9]'));
  }

  static bool _containsSpecialChar(String password) {
    return password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
  }
}

/// Enum representing password strength levels
enum PasswordStrength {
  empty(0.0, 'Empty', Colors.grey),
  weak(0.3, 'Weak', Colors.red),
  medium(0.6, 'Medium', Colors.orange),
  strong(1.0, 'Strong', Colors.green);

  final double value;
  final String label;
  final Color color;

  const PasswordStrength(this.value, this.label, this.color);
}
