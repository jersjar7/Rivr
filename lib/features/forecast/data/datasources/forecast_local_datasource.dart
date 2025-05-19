// lib/features/forecast/data/datasources/forecast_local_datasource.dart

import 'dart:convert';
import 'package:rivr/common/data/local/database_helper.dart';
import 'package:rivr/core/error/exceptions.dart';
import 'package:rivr/core/models/flow_unit.dart';
import 'package:rivr/features/forecast/domain/entities/forecast_types.dart';
import 'package:sqflite/sqflite.dart';

abstract class ForecastLocalDataSource {
  /// Gets cached forecast data
  /// Throws a [CacheException] if no cached data is found
  Future<Map<String, dynamic>> getCachedForecast(
    String reachId,
    ForecastType forecastType,
  );

  /// Caches forecast data
  Future<void> cacheForecast(
    String reachId,
    ForecastType forecastType,
    Map<String, dynamic> forecastData,
  );

  /// Gets cached return period data
  /// Returns null if no cached data is found
  /// The returned data includes the unit information
  Future<Map<String, dynamic>?> getCachedReturnPeriods(String reachId);

  /// Caches return period data
  /// [unit] specifies the unit of the stored values (defaults to CMS)
  Future<void> cacheReturnPeriods(
    String reachId,
    Map<String, dynamic> returnPeriodData, {
    FlowUnit unit =
        FlowUnit.cms, // Default is CMS since API returns values in CMS
  });

  /// Clears stale cached forecasts
  Future<void> clearStaleCache();

  /// Checks if cached forecast is stale
  Future<bool> isCacheStale(String reachId, ForecastType forecastType);
}

class ForecastLocalDataSourceImpl implements ForecastLocalDataSource {
  final DatabaseHelper databaseHelper;

  ForecastLocalDataSourceImpl({required this.databaseHelper});

  @override
  Future<Map<String, dynamic>> getCachedForecast(
    String reachId,
    ForecastType forecastType,
  ) async {
    final db = await databaseHelper.database;

    final results = await db.query(
      'forecast_cache',
      where: 'reach_id = ? AND forecast_type = ?',
      whereArgs: [reachId, forecastType.toString()],
    );

    if (results.isNotEmpty) {
      return json.decode(results.first['data'] as String)
          as Map<String, dynamic>;
    } else {
      throw CacheException(message: 'No cached forecast data found');
    }
  }

  @override
  Future<void> cacheForecast(
    String reachId,
    ForecastType forecastType,
    Map<String, dynamic> forecastData,
  ) async {
    final db = await databaseHelper.database;
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    await db.insert('forecast_cache', {
      'reach_id': reachId,
      'forecast_type': forecastType.toString(),
      'data': json.encode(forecastData),
      'timestamp': timestamp,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<Map<String, dynamic>?> getCachedReturnPeriods(String reachId) async {
    final db = await databaseHelper.database;

    final results = await db.query(
      'return_period_cache',
      where: 'reach_id = ?',
      whereArgs: [reachId],
    );

    if (results.isNotEmpty) {
      // Decode the JSON data
      final decodedData =
          json.decode(results.first['data'] as String) as Map<String, dynamic>;

      // Add unit information if not already present
      // This is for backward compatibility with older cache entries
      if (!decodedData.containsKey('unit')) {
        // Assume older data is in CMS (default API format)
        decodedData['unit'] = FlowUnit.cms.toString();
      }

      return decodedData;
    }

    return null;
  }

  @override
  Future<void> cacheReturnPeriods(
    String reachId,
    Map<String, dynamic> returnPeriodData, {
    FlowUnit unit =
        FlowUnit.cms, // Default is CMS since API returns values in CMS
  }) async {
    final db = await databaseHelper.database;
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Add unit information to the data before storing
    final Map<String, dynamic> dataWithUnit = {
      ...returnPeriodData,
      'unit': unit.toString(), // Store the unit information
    };

    await db.insert('return_period_cache', {
      'reach_id': reachId,
      'data': json.encode(dataWithUnit), // Store data with unit info
      'timestamp': timestamp,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> clearStaleCache() async {
    final db = await databaseHelper.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Clear stale short range forecasts (TTL: 2 hours)
    final shortRangeTTL =
        now - (ForecastType.shortRange.cacheDuration * 60 * 60 * 1000);
    await db.delete(
      'forecast_cache',
      where: 'forecast_type = ? AND timestamp < ?',
      whereArgs: [ForecastType.shortRange.toString(), shortRangeTTL],
    );

    // Clear stale medium range forecasts (TTL: 12 hours)
    final mediumRangeTTL =
        now - (ForecastType.mediumRange.cacheDuration * 60 * 60 * 1000);
    await db.delete(
      'forecast_cache',
      where: 'forecast_type = ? AND timestamp < ?',
      whereArgs: [ForecastType.mediumRange.toString(), mediumRangeTTL],
    );

    // Clear stale long range forecasts (TTL: 24 hours)
    final longRangeTTL =
        now - (ForecastType.longRange.cacheDuration * 60 * 60 * 1000);
    await db.delete(
      'forecast_cache',
      where: 'forecast_type = ? AND timestamp < ?',
      whereArgs: [ForecastType.longRange.toString(), longRangeTTL],
    );

    // Clear stale return period data (TTL: 7 days)
    final returnPeriodTTL =
        now - (7 * 24 * 60 * 60 * 1000); // 7 days in milliseconds
    await db.delete(
      'return_period_cache',
      where: 'timestamp < ?',
      whereArgs: [returnPeriodTTL],
    );
  }

  @override
  Future<bool> isCacheStale(String reachId, ForecastType forecastType) async {
    final db = await databaseHelper.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    final results = await db.query(
      'forecast_cache',
      columns: ['timestamp'],
      where: 'reach_id = ? AND forecast_type = ?',
      whereArgs: [reachId, forecastType.toString()],
    );

    if (results.isEmpty) {
      return true;
    }

    final timestamp = results.first['timestamp'] as int;
    final age = now - timestamp;
    final ttl =
        forecastType.cacheDuration *
        60 *
        60 *
        1000; // convert hours to milliseconds

    return age > ttl;
  }
}
