// lib/core/error/app_exception.dart

/// Base exception class for all application exceptions
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const AppException({required this.message, this.code, this.originalError});

  @override
  String toString() =>
      code != null
          ? 'AppException [$code]: $message'
          : 'AppException: $message';

  // Helper to check if an exception is of a specific type
  static bool isA<T extends AppException>(Exception e) => e is T;
}

/// Network-related exceptions
class NetworkException extends AppException {
  final bool isConnectionIssue;
  final int? statusCode;

  const NetworkException({
    required super.message,
    String? code,
    this.isConnectionIssue = false,
    this.statusCode,
    super.originalError,
  }) : super(code: code ?? 'network_error');

  // Factory constructor for connection issues
  factory NetworkException.noConnection({dynamic originalError}) {
    return NetworkException(
      message: 'No internet connection. Please check your network settings.',
      code: 'no_connection',
      isConnectionIssue: true,
      originalError: originalError,
    );
  }

  // Factory constructor for timeout issues
  factory NetworkException.timeout({int? seconds, dynamic originalError}) {
    return NetworkException(
      message:
          seconds != null
              ? 'Request timed out after $seconds seconds'
              : 'Request timed out',
      code: 'timeout',
      isConnectionIssue: true,
      originalError: originalError,
    );
  }

  // Factory constructor for HTTP status errors
  factory NetworkException.httpError({
    required int statusCode,
    String? message,
    dynamic originalError,
  }) {
    return NetworkException(
      message: message ?? 'HTTP Error: $statusCode',
      code: 'http_$statusCode',
      statusCode: statusCode,
      originalError: originalError,
    );
  }
}

/// Data-related exceptions
class DataException extends AppException {
  const DataException({
    required super.message,
    String? code,
    super.originalError,
  }) : super(code: code ?? 'data_error');

  // Factory constructor for missing data
  factory DataException.notFound({
    String? entityName,
    String? entityId,
    dynamic originalError,
  }) {
    final entity = entityName ?? 'Resource';
    final id = entityId != null ? ' with ID $entityId' : '';

    return DataException(
      message: '$entity$id not found',
      code: 'not_found',
      originalError: originalError,
    );
  }

  // Factory constructor for parsing errors
  factory DataException.parseError({String? details, dynamic originalError}) {
    return DataException(
      message:
          details != null
              ? 'Failed to parse data: $details'
              : 'Failed to parse data',
      code: 'parse_error',
      originalError: originalError,
    );
  }
}

/// Authentication-related exceptions
class AuthException extends AppException {
  const AuthException({
    required super.message,
    String? code,
    super.originalError,
  }) : super(code: code ?? 'auth_error');

  // Factory constructor for unauthorized access
  factory AuthException.unauthorized({String? details, dynamic originalError}) {
    return AuthException(
      message: details ?? 'You are not authorized to access this resource',
      code: 'unauthorized',
      originalError: originalError,
    );
  }

  // Factory constructor for expired tokens
  factory AuthException.expiredToken({dynamic originalError}) {
    return AuthException(
      message: 'Your session has expired. Please log in again.',
      code: 'token_expired',
      originalError: originalError,
    );
  }
}

/// Permission-related exceptions
class PermissionException extends AppException {
  const PermissionException({
    required super.message,
    String? code,
    super.originalError,
  }) : super(code: code ?? 'permission_error');
}

/// Location-related exceptions
class LocationException extends AppException {
  const LocationException({
    required super.message,
    String? code,
    super.originalError,
  }) : super(code: code ?? 'location_error');
}

/// Storage-related exceptions
class StorageException extends AppException {
  const StorageException({
    required super.message,
    String? code,
    super.originalError,
  }) : super(code: code ?? 'storage_error');
}

/// Resource-related exceptions (for handling state of device resources)
class ResourceException extends AppException {
  const ResourceException({
    required super.message,
    String? code,
    super.originalError,
  }) : super(code: code ?? 'resource_error');
}

/// Unexpected exceptions (catch-all for unhandled errors)
class UnexpectedException extends AppException {
  const UnexpectedException({String? message, super.originalError})
    : super(
        message: message ?? 'An unexpected error occurred',
        code: 'unexpected_error',
      );
}
