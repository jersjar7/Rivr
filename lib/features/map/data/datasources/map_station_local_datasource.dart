// lib/features/map/data/datasources/map_station_local_datasource.dart

import 'package:sqflite/sqflite.dart' as sqflite;
import '../../../../common/data/local/database_helper.dart';
import '../../../../core/error/exceptions.dart';
import '../models/map_station_model.dart';

abstract class MapStationLocalDataSource {
  Future<List<MapStationModel>> getStationsInRegion(
    double minLat,
    double maxLat,
    double minLon,
    double maxLon, {
    int limit = 1000,
  });

  Future<List<MapStationModel>> getSampleStations({int limit = 10});

  Future<int> getStationCount();

  Future<List<MapStationModel>> getNearestStations(
    double lat,
    double lon, {
    int limit = 5,
    double radius = 50.0,
  });
}

class MapStationLocalDataSourceImpl implements MapStationLocalDataSource {
  final DatabaseHelper _databaseHelper;

  MapStationLocalDataSourceImpl({required DatabaseHelper databaseHelper})
    : _databaseHelper = databaseHelper;

  @override
  Future<List<MapStationModel>> getStationsInRegion(
    double minLat,
    double maxLat,
    double minLon,
    double maxLon, {
    int limit = 1000,
  }) async {
    try {
      final db = await _databaseHelper.database;

      final List<Map<String, dynamic>> result = await db.query(
        'StationDetails',
        where: 'lat >= ? AND lat <= ? AND lon >= ? AND lon <= ?',
        whereArgs: [minLat, maxLat, minLon, maxLon],
        limit: limit,
      );

      return result.map((map) => MapStationModel.fromMap(map)).toList();
    } catch (e) {
      print("Error querying stations: $e");
      throw DatabaseException(message: "Failed to fetch stations: $e");
    }
  }

  @override
  Future<List<MapStationModel>> getSampleStations({int limit = 10}) async {
    try {
      final db = await _databaseHelper.database;

      print("DEBUG: Executing sample stations query with limit: $limit");
      final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT * FROM StationDetails 
      ORDER BY RANDOM() 
      LIMIT $limit
    ''');

      print("DEBUG: Sample stations query returned ${result.length} rows");
      if (result.isNotEmpty) {
        print("DEBUG: First row data: ${result.first}");
      } else {
        print("DEBUG: Query returned no rows");
      }

      return result.map((map) => MapStationModel.fromMap(map)).toList();
    } catch (e) {
      print("DEBUG: Error querying sample stations: $e");
      throw DatabaseException(message: "Failed to fetch sample stations: $e");
    }
  }

  @override
  Future<int> getStationCount() async {
    try {
      final db = await _databaseHelper.database;

      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM StationDetails',
      );
      return sqflite.Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      print("Error counting stations: $e");
      throw DatabaseException(message: "Failed to count stations: $e");
    }
  }

  @override
  Future<List<MapStationModel>> getNearestStations(
    double lat,
    double lon, {
    int limit = 5,
    double radius = 50.0,
  }) async {
    try {
      final db = await _databaseHelper.database;

      // Using Haversine formula to calculate distance
      final String haversineFormula = '''
        (6371 * acos(
          cos(radians($lat)) * cos(radians(lat)) * 
          cos(radians(lon) - radians($lon)) + 
          sin(radians($lat)) * sin(radians(lat))
        ))
      ''';

      final List<Map<String, dynamic>> result = await db.rawQuery('''
        SELECT *, $haversineFormula AS distance
        FROM StationDetails
        WHERE $haversineFormula < $radius
        ORDER BY distance
        LIMIT $limit
      ''');

      return result.map((map) => MapStationModel.fromMap(map)).toList();
    } catch (e) {
      print("Error querying nearest stations: $e");
      throw DatabaseException(message: "Failed to fetch nearest stations: $e");
    }
  }
}
