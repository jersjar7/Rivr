// lib/features/forecast/data/datasources/forecast_remote_datasource.dart

import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:rivr/core/constants/api_constants.dart';
import 'package:rivr/core/error/exceptions.dart';
import 'package:rivr/core/models/flow_unit.dart';
import 'package:rivr/core/services/flow_units_service.dart';
import 'package:rivr/features/forecast/domain/entities/forecast_types.dart';
import 'package:rivr/features/forecast/domain/entities/return_period.dart';

abstract class ForecastRemoteDataSource {
  /// Gets forecast data from the NOAA API
  Future<Map<String, dynamic>> getForecast(
    String reachId,
    ForecastType forecastType,
  );

  /// Gets return period data for the given reach/comid
  ///
  /// [sourceUnit] specifies the unit of the API values (defaults to CMS)
  /// [targetUnit] specifies the desired unit for conversion (defaults to CFS)
  /// [flowUnitsService] is used for unit conversion if provided
  Future<Map<String, dynamic>> getReturnPeriods(
    String reachId, {
    FlowUnit sourceUnit = FlowUnit.cms,
    FlowUnit targetUnit = FlowUnit.cfs,
    FlowUnitsService? flowUnitsService,
  });

  /// Gets fully parsed ReturnPeriod model with proper unit conversion
  Future<ReturnPeriodModel> getReturnPeriodsModel(
    String reachId, {
    FlowUnit sourceUnit = FlowUnit.cms,
    FlowUnit targetUnit = FlowUnit.cfs,
    FlowUnitsService? flowUnitsService,
  });
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
  Future<Map<String, dynamic>> getReturnPeriods(
    String reachId, {
    FlowUnit sourceUnit = FlowUnit.cms,
    FlowUnit targetUnit = FlowUnit.cfs,
    FlowUnitsService? flowUnitsService,
  }) async {
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
          // Log to debug unit conversion issues
          if (kDebugMode) {
            debugPrint('📊 Raw return period data: ${data[0]}');
            debugPrint('📏 Source unit: $sourceUnit, Target unit: $targetUnit');
            if (flowUnitsService == null) {
              debugPrint(
                '⚠️ Warning: flowUnitsService is null, conversion may not work',
              );
            }
          }

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

  @override
  Future<ReturnPeriodModel> getReturnPeriodsModel(
    String reachId, {
    FlowUnit sourceUnit = FlowUnit.cms,
    FlowUnit targetUnit = FlowUnit.cfs,
    FlowUnitsService? flowUnitsService,
  }) async {
    final data = await getReturnPeriods(
      reachId,
      sourceUnit: sourceUnit,
      targetUnit: targetUnit,
      flowUnitsService: flowUnitsService,
    );

    // Create ReturnPeriodModel with explicit unit information and conversion service
    return ReturnPeriodModel.fromJson(
      data,
      reachId,
      sourceUnit: sourceUnit, // API data is in this unit (usually CMS)
      targetUnit:
          targetUnit, // Convert to this unit (usually user preferred unit)
      flowUnitsService: flowUnitsService, // Service used for conversion
    );
  }
}
