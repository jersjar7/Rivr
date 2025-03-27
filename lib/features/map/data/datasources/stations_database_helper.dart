// lib/features/map/data/datasources/stations_database_helper.dart
import 'package:sqflite/sqflite.dart';

/// Fetches station locations within the given bounds from the database
Future<List<Map<String, dynamic>>> getStationsLocations(
  Database db,
  double minLat,
  double maxLat,
  double minLon,
  double maxLon,
) async {
  // Perform the query
  final queryInBoundStations = await db.rawQuery(
    "SELECT lat, lon, stationId FROM Geolocations WHERE lat BETWEEN ? AND ? AND lon BETWEEN ? AND ?",
    [minLat, maxLat, minLon, maxLon],
  );

  return queryInBoundStations;
}
