// lib/core/constants/api_constants.dart

import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  /// Base URL for your NWM API (forecast + return‐period endpoints)
  static String get baseUrl =>
      dotenv.env['API_BASE_URL'] ??
      'https://nwm-api-updt-9f6idmxh.uc.gateway.dev';

  /// The specific return‐period path (no query params)
  static String get returnPeriodPath =>
      dotenv.env['RETURN_PERIOD_PATH'] ?? '/return-period';

  /// Your API key for both forecast & return‐period
  static String get apiKey =>
      dotenv.env['API_KEY'] ?? 'AIzaSyArCbLaEevrqrVPJDzu2OioM_kNmCBtsx8';

  /// NOAA‐style forecast URL (if you’re still pulling forecasts from the old service,
  /// otherwise point this at your new endpoint too)
  static String getForecastUrl(String reachId) =>
      '$baseUrl/reaches/$reachId/streamflow?key=$apiKey';

  /// Return period URL: builds e.g.
  /// https://…/return-period?comids=15039097&key=…
  static String getReturnPeriodUrl(String reachId) {
    return '$baseUrl$returnPeriodPath'
        '?comids=$reachId'
        '&key=$apiKey';
  }
}
