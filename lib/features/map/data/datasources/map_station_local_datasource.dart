// lib/features/map/data/datasources/map_station_local_datasource.dart

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
      print(
        "DEBUG: Querying stations in region: minLat=$minLat, maxLat=$maxLat, minLon=$minLon, maxLon=$maxLon, limit=$limit",
      );
      final db = await _databaseHelper.database;

      // Check if Geolocations table exists
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='Geolocations'",
      );

      if (tables.isEmpty) {
        print("ERROR: Geolocations table not found in database!");
        throw DatabaseException(
          message: "Geolocations table not found in database!",
        );
      }

      // Check table structure
      final columns = await db.rawQuery("PRAGMA table_info(Geolocations)");
      print("DEBUG: Geolocations table columns: $columns");

      final List<Map<String, dynamic>> result = await db.query(
        'Geolocations',
        where: 'lat >= ? AND lat <= ? AND lon >= ? AND lon <= ?',
        whereArgs: [minLat, maxLat, minLon, maxLon],
        limit: limit,
      );

      print("DEBUG: Query returned ${result.length} stations in region");
      if (result.isNotEmpty) {
        print("DEBUG: First result: ${result.first}");
      }

      return result.map((map) {
        // Add default values for missing fields
        final enhancedMap = Map<String, dynamic>.from(map);
        enhancedMap['name'] ??= 'Station ${map['stationId']}';
        enhancedMap['type'] ??= 'river';
        enhancedMap['color'] ??= '#2389DA';

        return MapStationModel.fromMap(enhancedMap);
      }).toList();
    } catch (e) {
      print("ERROR: Failed to fetch stations in region: $e");
      throw DatabaseException(
        message: "Failed to fetch stations in region: $e",
      );
    }
  }

  @override
  Future<List<MapStationModel>> getSampleStations({int limit = 10}) async {
    try {
      print("DEBUG: Getting sample stations with limit=$limit");
      final db = await _databaseHelper.database;

      // Check if Geolocations table exists
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='Geolocations'",
      );

      if (tables.isEmpty) {
        print("ERROR: Geolocations table not found in database!");
        throw DatabaseException(
          message: "Geolocations table not found in database!",
        );
      }

      final List<Map<String, dynamic>> result = await db.rawQuery('''
        SELECT stationId, lat, lon FROM Geolocations ORDER BY RANDOM() LIMIT $limit
      ''');

      print("DEBUG: Retrieved ${result.length} sample stations");
      if (result.isNotEmpty) {
        print("DEBUG: First sample station: ${result.first}");
      }

      return result.map((map) {
        // Add default values for missing fields
        final enhancedMap = Map<String, dynamic>.from(map);
        enhancedMap['name'] ??= 'Station ${map['stationId']}';
        enhancedMap['type'] ??= 'river';
        enhancedMap['color'] ??= '#2389DA';

        return MapStationModel.fromMap(enhancedMap);
      }).toList();
    } catch (e) {
      print("ERROR: Failed to fetch sample stations: $e");
      throw DatabaseException(message: "Failed to fetch sample stations: $e");
    }
  }

  @override
  Future<int> getStationCount() async {
    try {
      print("DEBUG: Getting station count");
      final db = await _databaseHelper.database;

      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM Geolocations',
      );
      final count = result.first['count'] as int;
      print("DEBUG: Station count = $count");
      return count;
    } catch (e) {
      print("ERROR: Failed to get station count: $e");
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
      print(
        "DEBUG: Getting nearest stations to ($lat, $lon) with radius=$radius, limit=$limit",
      );
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
        FROM Geolocations
        WHERE $haversineFormula < $radius
        ORDER BY distance
        LIMIT $limit
      ''');

      print("DEBUG: Retrieved ${result.length} nearest stations");
      if (result.isNotEmpty) {
        print("DEBUG: First nearest station: ${result.first}");
      }

      return result.map((map) {
        // Add default values for missing fields
        final enhancedMap = Map<String, dynamic>.from(map);
        enhancedMap['name'] ??= 'Station ${map['stationId']}';
        enhancedMap['type'] ??= 'river';
        enhancedMap['color'] ??= '#2389DA';

        return MapStationModel.fromMap(enhancedMap);
      }).toList();
    } catch (e) {
      print("ERROR: Failed to fetch nearest stations: $e");
      throw DatabaseException(message: "Failed to fetch nearest stations: $e");
    }
  }
}
