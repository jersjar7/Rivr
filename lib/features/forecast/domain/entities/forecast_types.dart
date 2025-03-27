// lib/features/forecast/domain/entities/forecast_types.dart

enum ForecastType {
  shortRange,
  mediumRange,
  longRange;

  @override
  String toString() {
    switch (this) {
      case ForecastType.shortRange:
        return 'short_range';
      case ForecastType.mediumRange:
        return 'medium_range';
      case ForecastType.longRange:
        return 'long_range';
    }
  }

  String get displayName {
    switch (this) {
      case ForecastType.shortRange:
        return 'Hourly (3-Day)';
      case ForecastType.mediumRange:
        return '9-Day';
      case ForecastType.longRange:
        return '30-Day';
    }
  }

  int get cacheDuration {
    switch (this) {
      case ForecastType.shortRange:
        return 2; // 2 hours
      case ForecastType.mediumRange:
        return 12; // 12 hours
      case ForecastType.longRange:
        return 24; // 24 hours
    }
  }
}
