// lib/core/constants/api_constants.dart

import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  // 1) Read straight from .env
  static final _forecastBase = dotenv.env['FORECAST_BASE_URL']!;
  static final _returnBase = dotenv.env['RETURN_BASE_URL']!;
  static final _apiKey = dotenv.env['API_KEY']!;

  /// Builds e.g. https://api.water.noaa.gov/nwps/v1/reaches/23021904/streamflow?series=short_range
  static String getForecastUrl(String reachId, String series) {
    final uri = Uri.parse(_forecastBase).replace(
      pathSegments: [
        ...Uri.parse(_forecastBase).pathSegments, // in case v1 is a path
        'reaches',
        reachId,
        'streamflow',
      ],
      queryParameters: {'series': series},
    );
    return uri.toString();
  }

  /// Builds e.g.
  /// https://nwm-api-updt-9f6idmxh.uc.gateway.dev/return-period?comids=15039097&key=AIza…
  static String getReturnPeriodUrl(String comid) {
    final uri = Uri.parse(_returnBase).replace(
      path: '/return-period',
      queryParameters: {'comids': comid, 'key': _apiKey},
    );
    return uri.toString();
  }
}
