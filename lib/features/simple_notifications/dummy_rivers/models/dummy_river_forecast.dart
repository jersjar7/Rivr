// lib/features/simple_notifications/dummy_rivers/models/dummy_river_forecast.dart

import 'dart:math';

enum ForecastRange { shortRange, mediumRange }

/// Individual forecast data point with timestamp and flow value
class ForecastDataPoint {
  final DateTime timestamp;
  final double flowValue;
  final String unit;

  const ForecastDataPoint({
    required this.timestamp,
    required this.flowValue,
    required this.unit,
  });

  /// Create a copy with updated values
  ForecastDataPoint copyWith({
    DateTime? timestamp,
    double? flowValue,
    String? unit,
  }) {
    return ForecastDataPoint(
      timestamp: timestamp ?? this.timestamp,
      flowValue: flowValue ?? this.flowValue,
      unit: unit ?? this.unit,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'flowValue': flowValue,
      'unit': unit,
    };
  }

  /// Create from JSON
  factory ForecastDataPoint.fromJson(Map<String, dynamic> json) {
    return ForecastDataPoint(
      timestamp: DateTime.parse(json['timestamp'] as String),
      flowValue: (json['flowValue'] as num).toDouble(),
      unit: json['unit'] as String,
    );
  }

  /// Format flow value for display
  String get formattedFlow {
    if (flowValue >= 1000000) {
      return '${(flowValue / 1000000).toStringAsFixed(1)}M';
    } else if (flowValue >= 1000) {
      return '${(flowValue / 1000).toStringAsFixed(1)}K';
    } else {
      return flowValue.toStringAsFixed(0);
    }
  }

  /// Get relative time description
  String get relativeTime {
    final now = DateTime.now();
    final difference = timestamp.difference(now);

    if (difference.isNegative) {
      final pastDiff = difference.abs();
      if (pastDiff.inHours < 1) {
        return '${pastDiff.inMinutes}m ago';
      } else if (pastDiff.inDays < 1) {
        return '${pastDiff.inHours}h ago';
      } else {
        return '${pastDiff.inDays}d ago';
      }
    } else {
      if (difference.inHours < 1) {
        return 'in ${difference.inMinutes}m';
      } else if (difference.inDays < 1) {
        return 'in ${difference.inHours}h';
      } else {
        return 'in ${difference.inDays}d';
      }
    }
  }

  @override
  String toString() {
    return 'ForecastDataPoint($formattedFlow $unit at $relativeTime)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ForecastDataPoint &&
        other.timestamp == timestamp &&
        other.flowValue == flowValue &&
        other.unit == unit;
  }

  @override
  int get hashCode => Object.hash(timestamp, flowValue, unit);
}

