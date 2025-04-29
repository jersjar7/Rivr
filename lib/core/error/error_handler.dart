// lib/core/error/error_handler.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'app_exception.dart';

/// Central error handling logic for the app
class ErrorHandler {
  // Convert any error to an appropriate AppException
  static AppException handleError(dynamic error, {String? context}) {
    // Log error for debugging
    print('ERROR${context != null ? ' [$context]' : ''}: $error');

    // Already an AppException
    if (error is AppException) {
      return error;
    }

    // Handle network-related errors
    if (error is SocketException) {
      return NetworkException.noConnection(originalError: error);
    }

    if (error is HttpException) {
      return NetworkException(
        message: 'HTTP Error: ${error.message}',
        originalError: error,
      );
    }

    if (error is FormatException) {
      return DataException.parseError(
        details: error.message,
        originalError: error,
      );
    }

    if (error is TimeoutException) {
      return NetworkException.timeout(originalError: error);
    }

    // For any other type of error, wrap as unexpected
    return UnexpectedException(
      message: error?.toString() ?? 'An unexpected error occurred',
      originalError: error,
    );
  }

  // Get a user-friendly message for any exception
  static String getUserFriendlyMessage(dynamic error) {
    final exception = error is AppException ? error : handleError(error);

    // Network errors
    if (exception is NetworkException) {
      if (exception.isConnectionIssue) {
        return 'Please check your internet connection and try again.';
      }

      if (exception.statusCode != null) {
        switch (exception.statusCode) {
          case 401:
            return 'Your session has expired. Please log in again.';
          case 403:
            return 'You don\'t have permission to access this resource.';
          case 404:
            return 'The requested resource was not found.';
          case 500:
          case 502:
          case 503:
            return 'Server error. Please try again later.';
          default:
            return 'Network error (${exception.statusCode}). Please try again.';
        }
      }

      return 'Network error. Please try again.';
    }

    // Auth errors
    if (exception is AuthException) {
      return exception.message;
    }

    // Data errors
    if (exception is DataException) {
      if (exception.code == 'not_found') {
        return exception.message;
      }
      return 'There was a problem with the data. Please try again.';
    }

    // Default message for other errors
    return 'Something went wrong. Please try again.';
  }

  // Get a recovery suggestion for the error
  static String? getRecoverySuggestion(dynamic error) {
    final exception = error is AppException ? error : handleError(error);

    if (exception is NetworkException && exception.isConnectionIssue) {
      return 'Check your WiFi or mobile data connection and try again.';
    }

    if (exception is AuthException && exception.code == 'token_expired') {
      return 'Please sign in again to continue.';
    }

    if (exception is DataException && exception.code == 'parse_error') {
      return 'The data format might have changed. Try updating the app.';
    }

    // No specific suggestion for other errors
    return null;
  }

  // Show appropriate error UI based on the exception
  static void showErrorSnackbar(
    BuildContext context,
    dynamic error, {
    bool showRetry = false,
    VoidCallback? onRetry,
    Duration duration = const Duration(seconds: 4),
  }) {
    final exception = error is AppException ? error : handleError(error);

    final message = getUserFriendlyMessage(exception);
    final suggestion = getRecoverySuggestion(exception);

    final snackBar = SnackBar(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          if (suggestion != null)
            Text(
              suggestion,
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
        ],
      ),
      action:
          showRetry && onRetry != null
              ? SnackBarAction(label: 'Retry', onPressed: onRetry)
              : null,
      duration: duration,
      backgroundColor: _getErrorColor(exception),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  // Get appropriate color for the error type
  static Color _getErrorColor(AppException exception) {
    if (exception is NetworkException) {
      return Colors.orange.shade800;
    }

    if (exception is AuthException) {
      return Colors.red.shade800;
    }

    if (exception is DataException) {
      return Colors.amber.shade900;
    }

    return Colors.red.shade700; // Default error color
  }
}
