// lib/core/config/api_config.dart

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized configuration for API endpoints and keys
class ApiConfig {
  // Base URLs
  static String get baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'https://api.water.noaa.gov/nwps/v1';

  static String get returnPeriodApi =>
      dotenv.env['RETURN_PERIOD_API'] ??
      'https://nwm-api-updt-9f6idmxh.uc.gateway.dev/return-period';

  // API Keys
  static String get apiKey => dotenv.env['API_KEY'] ?? '';

  // Mapbox
  static String get mapboxAccessToken =>
      dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';

  // Timeouts (in seconds)
  static const int defaultTimeout = 15;
  static const int longTimeout = 30;

  // Construct endpoint URLs
  static String getForecastUrl(String reachId) =>
      '$baseUrl/reaches/$reachId/streamflow';

  static String getReachUrl(String reachId) => '$baseUrl/reaches/$reachId';

  static String getReturnPeriodUrl(String reachId) =>
      '$returnPeriodApi?comids=$reachId&key=$apiKey';

  // Validate configuration
  static bool validateConfig() {
    bool isValid = true;

    if (baseUrl.isEmpty) {
      print('ERROR: API_BASE_URL is not configured');
      isValid = false;
    }

    if (mapboxAccessToken.isEmpty) {
      print('ERROR: MAPBOX_ACCESS_TOKEN is not configured');
      isValid = false;
    }

    return isValid;
  }
}
