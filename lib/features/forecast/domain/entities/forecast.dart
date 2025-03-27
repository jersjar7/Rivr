// lib/features/forecast/domain/entities/forecast.dart

import 'package:rivr/features/forecast/domain/entities/forecast_types.dart';

class Forecast {
  final String reachId;
  final String validTime;
  final double flow;
  final ForecastType forecastType;
  final DateTime retrievedAt;
  final String? member; // For ensemble forecasts

  Forecast({
    required this.reachId,
    required this.validTime,
    required this.flow,
    required this.forecastType,
    DateTime? retrievedAt,
    this.member,
  }) : retrievedAt = retrievedAt ?? DateTime.now();

  DateTime get validDateTime => DateTime.parse(validTime);

  bool get isToday {
    final today = DateTime.now();
    final forecastDate = validDateTime;
    return forecastDate.year == today.year &&
        forecastDate.month == today.month &&
        forecastDate.day == today.day;
  }

  bool get isStale {
    final now = DateTime.now();
    final age = now.difference(retrievedAt).inHours;
    return age > forecastType.cacheDuration;
  }
}

class ForecastCollection {
  final String reachId;
  final ForecastType forecastType;
  final List<Forecast> forecasts;
  final DateTime retrievedAt;

  ForecastCollection({
    required this.reachId,
    required this.forecastType,
    required this.forecasts,
    DateTime? retrievedAt,
  }) : retrievedAt = retrievedAt ?? DateTime.now();

  List<Forecast> getForecastsForDay(DateTime date) {
    return forecasts.where((forecast) {
      final forecastDate = forecast.validDateTime;
      return forecastDate.year == date.year &&
          forecastDate.month == date.month &&
          forecastDate.day == date.day;
    }).toList();
  }

  Forecast? get mostRecentForecast {
    if (forecasts.isEmpty) return null;
    return forecasts.reduce(
      (a, b) => a.validDateTime.isAfter(b.validDateTime) ? a : b,
    );
  }

  double get minFlow {
    if (forecasts.isEmpty) return 0;
    return forecasts.map((f) => f.flow).reduce((a, b) => a < b ? a : b);
  }

  double get maxFlow {
    if (forecasts.isEmpty) return 0;
    return forecasts.map((f) => f.flow).reduce((a, b) => a > b ? a : b);
  }

  bool get isStale {
    final now = DateTime.now();
    final age = now.difference(retrievedAt).inHours;
    return age > forecastType.cacheDuration;
  }
}
