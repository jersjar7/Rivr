import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  static String get baseUrl => dotenv.env['API_BASE_URL'] ?? '';
  static String get returnPeriodApi => dotenv.env['RETURN_PERIOD_API'] ?? '';
  static String get apiKey => dotenv.env['API_KEY'] ?? '';

  static String getForecastUrl(String reachId) =>
      '$baseUrl/reaches/$reachId/streamflow';

  static String getReturnPeriodUrl(String reachId) =>
      '$returnPeriodApi?comids=$reachId&key=$apiKey';
}
