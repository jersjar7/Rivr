// lib/features/simple_notifications/dummy_rivers/services/dummy_river_forecast_service.dart

import 'dart:math';
import '../models/dummy_river_forecast.dart';
import '../models/dummy_river.dart';

/// Preset scenarios for quick testing
enum ForecastScenario {
  noAlerts,
  moderateAlert,
  extremeAlert,
  mixedScenario,
  borderlineCase,
}

/// Service for generating and managing dummy river forecast data
class DummyRiverForecastService {
  static final DummyRiverForecastService _instance =
      DummyRiverForecastService._internal();
  factory DummyRiverForecastService() => _instance;
  DummyRiverForecastService._internal();

  // In-memory storage for forecast data
  final Map<String, DummyRiverForecast> _forecastCache = {};
  final Random _random = Random();

  /// Generate forecasts within specified flow ranges
  DummyRiverForecast generateForecasts({
    required String riverId,
    required String riverName,
    required String unit,
    double? shortRangeMin,
    double? shortRangeMax,
    double? mediumRangeMin,
    double? mediumRangeMax,
    int shortRangeHours = 18,
    int mediumRangeDays = 10,
  }) {
    final now = DateTime.now();
    final shortForecasts = <ForecastDataPoint>[];
    final mediumForecasts = <ForecastDataPoint>[];

    // Generate short range forecasts (hourly)
    if (shortRangeMin != null && shortRangeMax != null) {
      for (int i = 1; i <= shortRangeHours; i++) {
        final timestamp = now.add(Duration(hours: i));
        final flow = _generateFlowValue(shortRangeMin, shortRangeMax);
        shortForecasts.add(
          ForecastDataPoint(timestamp: timestamp, flowValue: flow, unit: unit),
        );
      }
    }

    // Generate medium range forecasts (daily)
    if (mediumRangeMin != null && mediumRangeMax != null) {
      for (int i = 1; i <= mediumRangeDays; i++) {
        final timestamp = now.add(Duration(days: i));
        final flow = _generateFlowValue(mediumRangeMin, mediumRangeMax);
        mediumForecasts.add(
          ForecastDataPoint(timestamp: timestamp, flowValue: flow, unit: unit),
        );
      }
    }

    final forecast = DummyRiverForecast(
      riverId: riverId,
      riverName: riverName,
      shortRangeForecasts: shortForecasts,
      mediumRangeForecasts: mediumForecasts,
      createdAt: now,
      updatedAt: now,
    );

    // Cache the forecast
    _forecastCache[riverId] = forecast;
    return forecast;
  }

  /// Generate forecasts based on preset scenarios
  DummyRiverForecast generateScenarioForecasts({
    required String riverId,
    required String riverName,
    required DummyRiver dummyRiver,
    required ForecastScenario scenario,
  }) {
    final returnPeriods = dummyRiver.returnPeriods;
    if (returnPeriods.isEmpty) {
      throw Exception('Dummy river must have return periods defined');
    }

    final sortedPeriods =
        returnPeriods.entries.toList()
          ..sort((a, b) => a.value.compareTo(b.value));

    final minReturnFlow = sortedPeriods.first.value;
    final maxReturnFlow = sortedPeriods.last.value;

    double shortMin, shortMax, mediumMin, mediumMax;

    switch (scenario) {
      case ForecastScenario.noAlerts:
        // All flows below 2-year return period
        shortMax = minReturnFlow * 0.8;
        shortMin = minReturnFlow * 0.3;
        mediumMax = minReturnFlow * 0.9;
        mediumMin = minReturnFlow * 0.4;
        break;

      case ForecastScenario.moderateAlert:
        // Flows around 5-10 year return periods
        final midFlow =
            _getReturnPeriodFlow(returnPeriods, 5) ??
            (minReturnFlow + maxReturnFlow) / 2;
        shortMin = midFlow * 0.8;
        shortMax = midFlow * 1.2;
        mediumMin = midFlow * 0.9;
        mediumMax = midFlow * 1.1;
        break;

      case ForecastScenario.extremeAlert:
        // Flows exceeding 25-50 year return periods
        final extremeFlow =
            _getReturnPeriodFlow(returnPeriods, 25) ?? maxReturnFlow;
        shortMin = extremeFlow * 1.1;
        shortMax = extremeFlow * 1.5;
        mediumMin = extremeFlow * 1.0;
        mediumMax = extremeFlow * 1.3;
        break;

      case ForecastScenario.mixedScenario:
        // Mix of flows - some trigger alerts, others don't
        shortMin = minReturnFlow * 0.5;
        shortMax = maxReturnFlow * 1.2;
        mediumMin = minReturnFlow * 0.7;
        mediumMax = maxReturnFlow * 0.9;
        break;

      case ForecastScenario.borderlineCase:
        // Flows very close to return period thresholds
        final targetFlow =
            _getReturnPeriodFlow(returnPeriods, 5) ??
            (minReturnFlow + maxReturnFlow) / 2;
        shortMin = targetFlow * 0.95;
        shortMax = targetFlow * 1.05;
        mediumMin = targetFlow * 0.98;
        mediumMax = targetFlow * 1.02;
        break;
    }

    return generateForecasts(
      riverId: riverId,
      riverName: riverName,
      unit: dummyRiver.unit,
      shortRangeMin: shortMin,
      shortRangeMax: shortMax,
      mediumRangeMin: mediumMin,
      mediumRangeMax: mediumMax,
    );
  }

