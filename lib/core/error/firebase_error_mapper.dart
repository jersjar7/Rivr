// lib/core/error/firebase_error_mapper.dart
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseErrorMapper {
  /// Maps Firebase Auth error codes to user-friendly error messages
  static String mapAuthError(FirebaseAuthException exception) {
    switch (exception.code) {
      // Authentication errors
      case 'invalid-email':
        return 'The email address is badly formatted.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'This email address is already associated with an account.';
      case 'operation-not-allowed':
        return 'This operation is not allowed. Please contact support.';
      case 'weak-password':
        return 'The password is too weak. Please choose a stronger password.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with the same email but different sign-in credentials.';
      case 'invalid-credential':
        return 'The authentication credential is invalid.';
      case 'invalid-verification-code':
        return 'The verification code is invalid.';
      case 'invalid-verification-id':
        return 'The verification ID is invalid.';
      case 'requires-recent-login':
        return 'This operation requires re-authentication. Please log in again.';
      case 'too-many-requests':
        return 'Too many login attempts. Please try again later.';
      case 'provider-already-linked':
        return 'This provider is already linked to your account.';
      case 'no-such-provider':
        return 'This provider is not linked to your account.';
      case 'network-request-failed':
        return 'A network error occurred. Please check your connection.';
      case 'credential-already-in-use':
        return 'These credentials are already associated with another account.';
      case 'quota-exceeded':
        return 'Operation quota exceeded. Please try again later.';
      default:
        // For unknown error codes, use the message if available
        if (exception.message != null && exception.message!.isNotEmpty) {
          return exception.message!;
        }
        return 'An unknown authentication error occurred. Please try again.';
    }
  }

  /// Provides recovery suggestions based on the error
  static String? getRecoverySuggestion(String errorCode) {
    switch (errorCode) {
      case 'wrong-password':
        return 'Try using the "Forgot Password" option to reset your password.';
      case 'user-not-found':
        return 'Make sure you\'re using the correct email or register for a new account.';
      case 'too-many-requests':
        return 'Wait a few minutes before trying again.';
      case 'network-request-failed':
        return 'Check your internet connection and try again.';
      case 'requires-recent-login':
        return 'Sign out and log back in, then try again.';
      default:
        return null;
    }
  }
}
