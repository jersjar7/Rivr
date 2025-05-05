// lib/core/network/api_client.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../error/app_exception.dart';
import '../network/network_info.dart';
import '../cache/storage/cache_database.dart';
import 'caching_http_client.dart';

/// A centralized API client for making HTTP requests (with optional caching)
class ApiClient {
  final CachingHttpClient _client;
  final NetworkInfo _networkInfo;
  bool _offlineMode = false;

  /// Creates an [ApiClient].
  ///
  /// If [innerClient] is provided, it's wrapped with caching;
  /// otherwise a default [http.Client] is used.
  ApiClient({
    http.Client? innerClient,
    required NetworkInfo networkInfo,
    CacheDatabase? cacheDatabase,
  }) : _networkInfo = networkInfo,
       _client = CachingHttpClient(
         inner: innerClient ?? http.Client(),
         networkInfo: networkInfo,
         cacheDatabase: cacheDatabase ?? CacheDatabase(),
       );

  /// Toggle offline mode (forces cache use even when online)
  void setOfflineMode(bool enabled) {
    _offlineMode = enabled;
    _client.forceOfflineMode = enabled;
  }

  /// GET request
  Future<dynamic> get(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    Duration timeout = const Duration(seconds: 15),
    bool requiresConnection = true,
    bool forceFresh = false,
  }) {
    // If forcing fresh data, bypass cache while online
    _client.forceOfflineMode = _offlineMode || !forceFresh;

    return _executeRequest(
      () => _client
          .get(_buildUri(url, queryParameters), headers: _buildHeaders(headers))
          .timeout(
            timeout,
            onTimeout:
                () =>
                    throw NetworkException.timeout(seconds: timeout.inSeconds),
          ),
      timeout: timeout,
      requiresConnection: requiresConnection,
    );
  }

  /// POST request
  Future<dynamic> post(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    dynamic body,
    Duration timeout = const Duration(seconds: 15),
    bool requiresConnection = true,
  }) {
    _client.forceOfflineMode = _offlineMode;

    return _executeRequest(
      () => _client
          .post(
            _buildUri(url, queryParameters),
            headers: _buildHeaders(headers),
            body: _encodeBody(body),
          )
          .timeout(
            timeout,
            onTimeout:
                () =>
                    throw NetworkException.timeout(seconds: timeout.inSeconds),
          ),
      timeout: timeout,
      requiresConnection: requiresConnection,
    );
  }

  /// PUT request
  Future<dynamic> put(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    dynamic body,
    Duration timeout = const Duration(seconds: 15),
    bool requiresConnection = true,
  }) {
    _client.forceOfflineMode = _offlineMode;

    return _executeRequest(
      () => _client
          .put(
            _buildUri(url, queryParameters),
            headers: _buildHeaders(headers),
            body: _encodeBody(body),
          )
          .timeout(
            timeout,
            onTimeout:
                () =>
                    throw NetworkException.timeout(seconds: timeout.inSeconds),
          ),
      timeout: timeout,
      requiresConnection: requiresConnection,
    );
  }

  /// DELETE request
  Future<dynamic> delete(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    dynamic body,
    Duration timeout = const Duration(seconds: 15),
    bool requiresConnection = true,
  }) {
    _client.forceOfflineMode = _offlineMode;

    return _executeRequest(
      () => _client
          .delete(
            _buildUri(url, queryParameters),
            headers: _buildHeaders(headers),
            body: _encodeBody(body),
          )
          .timeout(
            timeout,
            onTimeout:
                () =>
                    throw NetworkException.timeout(seconds: timeout.inSeconds),
          ),
      timeout: timeout,
      requiresConnection: requiresConnection,
    );
  }

  /// Executes the HTTP call with error handling
  Future<dynamic> _executeRequest(
    Future<http.Response> Function() requestFunction, {
    required Duration timeout,
    required bool requiresConnection,
  }) async {
    try {
      if (requiresConnection && !_client.forceOfflineMode) {
        if (!await _networkInfo.isConnected) {
          throw NetworkException.noConnection();
        }
      }

      final response = await requestFunction();
      return _processResponse(response);
    } on SocketException catch (e) {
      throw NetworkException.noConnection(originalError: e);
    } on TimeoutException catch (e) {
      throw NetworkException.timeout(originalError: e);
    } on AppException {
      rethrow;
    } catch (e) {
      throw UnexpectedException(
        message: 'Failed to complete request: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Parses and handles HTTP responses
  dynamic _processResponse(http.Response response) {
    final statusCode = response.statusCode;

    if (statusCode >= 200 && statusCode < 300) {
      if (response.body.isEmpty) return null;
      try {
        return json.decode(response.body);
      } catch (e) {
        throw DataException.parseError(
          details: 'Failed to parse response: ${e.toString()}',
          originalError: e,
        );
      }
    }

    if (statusCode == 401) {
      throw AuthException.unauthorized(
        details: _getErrorMessage(response),
        originalError: response,
      );
    }

    if (statusCode == 404) {
      throw DataException.notFound(originalError: response);
    }

    throw NetworkException.httpError(
      statusCode: statusCode,
      message: _getErrorMessage(response),
      originalError: response,
    );
  }

  /// Extracts error message from response body
  String _getErrorMessage(http.Response response) {
    try {
      final body = json.decode(response.body);
      if (body is Map) {
        if (body.containsKey('message')) return body['message'];
        if (body.containsKey('error')) {
          final err = body['error'];
          if (err is String) return err;
          if (err is Map && err.containsKey('message')) return err['message'];
        }
      }
    } catch (_) {}
    return 'HTTP Error: ${response.statusCode}';
  }

  /// Encodes request body
  dynamic _encodeBody(dynamic body) {
    if (body == null) return null;
    if (body is String) return body;
    if (body is Map || body is List) return json.encode(body);
    return body.toString();
  }

  /// Builds headers with defaults
  Map<String, String> _buildHeaders(Map<String, String>? headers) {
    const defaults = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    return headers != null ? {...defaults, ...headers} : defaults;
  }

  /// Constructs URI with query parameters
  Uri _buildUri(String url, Map<String, dynamic>? queryParameters) {
    final uri = Uri.parse(url);
    if (queryParameters == null || queryParameters.isEmpty) return uri;
    final params = queryParameters.map((k, v) => MapEntry(k, v.toString()));
    return uri.replace(queryParameters: {...uri.queryParameters, ...params});
  }

  /// Dispose underlying HTTP client
  void dispose() {
    _client.close();
  }
}
