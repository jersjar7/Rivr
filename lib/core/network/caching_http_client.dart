// lib/core/network/caching_http_client.dart

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:rivr/core/network/network_info.dart';
import 'package:sqflite/sqflite.dart';

import '../cache/storage/cache_database.dart';
import '../error/app_exception.dart';

/// HTTP client with built-in caching capabilities
class CachingHttpClient extends http.BaseClient {
  final http.Client _inner;
  final CacheDatabase _cacheDatabase;
  final NetworkInfo _networkInfo;

  /// Default timeout for requests
  final Duration timeout;

  /// Default cache duration if not specified
  final Duration defaultCacheDuration;

  /// Whether to force cache usage even for requests that normally wouldn't be cached
  bool forceOfflineMode = false;

  CachingHttpClient({
    required http.Client inner,
    required CacheDatabase cacheDatabase,
    required NetworkInfo networkInfo,
    this.timeout = const Duration(seconds: 30),
    this.defaultCacheDuration = const Duration(hours: 2),
  }) : _inner = inner,
       _cacheDatabase = cacheDatabase,
       _networkInfo = networkInfo;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final cacheKey = _generateCacheKey(request);
    final requestData = await _prepareRequest(request);

    // Offline-first: try cache if no connectivity or forced offline
    final isConnected = await _networkInfo.isConnected;
    if ((!isConnected || forceOfflineMode)) {
      final cached = await _getCachedResponse(cacheKey);
      if (cached != null) {
        return cached;
      }
      if (!isConnected) {
        throw NetworkException.noConnection();
      }
    }

    // Execute network request with timeout
    final original = await _inner
        .send(request)
        .timeout(
          timeout,
          onTimeout:
              () =>
                  throw TimeoutException(
                    'Request timed out after ${timeout.inSeconds}s',
                  ),
        );

    // Buffer the response bytes
    final bytes = await original.stream.toBytes();

    // Cache successful GET responses
    if (_shouldCacheResponse(request, original)) {
      try {
        final db = await _cacheDatabase.database;
        final now = DateTime.now().millisecondsSinceEpoch;
        final expiresAt = now + _getCacheDuration(original).inMilliseconds;

        await db.insert(
          CacheDatabase.tableNetworkCache,
          {
            'url': cacheKey,
            'method': requestData['method'],
            'headers': jsonEncode(requestData['headers']),
            'body': requestData['body'],
            'status_code': original.statusCode,
            'response_body': utf8.decode(bytes),
            'response_headers': jsonEncode(original.headers),
            'created_at': now,
            'expires_at': expiresAt,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (e) {
        print('Error caching response: $e');
      }
    }

    // Return a new StreamedResponse with the buffered body
    return http.StreamedResponse(
      Stream.value(bytes),
      original.statusCode,
      headers: original.headers,
      reasonPhrase: original.reasonPhrase,
      contentLength: bytes.length,
      request: original.request,
    );
  }

  /// Prepare request data for caching
  Future<Map<String, dynamic>> _prepareRequest(http.BaseRequest request) async {
    final headers = Map<String, String>.from(request.headers);
    String? body;
    if (request is http.Request) {
      body = request.body;
    }
    return {
      'url': request.url.toString(),
      'method': request.method,
      'headers': headers,
      'body': body,
    };
  }

  /// Generate a unique cache key for a request
  String _generateCacheKey(http.BaseRequest request) {
    String key = '${request.method}_${request.url}';
    if (request is http.Request &&
        (request.method == 'POST' || request.method == 'PUT')) {
      key += '_${_hashString(request.body)}';
    }
    return key;
  }

  /// Simple string hashing for cache keys
  String _hashString(String input) {
    var hash = 0;
    for (var i = 0; i < input.length; i++) {
      hash = ((hash << 5) - hash) + input.codeUnitAt(i);
      hash &= 0xFFFFFFFF;
    }
    return hash.toString();
  }

  /// Get a cached response
  Future<http.StreamedResponse?> _getCachedResponse(String cacheKey) async {
    final db = await _cacheDatabase.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final results = await db.query(
      CacheDatabase.tableNetworkCache,
      where: 'url = ? AND expires_at > ?',
      whereArgs: [cacheKey, now],
    );

    if (results.isEmpty) return null;
    try {
      final entry = results.first;
      final headersJson = entry['response_headers'] as String?;
      final headers =
          headersJson != null
              ? Map<String, String>.from(jsonDecode(headersJson))
              : <String, String>{};
      final statusCode = entry['status_code'] as int;
      final responseBody = entry['response_body'] as String;
      final bodyBytes = utf8.encode(responseBody);

      return http.StreamedResponse(
        Stream.value(Uint8List.fromList(bodyBytes)),
        statusCode,
        headers: headers,
      );
    } catch (e) {
      print('Error retrieving cached response: $e');
      return null;
    }
  }

  /// Determine if a response should be cached
  bool _shouldCacheResponse(
    http.BaseRequest request,
    http.StreamedResponse response,
  ) {
    if (response.statusCode < 200 || response.statusCode >= 300) return false;
    if (request.method != 'GET') return false;
    if (response.headers['cache-control']?.contains('no-cache') ?? false) {
      return false;
    }
    return true;
  }

  /// Determine appropriate cache duration from response headers
  Duration _getCacheDuration(http.StreamedResponse response) {
    if (response.headers.containsKey('cache-control')) {
      final cacheControl = response.headers['cache-control']!;
      final maxAgeMatch = RegExp(r'max-age=(\d+)').firstMatch(cacheControl);
      if (maxAgeMatch != null) {
        return Duration(seconds: int.parse(maxAgeMatch.group(1)!));
      }
    }
    if (response.headers.containsKey('expires')) {
      try {
        final expires = DateTime.parse(response.headers['expires']!);
        return expires.difference(DateTime.now());
      } catch (_) {}
    }
    return defaultCacheDuration;
  }

  /// Override close to close the inner client
  @override
  void close() {
    _inner.close();
    super.close();
  }
}

/// Exception for timeout errors
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  @override
  String toString() => 'TimeoutException: $message';
}
