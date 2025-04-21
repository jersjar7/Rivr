// lib/features/map/presentation/providers/station_provider.dart

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../domain/entities/map_station.dart';
import '../../domain/usecases/get_nearest_stations.dart';
import '../../domain/usecases/get_sample_stations.dart';
import '../../domain/usecases/get_stations_in_region.dart';

enum StationLoadingStatus { initial, loading, loaded, error }

class StationProvider with ChangeNotifier {
  // Use cases
  final GetStationsInRegion getStationsInRegion;
  final GetSampleStations getSampleStations;
  final GetNearestStations getNearestStations;

  // State
  List<MapStation> _stations = [];
  List<MapStation> get stations => _stations;

  StationLoadingStatus _status = StationLoadingStatus.initial;
  StationLoadingStatus get status => _status;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  MapStation? _selectedStation;
  MapStation? get selectedStation => _selectedStation;

  StationProvider({
    required this.getStationsInRegion,
    required this.getSampleStations,
    required this.getNearestStations,
  });

  // Load stations in a specific region
  Future<void> loadStationsInRegion(
    CoordinateBounds bounds, {
    int limit = 1000,
  }) async {
    _setLoading();
    print(
      "DEBUG: StationProvider.loadStationsInRegion called with bounds: $bounds, limit: $limit",
    );

    try {
      final southwest = bounds.southwest.coordinates;
      final northeast = bounds.northeast.coordinates;

      final result = await getStationsInRegion(
        southwest.lat.toDouble(),
        northeast.lat.toDouble(),
        southwest.lng.toDouble(),
        northeast.lng.toDouble(),
        limit: limit,
      );

      result.fold(
        (failure) {
          print(
            "ERROR: StationProvider failed to load stations in region: ${failure.message}",
          );
          _setError(failure.message);
        },
        (stations) {
          _stations = stations;
          print(
            "DEBUG: StationProvider loaded ${stations.length} stations in region",
          );
          if (stations.isNotEmpty) {
            print(
              "DEBUG: First station: id=${stations.first.stationId}, position=(${stations.first.lat}, ${stations.first.lon})",
            );
          }
          _status = StationLoadingStatus.loaded;
          _errorMessage = null;
          notifyListeners();
        },
      );
    } catch (e) {
      print("ERROR: StationProvider exception loading stations in region: $e");
      _setError('Failed to load stations: ${e.toString()}');
    }
  }

  // Load sample stations (for low zoom levels)
  Future<void> loadSampleStations({int limit = 10}) async {
    _setLoading();
    print(
      "DEBUG: StationProvider.loadSampleStations called with limit: $limit",
    );

    try {
      final result = await getSampleStations(limit: limit);

      result.fold(
        (failure) {
          print(
            "ERROR: StationProvider failed to load sample stations: ${failure.message}",
          );
          _setError(failure.message);
        },
        (stations) {
          _stations = stations;
          print(
            "DEBUG: StationProvider loaded ${stations.length} sample stations",
          );
          if (stations.isNotEmpty) {
            print(
              "DEBUG: First station: id=${stations.first.stationId}, position=(${stations.first.lat}, ${stations.first.lon})",
            );
          }
          _status = StationLoadingStatus.loaded;
          _errorMessage = null;
          notifyListeners();
        },
      );
    } catch (e) {
      print("ERROR: StationProvider exception loading sample stations: $e");
      _setError('Failed to load sample stations: ${e.toString()}');
    }
  }

  // Get nearest stations to a point
  Future<void> loadNearestStations(
    double lat,
    double lon, {
    int limit = 5,
    double radius = 50.0,
  }) async {
    _setLoading();
    print(
      "DEBUG: StationProvider.loadNearestStations called with lat: $lat, lon: $lon, limit: $limit, radius: $radius",
    );

    try {
      final result = await getNearestStations(
        lat,
        lon,
        limit: limit,
        radius: radius,
      );

      result.fold(
        (failure) {
          print(
            "ERROR: StationProvider failed to load nearest stations: ${failure.message}",
          );
          _setError(failure.message);
        },
        (stations) {
          _stations = stations;
          print(
            "DEBUG: StationProvider loaded ${stations.length} nearest stations",
          );
          if (stations.isNotEmpty) {
            print(
              "DEBUG: First station: id=${stations.first.stationId}, position=(${stations.first.lat}, ${stations.first.lon})",
            );
          }
          _status = StationLoadingStatus.loaded;
          _errorMessage = null;
          notifyListeners();
        },
      );
    } catch (e) {
      print("ERROR: StationProvider exception loading nearest stations: $e");
      _setError('Failed to load nearest stations: ${e.toString()}');
    }
  }

  // Clear all stations
  void clearStations() {
    print("DEBUG: StationProvider.clearStations called");
    _stations = [];
    _selectedStation = null;
    _status = StationLoadingStatus.initial;
    _errorMessage = null;
    notifyListeners();
  }

  // Select a station
  void selectStation(MapStation station) {
    print(
      "DEBUG: StationProvider.selectStation called with station id: ${station.stationId}",
    );
    _selectedStation = station;
    notifyListeners();
  }

  // Deselect the current station
  void deselectStation() {
    print("DEBUG: StationProvider.deselectStation called");
    _selectedStation = null;
    notifyListeners();
  }

  // Helper methods to update state
  void _setLoading() {
    _status = StationLoadingStatus.loading;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    _status = StationLoadingStatus.error;
    _errorMessage = message;
    notifyListeners();
  }
}
