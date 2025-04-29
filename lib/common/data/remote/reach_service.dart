// lib/common/data/remote/reach_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ReachService {
  final String baseUrl;
  final http.Client _httpClient;
  final Duration timeout;

  ReachService({
    String? baseUrl,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 15),
  }) : baseUrl =
           baseUrl ??
           dotenv.env['API_BASE_URL'] ??
           'https://api.water.noaa.gov/nwps/v1',
       _httpClient = httpClient ?? http.Client();

  /// Fetches data for a specific reach ID
  Future<dynamic> fetchReach(String reachId) async {
    if (reachId.isEmpty) {
      throw ArgumentError('Reach ID cannot be empty');
    }

    final uri = Uri.parse('$baseUrl/reaches/$reachId');
    print('ReachService: Fetching data from $uri');

    try {
      final response = await _httpClient
          .get(uri)
          .timeout(
            timeout,
            onTimeout: () {
              throw TimeoutException(
                'Request timed out after ${timeout.inSeconds} seconds',
              );
            },
          );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        print('ReachService: Successfully fetched data for reach $reachId');
        return jsonData;
      } else if (response.statusCode == 404) {
        print('ReachService: Reach ID $reachId not found (404)');
        throw NotFoundException('Reach with ID $reachId not found');
      } else {
        print(
          'ReachService: Failed to load reach $reachId - Status code ${response.statusCode}',
        );
        throw ApiException('Failed to load reach data: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      print('ReachService: Network error - ${e.message}');
      throw NetworkException('Network error - Check your internet connection');
    } on TimeoutException catch (e) {
      print('ReachService: Request timeout - ${e.message}');
      rethrow;
    } catch (e) {
      print('ReachService: Unexpected error - $e');
      throw UnexpectedException('An unexpected error occurred: $e');
    }
  }

  /// Fetches the streamflow forecast for a reach
  Future<dynamic> fetchForecast(
    String reachId, {
    String series = 'short_range',
  }) async {
    if (reachId.isEmpty) {
      throw ArgumentError('Reach ID cannot be empty');
    }

    final uri = Uri.parse(
      '$baseUrl/reaches/$reachId/streamflow?series=$series',
    );
    print('ReachService: Fetching forecast from $uri');

    try {
      final response = await _httpClient.get(uri).timeout(timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        throw NotFoundException('Forecast not found for reach ID $reachId');
      } else {
        throw ApiException('Failed to load forecast: ${response.statusCode}');
      }
    } catch (e) {
      if (e is TimeoutException || e is SocketException) {
        throw NetworkException('Network error: ${e.toString()}');
      }
      rethrow;
    }
  }

  /// Disposes the HTTP client resources
  void dispose() {
    _httpClient.close();
  }
}

/// Custom exceptions for the ReachService
class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}

class NotFoundException implements Exception {
  final String message;
  NotFoundException(this.message);

  @override
  String toString() => 'NotFoundException: $message';
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}

class UnexpectedException implements Exception {
  final String message;
  UnexpectedException(this.message);

  @override
  String toString() => 'UnexpectedException: $message';
}