  /// Calculate which return periods would be triggered by forecasts
  Map<int, List<ForecastDataPoint>> calculateTriggeredReturnPeriods(
    DummyRiverForecast forecast,
    Map<int, double> returnPeriods,
  ) {
    final triggered = <int, List<ForecastDataPoint>>{};

    // Sort return periods by flow value (descending) to check highest first
    final sortedPeriods =
        returnPeriods.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    for (final forecastPoint in forecast.allForecasts) {
      for (final period in sortedPeriods) {
        if (forecastPoint.flowValue >= period.value) {
          triggered.putIfAbsent(period.key, () => []).add(forecastPoint);
          break; // Only trigger the highest applicable return period
        }
      }
    }

    return triggered;
  }

  /// Get forecast summary with return period analysis
  ForecastSummary getForecastSummary(
    DummyRiverForecast forecast,
    Map<int, double> returnPeriods,
  ) {
    final triggered = calculateTriggeredReturnPeriods(forecast, returnPeriods);
    final alertCount = triggered.values.fold(
      0,
      (sum, list) => sum + list.length,
    );

    return ForecastSummary(
      totalForecasts: forecast.totalCount,
      shortRangeCount: forecast.shortRangeForecasts.length,
      mediumRangeCount: forecast.mediumRangeForecasts.length,
      triggeredReturnPeriods: triggered,
      alertCount: alertCount,
      maxFlow: forecast.maxFlow ?? 0,
      minFlow: forecast.minFlow ?? 0,
      unit: forecast.unit ?? 'cfs',
    );
  }

  /// Get cached forecast for a river
  DummyRiverForecast? getCachedForecast(String riverId) {
    return _forecastCache[riverId];
  }

  /// Update specific forecast range
  DummyRiverForecast updateForecastRange({
    required String riverId,
    required ForecastRange range,
    required String unit,
    required double minFlow,
    required double maxFlow,
    int? pointCount,
  }) {
    final existing = _forecastCache[riverId];
    if (existing == null) {
      throw Exception('No existing forecast found for river: $riverId');
    }

    final now = DateTime.now();
    List<ForecastDataPoint> newForecasts;

    switch (range) {
      case ForecastRange.shortRange:
        final hours = pointCount ?? 18;
        newForecasts = List.generate(hours, (i) {
          final timestamp = now.add(Duration(hours: i + 1));
          final flow = _generateFlowValue(minFlow, maxFlow);
          return ForecastDataPoint(
            timestamp: timestamp,
            flowValue: flow,
            unit: unit,
          );
        });
        break;

      case ForecastRange.mediumRange:
        final days = pointCount ?? 10;
        newForecasts = List.generate(days, (i) {
          final timestamp = now.add(Duration(days: i + 1));
          final flow = _generateFlowValue(minFlow, maxFlow);
          return ForecastDataPoint(
            timestamp: timestamp,
            flowValue: flow,
            unit: unit,
          );
        });
        break;
    }

    final updated = existing.updateForecasts(range, newForecasts);
    _forecastCache[riverId] = updated;
    return updated;
  }

  /// Clear forecast for a river
  void clearForecast(String riverId) {
    _forecastCache.remove(riverId);
  }

