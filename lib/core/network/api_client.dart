// lib/core/network/api_client.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../error/app_exception.dart';
import '../network/network_info.dart';

/// A centralized API client for making HTTP requests
class ApiClient {
  final http.Client _httpClient;
  final NetworkInfo _networkInfo;

  ApiClient({http.Client? httpClient, required NetworkInfo networkInfo})
    : _httpClient = httpClient ?? http.Client(),
      _networkInfo = networkInfo;

  /// Makes a GET request to the specified endpoint
  Future<dynamic> get(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    Duration timeout = const Duration(seconds: 15),
    bool requiresConnection = true,
  }) async {
    return _executeRequest(
      () => _httpClient.get(
        _buildUri(url, queryParameters),
        headers: _buildHeaders(headers),
      ),
      timeout: timeout,
      requiresConnection: requiresConnection,
    );
  }

  /// Makes a POST request to the specified endpoint
  Future<dynamic> post(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    dynamic body,
    Duration timeout = const Duration(seconds: 15),
    bool requiresConnection = true,
  }) async {
    return _executeRequest(
      () => _httpClient.post(
        _buildUri(url, queryParameters),
        headers: _buildHeaders(headers),
        body: _encodeBody(body),
      ),
      timeout: timeout,
      requiresConnection: requiresConnection,
    );
  }

  /// Makes a PUT request to the specified endpoint
  Future<dynamic> put(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    dynamic body,
    Duration timeout = const Duration(seconds: 15),
    bool requiresConnection = true,
  }) async {
    return _executeRequest(
      () => _httpClient.put(
        _buildUri(url, queryParameters),
        headers: _buildHeaders(headers),
        body: _encodeBody(body),
      ),
      timeout: timeout,
      requiresConnection: requiresConnection,
    );
  }

  /// Makes a DELETE request to the specified endpoint
  Future<dynamic> delete(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    dynamic body,
    Duration timeout = const Duration(seconds: 15),
    bool requiresConnection = true,
  }) async {
    return _executeRequest(
      () => _httpClient.delete(
        _buildUri(url, queryParameters),
        headers: _buildHeaders(headers),
        body: _encodeBody(body),
      ),
      timeout: timeout,
      requiresConnection: requiresConnection,
    );
  }

  /// Executes the HTTP request with proper error handling
  Future<dynamic> _executeRequest(
    Future<http.Response> Function() requestFunction, {
    required Duration timeout,
    required bool requiresConnection,
  }) async {
    try {
      // Check for network connection if required
      if (requiresConnection) {
        final hasConnection = await _networkInfo.isConnected;
        if (!hasConnection) {
          throw NetworkException.noConnection();
        }
      }

      // Execute the request with timeout
      final response = await requestFunction().timeout(
        timeout,
        onTimeout: () {
          throw NetworkException.timeout(seconds: timeout.inSeconds);
        },
      );

      // Process the response
      return _processResponse(response);
    } on SocketException catch (e) {
      print('SocketException: ${e.message}');
      throw NetworkException.noConnection(originalError: e);
    } on TimeoutException catch (e) {
      print('TimeoutException: ${e.message}');
      throw NetworkException.timeout(originalError: e);
    } on AppException {
      rethrow; // Rethrow AppExceptions as they're already handled
    } catch (e) {
      print('Unexpected error in API client: $e');
      throw UnexpectedException(
        message: 'Failed to complete request: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Process API response and handle errors
  dynamic _processResponse(http.Response response) {
    final statusCode = response.statusCode;

    // Success responses (2xx)
    if (statusCode >= 200 && statusCode < 300) {
      try {
        if (response.body.isEmpty) {
          return null;
        }
        return json.decode(response.body);
      } catch (e) {
        throw DataException.parseError(
          details: 'Failed to parse response: ${e.toString()}',
          originalError: e,
        );
      }
    }

    // Error handling based on status code
    if (statusCode == 401) {
      throw AuthException.unauthorized(
        details: _getErrorMessage(response),
        originalError: response,
      );
    }

    if (statusCode == 404) {
      throw DataException.notFound(originalError: response);
    }

    // Handle other error codes
    throw NetworkException.httpError(
      statusCode: statusCode,
      message: _getErrorMessage(response),
      originalError: response,
    );
  }

  /// Try to extract a meaningful error message from the response
  String _getErrorMessage(http.Response response) {
    try {
      final body = json.decode(response.body);

      // Check common error message formats
      if (body is Map) {
        if (body.containsKey('message')) {
          return body['message'];
        }

        if (body.containsKey('error')) {
          if (body['error'] is String) {
            return body['error'];
          }
          if (body['error'] is Map && body['error'].containsKey('message')) {
            return body['error']['message'];
          }
        }
      }
    } catch (_) {
      // If parsing fails, just return the status code
    }

    return 'HTTP Error: ${response.statusCode}';
  }

  /// Encode the request body based on its type
  dynamic _encodeBody(dynamic body) {
    if (body == null) {
      return null;
    }

    if (body is String) {
      return body;
    }

    if (body is Map || body is List) {
      return json.encode(body);
    }

    // For other types, try to use toString()
    return body.toString();
  }

  /// Build headers with default content-type
  Map<String, String> _buildHeaders(Map<String, String>? headers) {
    final defaultHeaders = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    return headers != null ? {...defaultHeaders, ...headers} : defaultHeaders;
  }

  /// Construct URI with optional query parameters
  Uri _buildUri(String url, Map<String, dynamic>? queryParameters) {
    final uri = Uri.parse(url);

    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }

    // Convert all parameter values to strings
    final stringParams = queryParameters.map(
      (key, value) => MapEntry(key, value.toString()),
    );

    // Merge with existing parameters if any
    final mergedParams = Map<String, String>.from(uri.queryParameters)
      ..addAll(stringParams);

    return uri.replace(queryParameters: mergedParams);
  }

  /// Dispose resources
  void dispose() {
    _httpClient.close();
  }
}
