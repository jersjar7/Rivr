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

    try {
      final result = await getStationsInRegion(
        bounds.southwest.coordinates.lat.toDouble(),
        bounds.northeast.coordinates.lat.toDouble(),
        bounds.southwest.coordinates.lng.toDouble(),
        bounds.northeast.coordinates.lng.toDouble(),
        limit: limit,
      );

      result.fold(
        (failure) {
          _setError(failure.message);
        },
        (stations) {
          _stations = stations;
          _status = StationLoadingStatus.loaded;
          _errorMessage = null;
          notifyListeners();
        },
      );
    } catch (e) {
      _setError('Failed to load stations: ${e.toString()}');
    }
  }

  // Load sample stations (for low zoom levels)
  Future<void> loadSampleStations({int limit = 10}) async {
    _setLoading();
    print(
      "DEBUG: Provider loadSampleStations method called with limit: $limit",
    );

    try {
      print("STATION PROVIDER: Loading sample stations, limit=$limit");
      final result = await getSampleStations(limit: limit);

      result.fold(
        (failure) {
          _setError(failure.message);
          print("DEBUG: Provider received failure: ${failure.message}");
          print(
            "STATION PROVIDER: Error loading sample stations: ${failure.message}",
          );
        },
        (stations) {
          _stations = stations;
          print("DEBUG: Stations set in provider: ${_stations.length}");
          if (_stations.isNotEmpty) {
            print(
              "DEBUG: First station: id=${_stations.first.stationId}, pos=(${_stations.first.lat}, ${_stations.first.lon})",
            );
          } else {
            print("DEBUG: Provider received empty stations list");
          }

          print(
            "STATION PROVIDER: Successfully loaded ${stations.length} sample stations",
          );

          // Log details of the first station for debugging
          if (stations.isNotEmpty) {
            final first = stations.first;
            print(
              "STATION PROVIDER: First station: id=${first.stationId}, name=${first.name ?? 'unnamed'}, position=(${first.lat}, ${first.lon})",
            );
          } else {
            print(
              "STATION PROVIDER: WARNING - No stations were returned from getSampleStations",
            );
          }

          _status = StationLoadingStatus.loaded;
          _errorMessage = null;
          notifyListeners();
        },
      );
    } catch (e) {
      print("DEBUG: Provider caught exception: $e");
      print("STATION PROVIDER: Exception loading sample stations: $e");
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

    try {
      final result = await getNearestStations(
        lat,
        lon,
        limit: limit,
        radius: radius,
      );

      result.fold(
        (failure) {
          _setError(failure.message);
        },
        (stations) {
          _stations = stations;
          _status = StationLoadingStatus.loaded;
          _errorMessage = null;
          notifyListeners();
        },
      );
    } catch (e) {
      _setError('Failed to load nearest stations: ${e.toString()}');
    }
  }

  // Clear all stations
  void clearStations() {
    _stations = [];
    _selectedStation = null;
    _status = StationLoadingStatus.initial;
    _errorMessage = null;
    notifyListeners();
  }

  // Select a station
  void selectStation(MapStation station) {
    _selectedStation = station;
    notifyListeners();
  }

  // Deselect the current station
  void deselectStation() {
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