  /// Clear all cached forecasts
  void clearAllForecasts() {
    _forecastCache.clear();
  }

  /// Get all cached forecasts
  Map<String, DummyRiverForecast> getAllCachedForecasts() {
    return Map.unmodifiable(_forecastCache);
  }

  /// Check if river has cached forecast
  bool hasCachedForecast(String riverId) {
    return _forecastCache.containsKey(riverId);
  }

  /// Generate realistic flow value with some variation
  double _generateFlowValue(double min, double max) {
    // Add some natural variation using normal distribution
    final baseValue = min + (_random.nextDouble() * (max - min));
    final variation = (max - min) * 0.1; // 10% variation
    final noise = (_random.nextGaussian() * variation);
    final result = baseValue + noise;

    // Ensure result stays within bounds
    return result.clamp(min * 0.8, max * 1.2);
  }

  /// Get flow value for specific return period
  double? _getReturnPeriodFlow(
    Map<int, double> returnPeriods,
    int targetYears,
  ) {
    // Try exact match first
    if (returnPeriods.containsKey(targetYears)) {
      return returnPeriods[targetYears];
    }

    // Find closest return period
    final sorted =
        returnPeriods.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    for (int i = 0; i < sorted.length; i++) {
      if (sorted[i].key >= targetYears) {
        return sorted[i].value;
      }
    }

    return null;
  }

  /// Get scenario description
  static String getScenarioDescription(ForecastScenario scenario) {
    switch (scenario) {
      case ForecastScenario.noAlerts:
        return 'All flows below alert thresholds - no notifications expected';
      case ForecastScenario.moderateAlert:
        return 'Some flows at 5-10 year levels - moderate alerts expected';
      case ForecastScenario.extremeAlert:
        return 'High flows exceeding 25+ year levels - extreme alerts expected';
      case ForecastScenario.mixedScenario:
        return 'Mixed flow levels - some alerts, some quiet periods';
      case ForecastScenario.borderlineCase:
        return 'Flows very close to thresholds - tests edge cases';
    }
  }

  /// Get scenario icon
  static String getScenarioIcon(ForecastScenario scenario) {
    switch (scenario) {
      case ForecastScenario.noAlerts:
        return '🟢';
      case ForecastScenario.moderateAlert:
        return '🟡';
      case ForecastScenario.extremeAlert:
        return '🔴';
      case ForecastScenario.mixedScenario:
        return '🔷';
      case ForecastScenario.borderlineCase:
        return '🔶';
    }
  }
}

/// Summary of forecast data with return period analysis
class ForecastSummary {
  final int totalForecasts;
  final int shortRangeCount;
  final int mediumRangeCount;
  final Map<int, List<ForecastDataPoint>> triggeredReturnPeriods;
  final int alertCount;
  final double maxFlow;
  final double minFlow;
  final String unit;

  const ForecastSummary({
    required this.totalForecasts,
    required this.shortRangeCount,
    required this.mediumRangeCount,
    required this.triggeredReturnPeriods,
    required this.alertCount,
    required this.maxFlow,
    required this.minFlow,
    required this.unit,
  });

  /// Get highest triggered return period
  int? get highestTriggeredPeriod {
    if (triggeredReturnPeriods.isEmpty) return null;
    return triggeredReturnPeriods.keys.reduce((a, b) => a > b ? a : b);
  }

  /// Check if any alerts would be triggered
  bool get hasAlerts => alertCount > 0;

  /// Get formatted flow range
  String get flowRange {
    final min = _formatFlow(minFlow);
    final max = _formatFlow(maxFlow);
    return '$min - $max $unit';
  }

  String _formatFlow(double flow) {
    if (flow >= 1000000) {
      return '${(flow / 1000000).toStringAsFixed(1)}M';
    } else if (flow >= 1000) {
      return '${(flow / 1000).toStringAsFixed(1)}K';
    } else {
      return flow.toStringAsFixed(0);
    }
  }
}

/// Extension for Random to generate Gaussian distributed values
extension GaussianRandom on Random {
  double nextGaussian() {
    double u = 0, v = 0;
    while (u == 0) u = nextDouble(); // Converting [0,1) to (0,1)
    while (v == 0) v = nextDouble();
    return sqrt(-2.0 * log(u)) * cos(2.0 * pi * v);
  }
}
