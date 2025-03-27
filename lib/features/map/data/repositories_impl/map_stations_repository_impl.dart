// lib/features/map/data/repositories_impl/map_stations_repository_impl.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:rivr/common/data/local/database_helper.dart';
import 'package:rivr/features/map/data/datasources/stations_database_helper.dart';
import 'package:rivr/features/map/domain/repositories/map_stations_repository.dart';
import 'package:sqflite/sqflite.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class MapStationsRepositoryImpl implements MapStationsRepository {
  final DatabaseHelper _databaseHelper;
  final Map<int, Color> _stationColorCache = {};

  MapStationsRepositoryImpl({DatabaseHelper? databaseHelper})
    : _databaseHelper = databaseHelper ?? DatabaseHelper();

  Future<bool> get _hasInternetConnection async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  @override
  Future<List<Marker>> getMarkersFromVisibleBounds(
    double minLat,
    double maxLat,
    double minLon,
    double maxLon,
    LatLng? selectedMarkerPosition,
  ) async {
    // Get an instance of the Database from the DatabaseHelper class
    final Database db = await _databaseHelper.database;

    // Fetch station locations using the database helper
    List<Map<String, dynamic>> allStations = await getStationsLocations(
      db,
      minLat,
      maxLat,
      minLon,
      maxLon,
    );

    // Load favorite stations for color coding
    final List<Map<String, dynamic>> favoriteStations = await db.query(
      'Favorites',
    );
    final Set<int> favoriteStationIds =
        favoriteStations
            .map<int>((station) => station['stationId'] as int)
            .toSet();

    List<Marker> markers = [];
    for (var station in allStations) {
      bool isSelected =
          selectedMarkerPosition != null &&
          station['lat'] == selectedMarkerPosition.latitude &&
          station['lon'] == selectedMarkerPosition.longitude;

      bool isFavorite = favoriteStationIds.contains(station['stationId']);
      Color markerColor = _getMarkerColor(station['stationId'], isFavorite);

      markers.add(
        Marker(
          width: 200,
          height: 200,
          point: LatLng(station['lat'], station['lon']),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Shadow Effect (Only for Selected Marker)
              if (isSelected)
                Container(
                  width:
                      65, // Slightly larger than the icon for a glowing effect
                  height: 65,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 5,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),

              // Main Marker Icon
              Icon(
                Icons.water_drop,
                size: isSelected ? 60 : 40,
                color:
                    isSelected
                        ? const Color.fromARGB(
                          255,
                          8,
                          0,
                          255,
                        ) // Selected marker
                        : markerColor, // Regular marker with conditional color
              ),

              // Favorite Indicator
              if (isFavorite)
                Positioned(
                  top: isSelected ? 0 : 10,
                  right: isSelected ? 0 : 10,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.yellow,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.star,
                      size: 10,
                      color: Colors.orangeAccent,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return markers;
  }

  // Method to get marker color based on station data
  Color _getMarkerColor(int stationId, bool isFavorite) {
    // Return from cache if available
    if (_stationColorCache.containsKey(stationId)) {
      return _stationColorCache[stationId]!;
    }

    // Define color based on favorite status or other logic
    Color color =
        isFavorite
            ? Colors.deepPurple
            : const Color.fromARGB(255, 33, 150, 243);

    // Cache the color
    _stationColorCache[stationId] = color;

    return color;
  }

  // Fetch station details with caching
  Future<Map<String, dynamic>?> getStationDetails(int stationId) async {
    final Database db = await _databaseHelper.database;

    // First check cached details
    final List<Map<String, dynamic>> stationDetails = await db.query(
      'StationDetails',
      where: 'stationId = ?',
      whereArgs: [stationId],
    );

    if (stationDetails.isNotEmpty) {
      final details = stationDetails.first;
      final timestamp = details['timestamp'] as int;
      final ageInHours =
          (DateTime.now().millisecondsSinceEpoch - timestamp) / (3600 * 1000);

      // Return cached data if it's less than 24 hours old
      if (ageInHours < 24) {
        return details;
      }
    }

    // If no valid cache or we need fresh data and have internet
    final hasInternet = await _hasInternetConnection;
    if (hasInternet) {
      // In a real implementation, you would fetch from an API
      // For this example, we'll simulate by getting data from the Geolocations table
      final List<Map<String, dynamic>> geolocations = await db.query(
        'Geolocations',
        where: 'stationId = ?',
        whereArgs: [stationId],
      );

      if (geolocations.isNotEmpty) {
        final stationData = geolocations.first;
        final timestamp = DateTime.now().millisecondsSinceEpoch;

        // Save or update the station details
        await db.insert('StationDetails', {
          'stationId': stationId,
          'name': 'Station $stationId', // Would come from API
          'lat': stationData['lat'],
          'lon': stationData['lon'],
          'lastMeasurement': 0.0, // Would come from API
          'timestamp': timestamp,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        return {
          'stationId': stationId,
          'name': 'Station $stationId',
          'lat': stationData['lat'],
          'lon': stationData['lon'],
          'lastMeasurement': 0.0,
          'timestamp': timestamp,
        };
      }
    } else if (stationDetails.isNotEmpty) {
      // Return expired cache if no internet
      return stationDetails.first;
    }

    return null;
  }

  // Method to create the StationDetails table if needed
  Future<void> ensureStationDetailsTable() async {
    final Database db = await _databaseHelper.database;

    await db.execute('''
      CREATE TABLE IF NOT EXISTS StationDetails (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stationId INTEGER NOT NULL UNIQUE,
        name TEXT,
        lat REAL,
        lon REAL,
        lastMeasurement REAL,
        timestamp INTEGER
      )
    ''');
  }
}
