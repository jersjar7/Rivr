// lib/common/data/remote/cached_forecast_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:rivr/common/data/local/database_helper.dart';

enum ForecastType { shortRange, mediumRange, longRange }

class CachedForecastService {
  final String baseUrl;
  final http.Client _httpClient;
  final DatabaseHelper _databaseHelper;

  // Cache durations in hours
  static const int _shortRangeCacheDuration = 2; // 2 hours
  static const int _mediumRangeCacheDuration = 12; // 12 hours
  static const int _longRangeCacheDuration = 24; // 24 hours

  CachedForecastService({
    this.baseUrl = 'https://api.water.noaa.gov/nwps/v1',
    http.Client? httpClient,
    DatabaseHelper? databaseHelper,
  }) : _httpClient = httpClient ?? http.Client(),
       _databaseHelper = databaseHelper ?? DatabaseHelper();

  Future<bool> get _hasInternetConnection async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  int _getCacheDuration(ForecastType type) {
    switch (type) {
      case ForecastType.shortRange:
        return _shortRangeCacheDuration;
      case ForecastType.mediumRange:
        return _mediumRangeCacheDuration;
      case ForecastType.longRange:
        return _longRangeCacheDuration;
    }
  }

  Future<Map<String, dynamic>> fetchForecast(String reachId) async {
    return _fetchWithCaching(reachId, ForecastType.shortRange);
  }

  Future<Map<String, dynamic>> fetchMediumRangeForecast(String reachId) async {
    return _fetchWithCaching(reachId, ForecastType.mediumRange);
  }

  Future<Map<String, dynamic>> fetchLongRangeForecast(String reachId) async {
    return _fetchWithCaching(reachId, ForecastType.longRange);
  }

  Future<Map<String, dynamic>> _fetchWithCaching(
    String reachId,
    ForecastType forecastType,
  ) async {
    final hasInternet = await _hasInternetConnection;
    final db = await _databaseHelper.database;
    final typeString = forecastType.toString().split('.').last;

    // Try to get cached data first
    final cachedData = await _getCachedForecast(db, reachId, typeString);

    if (cachedData != null) {
      // Check if cache is still valid
      final timestamp = cachedData['timestamp'] as int;
      final cacheDuration = _getCacheDuration(forecastType);
      final ageInMillis = DateTime.now().millisecondsSinceEpoch - timestamp;
      final ageInHours = ageInMillis / (1000 * 60 * 60);

      if (ageInHours < cacheDuration) {
        print(
          'Using cached data for $reachId ($typeString), age: ${ageInHours.toStringAsFixed(1)} hours',
        );
        return json.decode(cachedData['data'] as String);
      }
    }

    // If no valid cache or cache expired, fetch from network
    if (hasInternet) {
      try {
        final data = await _fetchFromNetwork(reachId, forecastType);
        // Save to cache
        await _saveForecastToCache(db, reachId, typeString, data);
        return data;
      } catch (e) {
        // If network fetch fails but we have cached data, return it even if expired
        if (cachedData != null) {
          print(
            'Network fetch failed, using expired cache for $reachId ($typeString)',
          );
          return json.decode(cachedData['data'] as String);
        }
        rethrow;
      }
    } else if (cachedData != null) {
      // No internet, but we have cached data
      print(
        'No internet connection, using cached data for $reachId ($typeString)',
      );
      return json.decode(cachedData['data'] as String);
    } else {
      // No internet and no cached data
      throw Exception('No internet connection and no cached data available');
    }
  }

  Future<Map<String, dynamic>?> _getCachedForecast(
    Database db,
    String reachId,
    String forecastType,
  ) async {
    final results = await db.query(
      'CachedForecasts',
      where: 'reachId = ? AND forecastType = ?',
      whereArgs: [reachId, forecastType],
    );

    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  Future<void> _saveForecastToCache(
    Database db,
    String reachId,
    String forecastType,
    Map<String, dynamic> data,
  ) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    await db.insert('CachedForecasts', {
      'reachId': reachId,
      'forecastType': forecastType,
      'data': json.encode(data),
      'timestamp': timestamp,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>> _fetchFromNetwork(
    String reachId,
    ForecastType forecastType,
  ) async {
    String endpoint;
    switch (forecastType) {
      case ForecastType.shortRange:
        endpoint = '$baseUrl/reaches/$reachId/streamflow?series=short_range';
        break;
      case ForecastType.mediumRange:
        endpoint = '$baseUrl/reaches/$reachId/streamflow?series=medium_range';
        break;
      case ForecastType.longRange:
        endpoint = '$baseUrl/reaches/$reachId/streamflow?series=long_range';
        break;
    }

    final response = await _httpClient
        .get(Uri.parse(endpoint))
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw TimeoutException('Request timed out');
          },
        );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load forecast data: ${response.statusCode}');
    }
  }

  // Utility method to clear old cache entries
  Future<void> cleanupCache() async {
    final maxAge =
        _longRangeCacheDuration * 2; // Double the longest cache duration
    await _databaseHelper.clearOldCache(maxAge);
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}
