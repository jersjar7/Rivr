// lib/features/map/presentation/providers/enhanced_clustered_map_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../domain/entities/map_station.dart';
import '../../domain/usecases/dispose_clustering.dart';
import '../../domain/usecases/initialize_clustering.dart';
import '../../domain/usecases/setup_cluster_tap_handling.dart';
import '../../domain/usecases/update_cluster_data.dart';

enum ClusteringStatus { initial, initializing, ready, updating, error }

/// Interface for cluster map data source operations.
abstract class ClusteredMapDataSource {
  /// Initialize cluster sources and layers on the map
  Future<void> initializeClusterLayers(MapboxMap mapboxMap);

  /// Update station data in the cluster source
  Future<void> updateClusterData(
    MapboxMap mapboxMap,
    List<MapStation> stations,
  );

  /// Clean up resources
  Future<void> dispose(MapboxMap mapboxMap);

  /// Setup tap handling for clusters and individual points
  Future<void> setupTapHandling(
    MapboxMap mapboxMap,
    Function(MapStation) onStationTapped,
    Function(Point, List<MapStation>) onClusterTapped,
  );
}

class ClusteredMapProvider with ChangeNotifier {
  // Use cases
  final InitializeClustering initializeClustering;
  final UpdateClusterData updateClusterData;
  final SetupClusterTapHandling setupClusterTapHandling;
  final DisposeClustering disposeClustering;

  // State
  ClusteringStatus _status = ClusteringStatus.initial;
  ClusteringStatus get status => _status;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  MapStation? _selectedStation;
  MapStation? get selectedStation => _selectedStation;

  List<MapStation> _currentStations = [];
  List<MapStation> get currentStations => _currentStations;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Debounce timer
  Timer? _debounceTimer;

  ClusteredMapProvider({
    required this.initializeClustering,
    required this.updateClusterData,
    required this.setupClusterTapHandling,
    required this.disposeClustering,
  });

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Initialize clustering on the map
  Future<void> initialize(MapboxMap mapboxMap) async {
    if (_isInitialized) return;

    _setStatus(ClusteringStatus.initializing);

    final result = await initializeClustering(mapboxMap);

    result.fold(
      (failure) {
        _setError(failure.message);
      },
      (_) {
        _isInitialized = true;
        _setStatus(ClusteringStatus.ready);
        _setupHandlers(mapboxMap);
      },
    );
  }

  /// Update the stations in the clustering system
  Future<List<MapStation>> updateStations(
    MapboxMap mapboxMap,
    List<MapStation> stations,
  ) async {
    if (!_isInitialized) {
      await initialize(mapboxMap);
    }

    // Don't update if the stations are the same
    if (_areStationsEqual(_currentStations, stations)) {
      return _currentStations;
    }

    _setStatus(ClusteringStatus.updating);
    _currentStations = List.from(stations);

    final result = await updateClusterData(mapboxMap, stations);

    return result.fold(
      (failure) {
        _setError(failure.message);
        return <MapStation>[];
      },
      (_) {
        _setStatus(ClusteringStatus.ready);
        return _currentStations;
      },
    );
  }

  /// Helper method to set up tap handlers for clusters and stations
  Future<void> _setupHandlers(MapboxMap mapboxMap) async {
    final result = await setupClusterTapHandling(
      mapboxMap,
      _onStationTapped,
      _onClusterTapped,
    );

    result.fold((failure) {
      print('Warning: Failed to setup tap handlers: ${failure.message}');
    }, (_) => print('Tap handlers set up successfully'));
  }

  /// Handle when an individual station is tapped
  void _onStationTapped(MapStation station) {
    _selectedStation = station;
    notifyListeners();
  }

  /// Handle when a cluster is tapped
  void _onClusterTapped(Point point, List<MapStation> stationsInCluster) {
    if (stationsInCluster.isEmpty) return;

    // For simplicity, just select the first station in the cluster
    // In a real app, you might want to show a list of all stations or zoom in
    _selectedStation = stationsInCluster.first;
    notifyListeners();
  }

  /// Clean up clustering resources
  Future<void> cleanupClustering(MapboxMap mapboxMap) async {
    if (!_isInitialized) return;

    final result = await disposeClustering(mapboxMap);

    result.fold(
      (failure) {
        print('Warning: Failed to clean up clustering: ${failure.message}');
      },
      (_) {
        _isInitialized = false;
        _currentStations = [];
        _selectedStation = null;
        _status = ClusteringStatus.initial;
        print('Clustering cleaned up successfully');
      },
    );
  }

  /// Select a station programmatically
  void selectStation(MapStation station) {
    _selectedStation = station;
    notifyListeners();
  }

  /// Deselect the current station
  void deselectStation() {
    _selectedStation = null;
    notifyListeners();
  }

  /// Helper method to trigger a debounced operation
  void triggerDebounceTimer(VoidCallback callback, {Duration? duration}) {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }

    _debounceTimer = Timer(
      duration ?? const Duration(milliseconds: 300),
      callback,
    );
  }

  // Helper methods
  void _setStatus(ClusteringStatus status) {
    _status = status;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _status = ClusteringStatus.error;
    notifyListeners();
  }

  bool _areStationsEqual(List<MapStation> list1, List<MapStation> list2) {
    if (list1.length != list2.length) return false;

    // Simple check for now - just compare lengths and check if all IDs are the same
    final set1 = list1.map((s) => s.stationId).toSet();
    final set2 = list2.map((s) => s.stationId).toSet();

    return set1.containsAll(set2) && set2.containsAll(set1);
  }
}
