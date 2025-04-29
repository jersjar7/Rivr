// lib/common/data/remote/reach_service.dart

import 'package:rivr/core/config/api_config.dart';
import 'package:rivr/core/di/service_locator.dart';
import 'package:rivr/core/error/app_exception.dart';
import 'package:rivr/core/network/api_client.dart';

/// Service for fetching river reach data from the NOAA API
class ReachService {
  final ApiClient _apiClient;

  /// Create a new ReachService instance
  ///
  /// Optionally provide an ApiClient. If not provided,
  /// it will be retrieved from the service locator.
  ReachService({ApiClient? apiClient})
    : _apiClient = apiClient ?? sl<ApiClient>();

  /// Fetches data for a specific reach ID
  Future<dynamic> fetchReach(String reachId) async {
    if (reachId.isEmpty) {
      throw ArgumentError('Reach ID cannot be empty');
    }

    final url = ApiConfig.getReachUrl(reachId);
    print('ReachService: Fetching data from $url');

    try {
      // Use the global API client which handles all error cases
      final data = await _apiClient.get(url);
      print('ReachService: Successfully fetched data for reach $reachId');
      return data;
    } on DataException catch (e) {
      if (e.code == 'not_found') {
        throw DataException.notFound(
          entityName: 'Reach',
          entityId: reachId,
          originalError: e,
        );
      }
      rethrow;
    } catch (e) {
      print('ReachService: Error fetching reach data: $e');
      rethrow; // Let the global error handler manage this
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

    // Build URL with query parameters directly in the ApiClient
    final url = '${ApiConfig.baseUrl}/reaches/$reachId/streamflow';
    print('ReachService: Fetching forecast from $url');

    try {
      final data = await _apiClient.get(
        url,
        queryParameters: {'series': series},
      );
      print('ReachService: Successfully fetched forecast for reach $reachId');
      return data;
    } on DataException catch (e) {
      if (e.code == 'not_found') {
        throw DataException.notFound(
          entityName: 'Forecast',
          entityId: reachId,
          originalError: e,
        );
      }
      rethrow;
    } catch (e) {
      print('ReachService: Error fetching forecast data: $e');
      rethrow; // Let the global error handler manage this
    }
  }
}
