// lib/features/forecast/presentation/widgets/hydrograph/hydrograph_factory.dart

import 'package:flutter/material.dart';
import 'package:rivr/features/forecast/domain/entities/forecast.dart';
import 'package:rivr/features/forecast/domain/entities/forecast_types.dart';
import 'package:rivr/features/forecast/domain/entities/return_period.dart';
import 'package:rivr/features/forecast/presentation/widgets/long_range_hydrograph.dart';
import 'package:rivr/features/forecast/presentation/widgets/medium_range_hydrograph.dart';
import 'package:rivr/features/forecast/presentation/widgets/short_range_hydrograph.dart';

/// Factory class to create appropriate hydrograph widgets based on forecast type
class HydrographFactory {
  /// Creates a hydrograph widget for the specified forecast type
  static Widget createHydrograph({
    required String reachId,
    required ForecastType forecastType,
    required List<Forecast> forecasts,
    ReturnPeriod? returnPeriod,
    Map<DateTime, Map<String, double>>? dailyStats,
    Map<String, Map<String, double>>? longRangeFlows,
  }) {
    switch (forecastType) {
      case ForecastType.shortRange:
        return ShortRangeHydrograph(
          reachId: reachId,
          forecasts: forecasts,
          returnPeriod: returnPeriod,
        );

      case ForecastType.mediumRange:
        return MediumRangeHydrograph(
          reachId: reachId,
          forecasts: forecasts,
          dailyStats: dailyStats,
          returnPeriod: returnPeriod,
        );

      case ForecastType.longRange:
        return LongRangeHydrograph(
          reachId: reachId,
          forecasts: forecasts,
          longRangeFlows: longRangeFlows,
          returnPeriod: returnPeriod,
        );
    }
  }

  /// Creates a hydrograph widget from a forecast collection
  static Widget createFromForecastCollection({
    required String reachId,
    required ForecastCollection collection,
    ReturnPeriod? returnPeriod,
    Map<DateTime, Map<String, double>>? dailyStats,
    Map<String, Map<String, double>>? longRangeFlows,
  }) {
    return createHydrograph(
      reachId: reachId,
      forecastType: collection.forecastType,
      forecasts: collection.forecasts,
      returnPeriod: returnPeriod,
      dailyStats: dailyStats,
      longRangeFlows: longRangeFlows,
    );
  }

  /// Shows a hydrograph in a modal dialog
  static Future<void> showHydrographDialog({
    required BuildContext context,
    required String reachId,
    required ForecastType forecastType,
    required List<Forecast> forecasts,
    ReturnPeriod? returnPeriod,
    Map<DateTime, Map<String, double>>? dailyStats,
    Map<String, Map<String, double>>? longRangeFlows,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => createHydrograph(
              reachId: reachId,
              forecastType: forecastType,
              forecasts: forecasts,
              returnPeriod: returnPeriod,
              dailyStats: dailyStats,
              longRangeFlows: longRangeFlows,
            ),
      ),
    );
  }
}
