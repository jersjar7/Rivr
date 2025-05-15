// lib/features/forecast/data/models/forecast_model.dart

import 'package:rivr/features/forecast/domain/entities/forecast.dart';
import 'package:rivr/features/forecast/domain/entities/forecast_types.dart';

class ForecastModel {
  final String reachId;
  final String validTime;
  final double flow;
  final ForecastType forecastType;
  final DateTime retrievedAt;
  final String? member;

  ForecastModel({
    required this.reachId,
    required this.validTime,
    required this.flow,
    required this.forecastType,
    required this.retrievedAt,
    this.member,
  });

  // Convert model to entity
  Forecast toEntity() {
    return Forecast(
      reachId: reachId,
      validTime: validTime,
      flow: flow,
      forecastType: forecastType,
      retrievedAt: retrievedAt,
      member: member,
    );
  }

  // Factory constructor to create a ForecastModel from API JSON data
  factory ForecastModel.fromApiJson(
    Map<String, dynamic> json,
    String reachId,
    ForecastType forecastType, {
    String? member,
  }) {
    return ForecastModel(
      reachId: reachId,
      validTime: json['validTime'] as String,
      flow: (json['flow'] as num).toDouble(),
      forecastType: forecastType,
      retrievedAt: DateTime.now(),
      member: member,
    );
  }

  // Factory method to create a collection of forecast models from API
  static List<ForecastModel> listFromApiJson(
    Map<String, dynamic> json,
    String reachId,
    ForecastType forecastType,
  ) {
    final List<ForecastModel> forecasts = [];

    // Handle different API response structures
    if (forecastType == ForecastType.shortRange) {
      if (json.containsKey('shortRange') && json['shortRange'] != null) {
        // Try to get series data first (mean data for short range)
        if (json['shortRange'].containsKey('series') &&
            json['shortRange']['series'] != null &&
            json['shortRange']['series'].containsKey('data')) {
          final List<dynamic> data = json['shortRange']['series']['data'];
          for (var item in data) {
            if (item['flow'] != null && item['validTime'] != null) {
              forecasts.add(
                ForecastModel.fromApiJson(item, reachId, forecastType),
              );
            }
          }
        }

        // If no forecasts from series, try to get data from members
        if (forecasts.isEmpty) {
          for (int i = 1; i <= 6; i++) {
            final memberKey = 'member$i';
            if (json['shortRange'].containsKey(memberKey) &&
                json['shortRange'][memberKey] != null &&
                json['shortRange'][memberKey].containsKey('data')) {
              final List<dynamic> memberData =
                  json['shortRange'][memberKey]['data'];
              for (var item in memberData) {
                if (item['flow'] != null && item['validTime'] != null) {
                  forecasts.add(
                    ForecastModel.fromApiJson(
                      item,
                      reachId,
                      forecastType,
                      member: memberKey,
                    ),
                  );
                }
              }
              // If we found valid forecasts from this member, stop searching further
              if (forecasts.isNotEmpty) break;
            }
          }
        }
      }
    } else if (forecastType == ForecastType.mediumRange) {
      if (json.containsKey('mediumRange') && json['mediumRange'] != null) {
        // Try to get mean data first
        if (json['mediumRange'].containsKey('mean') &&
            json['mediumRange']['mean'] != null &&
            json['mediumRange']['mean'].containsKey('data')) {
          final List<dynamic> meanData = json['mediumRange']['mean']['data'];
          for (var item in meanData) {
            if (item['flow'] != null && item['validTime'] != null) {
              forecasts.add(
                ForecastModel.fromApiJson(item, reachId, forecastType),
              );
            }
          }
        }

        // If no forecasts from mean, try to get data from members
        if (forecasts.isEmpty) {
          for (int i = 1; i <= 6; i++) {
            final memberKey = 'member$i';
            if (json['mediumRange'].containsKey(memberKey) &&
                json['mediumRange'][memberKey] != null &&
                json['mediumRange'][memberKey].containsKey('data')) {
              final List<dynamic> memberData =
                  json['mediumRange'][memberKey]['data'];
              for (var item in memberData) {
                if (item['flow'] != null && item['validTime'] != null) {
                  forecasts.add(
                    ForecastModel.fromApiJson(
                      item,
                      reachId,
                      forecastType,
                      member: memberKey,
                    ),
                  );
                }
              }
              // If we found valid forecasts from this member, stop searching further
              if (forecasts.isNotEmpty) break;
            }
          }
        }
      }
    } else if (forecastType == ForecastType.longRange) {
      if (json.containsKey('longRange') && json['longRange'] != null) {
        // Try to get mean data first
        if (json['longRange'].containsKey('mean') &&
            json['longRange']['mean'] != null &&
            json['longRange']['mean'].containsKey('data')) {
          final List<dynamic> meanData = json['longRange']['mean']['data'];
          for (var item in meanData) {
            if (item['flow'] != null && item['validTime'] != null) {
              forecasts.add(
                ForecastModel.fromApiJson(item, reachId, forecastType),
              );
            }
          }
        }

        // If no forecasts from mean, try to get data from members
        if (forecasts.isEmpty) {
          for (int i = 1; i <= 6; i++) {
            final memberKey = 'member$i';
            if (json['longRange'].containsKey(memberKey) &&
                json['longRange'][memberKey] != null &&
                json['longRange'][memberKey].containsKey('data')) {
              final List<dynamic> memberData =
                  json['longRange'][memberKey]['data'];
              for (var item in memberData) {
                if (item['flow'] != null && item['validTime'] != null) {
                  forecasts.add(
                    ForecastModel.fromApiJson(
                      item,
                      reachId,
                      forecastType,
                      member: memberKey,
                    ),
                  );
                }
              }
              // If we found valid forecasts from this member, stop searching further
              if (forecasts.isNotEmpty) break;
            }
          }
        }
      }
    }

    return forecasts;
  }

  // Factory method for creating a collection model
  static ForecastCollectionModel fromJson(
    Map<String, dynamic> json,
    String reachId,
    ForecastType forecastType,
  ) {
    final forecasts = listFromApiJson(json, reachId, forecastType);
    return ForecastCollectionModel(
      reachId: reachId,
      forecastType: forecastType,
      forecasts: forecasts,
    );
  }
}

class ForecastCollectionModel {
  final String reachId;
  final ForecastType forecastType;
  final List<ForecastModel> forecasts;
  final DateTime retrievedAt;

  ForecastCollectionModel({
    required this.reachId,
    required this.forecastType,
    required this.forecasts,
    DateTime? retrievedAt,
  }) : retrievedAt = retrievedAt ?? DateTime.now();

  // Convert to entity
  ForecastCollection toEntity() {
    return ForecastCollection(
      reachId: reachId,
      forecastType: forecastType,
      forecasts: forecasts.map((model) => model.toEntity()).toList(),
      retrievedAt: retrievedAt,
    );
  }
}