/// Container for managing forecast data for a dummy river
class DummyRiverForecast {
  final String riverId;
  final String riverName;
  final List<ForecastDataPoint> shortRangeForecasts;
  final List<ForecastDataPoint> mediumRangeForecasts;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DummyRiverForecast({
    required this.riverId,
    required this.riverName,
    this.shortRangeForecasts = const [],
    this.mediumRangeForecasts = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create empty forecast for a river
  factory DummyRiverForecast.empty(String riverId, String riverName) {
    final now = DateTime.now();
    return DummyRiverForecast(
      riverId: riverId,
      riverName: riverName,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Create forecast with generated data
  factory DummyRiverForecast.withGeneratedData({
    required String riverId,
    required String riverName,
    required String unit,
    double? shortRangeMin,
    double? shortRangeMax,
    double? mediumRangeMin,
    double? mediumRangeMax,
    int shortRangePoints = 12,
    int mediumRangePoints = 10,
  }) {
    final now = DateTime.now();
    final random = Random();

    // Generate short range forecasts (hourly for 18 hours)
    final shortForecasts = <ForecastDataPoint>[];
    if (shortRangeMin != null && shortRangeMax != null) {
      for (int i = 0; i < shortRangePoints; i++) {
        final timestamp = now.add(Duration(hours: i + 1));
        final flow =
            shortRangeMin +
            (random.nextDouble() * (shortRangeMax - shortRangeMin));
        shortForecasts.add(
          ForecastDataPoint(timestamp: timestamp, flowValue: flow, unit: unit),
        );
      }
    }

    // Generate medium range forecasts (daily for 10 days)
    final mediumForecasts = <ForecastDataPoint>[];
    if (mediumRangeMin != null && mediumRangeMax != null) {
      for (int i = 0; i < mediumRangePoints; i++) {
        final timestamp = now.add(Duration(days: i + 1));
        final flow =
            mediumRangeMin +
            (random.nextDouble() * (mediumRangeMax - mediumRangeMin));
        mediumForecasts.add(
          ForecastDataPoint(timestamp: timestamp, flowValue: flow, unit: unit),
        );
      }
    }

    return DummyRiverForecast(
      riverId: riverId,
      riverName: riverName,
      shortRangeForecasts: shortForecasts,
      mediumRangeForecasts: mediumForecasts,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Create a copy with updated values
  DummyRiverForecast copyWith({
    String? riverId,
    String? riverName,
    List<ForecastDataPoint>? shortRangeForecasts,
    List<ForecastDataPoint>? mediumRangeForecasts,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DummyRiverForecast(
      riverId: riverId ?? this.riverId,
      riverName: riverName ?? this.riverName,
      shortRangeForecasts: shortRangeForecasts ?? this.shortRangeForecasts,
      mediumRangeForecasts: mediumRangeForecasts ?? this.mediumRangeForecasts,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Update forecasts for a specific range
  DummyRiverForecast updateForecasts(
    ForecastRange range,
    List<ForecastDataPoint> forecasts,
  ) {
    switch (range) {
      case ForecastRange.shortRange:
        return copyWith(
          shortRangeForecasts: forecasts,
          updatedAt: DateTime.now(),
        );
      case ForecastRange.mediumRange:
        return copyWith(
          mediumRangeForecasts: forecasts,
          updatedAt: DateTime.now(),
        );
    }
  }

  /// Get all forecasts sorted by timestamp
  List<ForecastDataPoint> get allForecasts {
    final all = [...shortRangeForecasts, ...mediumRangeForecasts];
    all.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return all;
  }

  /// Get forecasts for a specific range
  List<ForecastDataPoint> getForecastsForRange(ForecastRange range) {
    switch (range) {
      case ForecastRange.shortRange:
        return List.unmodifiable(shortRangeForecasts);
      case ForecastRange.mediumRange:
        return List.unmodifiable(mediumRangeForecasts);
    }
  }

  /// Check if has any forecasts
  bool get hasForecasts =>
      shortRangeForecasts.isNotEmpty || mediumRangeForecasts.isNotEmpty;

  /// Check if has forecasts for a specific range
  bool hasForecastsForRange(ForecastRange range) {
    return getForecastsForRange(range).isNotEmpty;
  }

  /// Get maximum flow value across all forecasts
  double? get maxFlow {
    if (!hasForecasts) return null;
    return allForecasts.map((f) => f.flowValue).reduce((a, b) => a > b ? a : b);
  }

  /// Get minimum flow value across all forecasts
  double? get minFlow {
    if (!hasForecasts) return null;
    return allForecasts.map((f) => f.flowValue).reduce((a, b) => a < b ? a : b);
  }

  /// Get count of forecasts by range
  int getCountForRange(ForecastRange range) {
    return getForecastsForRange(range).length;
  }

  /// Get total forecast count
  int get totalCount =>
      shortRangeForecasts.length + mediumRangeForecasts.length;

  /// Get forecast unit (assumes all forecasts use same unit)
  String? get unit {
    if (hasForecasts) {
      return allForecasts.first.unit;
    }
    return null;
  }

  /// Check if forecasts are recent (within last hour)
  bool get isRecent {
    final now = DateTime.now();
    final hourAgo = now.subtract(const Duration(hours: 1));
    return updatedAt.isAfter(hourAgo);
  }

  /// Get forecasts that would trigger specific return periods
  List<ForecastDataPoint> getForecastsAboveThreshold(double threshold) {
    return allForecasts.where((f) => f.flowValue >= threshold).toList();
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'riverId': riverId,
      'riverName': riverName,
      'shortRangeForecasts':
          shortRangeForecasts.map((f) => f.toJson()).toList(),
      'mediumRangeForecasts':
          mediumRangeForecasts.map((f) => f.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create from JSON
  factory DummyRiverForecast.fromJson(Map<String, dynamic> json) {
    return DummyRiverForecast(
      riverId: json['riverId'] as String,
      riverName: json['riverName'] as String,
      shortRangeForecasts:
          (json['shortRangeForecasts'] as List)
              .map((f) => ForecastDataPoint.fromJson(f as Map<String, dynamic>))
              .toList(),
      mediumRangeForecasts:
          (json['mediumRangeForecasts'] as List)
              .map((f) => ForecastDataPoint.fromJson(f as Map<String, dynamic>))
              .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  @override
  String toString() {
    return 'DummyRiverForecast($riverName: ${shortRangeForecasts.length} short, ${mediumRangeForecasts.length} medium)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DummyRiverForecast &&
        other.riverId == riverId &&
        other.riverName == riverName;
  }

  @override
  int get hashCode => Object.hash(riverId, riverName);
}
