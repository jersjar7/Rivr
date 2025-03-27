// lib/features/forecast/data/datasources/forecast_remote_datasource.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
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
    final url = Uri.parse(
      '${ApiConstants.baseUrl}/reaches/$reachId/streamflow?series=${forecastType.toString()}',
    );

    try {
      final response = await client
          .get(url, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return json.decode(response.body);
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
    final url = Uri.parse(ApiConstants.getReturnPeriodUrl(reachId));

    try {
      final response = await client
          .get(url, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty && data[0] is Map<String, dynamic>) {
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
