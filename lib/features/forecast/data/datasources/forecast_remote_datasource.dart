// lib/features/forecast/data/datasources/forecast_remote_datasource.dart

import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:rivr/core/constants/api_constants.dart';
import 'package:rivr/core/error/exceptions.dart';
import 'package:rivr/features/forecast/domain/entities/forecast_types.dart';

abstract class ForecastRemoteDataSource {
  /// Gets forecast data from the NOAA API
  Future<Map<String, dynamic>> getForecast(
    String reachId,
    ForecastType forecastType,
  );

  /// Gets return period data for the given reach/comid
  Future<Map<String, dynamic>> getReturnPeriods(String reachId);
}

class ForecastRemoteDataSourceImpl implements ForecastRemoteDataSource {
  final http.Client client;

  ForecastRemoteDataSourceImpl({required this.client});

  @override
  Future<Map<String, dynamic>> getForecast(
    String reachId,
    ForecastType forecastType,
  ) async {
    // Build the exact NOAA streamflow URL
    final urlString = ApiConstants.getForecastUrl(
      reachId,
      forecastType.toString(),
    );
    final url = Uri.parse(urlString);
    if (kDebugMode) debugPrint('⏱️ Fetching forecast → $url');

    try {
      final response = await client
          .get(url, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 30));

      if (kDebugMode) {
        debugPrint(
          '🔄 Forecast ${response.statusCode}: '
          '${response.body.substring(0, min(200, response.body.length))}...',
        );
      }

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        throw ServerException(
          message: 'Forecast data not found for reach ID: $reachId',
        );
      } else {
        throw ServerException(
          message:
              'Failed to fetch forecast data. Status: ${response.statusCode}',
        );
      }
    } on http.ClientException {
      throw NetworkException(message: 'Network error occurred');
    } on FormatException {
      throw ServerException(message: 'Invalid response format');
    } catch (e) {
      throw ServerException(message: 'Unexpected error: ${e.toString()}');
    }
  }

  @override
  Future<Map<String, dynamic>> getReturnPeriods(String reachId) async {
    // Build your return‐period gateway URL
    final urlString = ApiConstants.getReturnPeriodUrl(reachId);
    final url = Uri.parse(urlString);
    if (kDebugMode) debugPrint('⏱️ Fetching return periods → $url');

    try {
      final response = await client
          .get(url, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 30));

      if (kDebugMode) {
        debugPrint(
          '🔄 ReturnPeriods ${response.statusCode}: '
          '${response.body.substring(0, min(200, response.body.length))}...',
        );
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List &&
            data.isNotEmpty &&
            data[0] is Map<String, dynamic>) {
          return data[0] as Map<String, dynamic>;
        } else {
          throw ServerException(message: 'Invalid return period data format');
        }
      } else {
        throw ServerException(
          message:
              'Failed to fetch return period data. Status: ${response.statusCode}',
        );
      }
    } on http.ClientException {
      throw NetworkException(message: 'Network error occurred');
    } on FormatException {
      throw ServerException(message: 'Invalid response format');
    } catch (e) {
      throw ServerException(message: 'Unexpected error: ${e.toString()}');
    }
  }
}
