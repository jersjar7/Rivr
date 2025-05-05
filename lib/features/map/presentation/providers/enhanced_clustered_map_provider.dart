// Update to lib/features/map/presentation/providers/enhanced_clustered_map_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../domain/entities/map_station.dart';
import '../../domain/usecases/dispose_clustering.dart';
import '../../domain/usecases/initialize_clustering.dart';
import '../../domain/usecases/setup_cluster_tap_handling.dart';
import '../../domain/usecases/update_cluster_data.dart';

enum ClusteringStatus {
  initial, // Just created
  initializing, // In the process of initializing
  ready, // Ready for use
  updating, // Currently updating data
  error, // Error state
  disposed, // Resources cleaned up
}

class EnhancedClusteredMapProvider with ChangeNotifier {
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
  bool _isInitializing = false;

  // Pending operations queue to handle race conditions
  final List<Function> _pendingOperations = [];
  bool _isProcessingOperation = false;

  // Style change counter for tracking map style changes
  int _styleChangeCounter = 0;

  // Debounce timer
  Timer? _debounceTimer;

  EnhancedClusteredMapProvider({
    required this.initializeClustering,
    required this.updateClusterData,
    required this.setupClusterTapHandling,
    required this.disposeClustering,
  });

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _pendingOperations.clear();
    _status = ClusteringStatus.disposed;
    super.dispose();
  }

  /// Initialize clustering on the map
  Future<bool> initialize(MapboxMap mapboxMap) async {
    if (_isInitialized) {
      print('Clustering already initialized');
      return true;
    }

    // Add a guard against multiple initialization attempts
    if (_isInitializing) {
      print('Clustering initialization already in progress');
      // Wait for existing initialization to complete
      int attempts = 0;
      while (_isInitializing && attempts < 10) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
      return _isInitialized;
    }

    _isInitializing = true;

    try {
      _setStatus(ClusteringStatus.initializing);

      // Wait for map style to be fully loaded
      await Future.delayed(const Duration(milliseconds: 500));

      final result = await initializeClustering(mapboxMap);

      return result.fold(
        (failure) {
          _setError(failure.message);
          _isInitializing = false;
          return false;
        },
        (_) async {
          _isInitialized = true;
          _isInitializing = false;
          _setStatus(ClusteringStatus.ready);

          // Setup handlers after initialization
          await _setupHandlers(mapboxMap);
          return true;
        },
      );
    } catch (e) {
      _setError('Initialization error: $e');
      _isInitializing = false;
      return false;
    }
  }

  /// Update the stations in the clustering system
  Future<void> updateStations(
    MapboxMap mapboxMap,
    List<MapStation> stations,
  ) async {
    // If not initialized, initialize first
    if (!_isInitialized) {
      final initialized = await initialize(mapboxMap);
      if (!initialized) {
        print('Failed to initialize clustering before updating stations');
        return;
      }
    }

    // Queue the update operation
    return _queueOperation(() async {
      try {
        _setStatus(ClusteringStatus.updating);
        _currentStations = List.from(stations);

        // Pass the selected station to the data source
        final result = await updateClusterData(
          mapboxMap,
          stations,
          // Pass the currently selected station
          selectedStation: _selectedStation,
        );

        result.fold(
          (failure) {
            _setError(failure.message);

            // Attempt recovery if it appears to be a style change issue
            if (failure.message.contains('source') ||
                failure.message.contains('layer')) {
              print('Attempting recovery after source/layer error');
              _recoverFromStyleChange(mapboxMap, stations);
            }
          },
          (_) {
            _setStatus(ClusteringStatus.ready);
          },
        );
      } catch (e) {
        _setError('Update error: $e');

        // Try automatic recovery
        _recoverFromStyleChange(mapboxMap, stations);
      }
    });
  }

  /// Handle map style changes by reinitializing clustering
  void handleMapStyleChanged(MapboxMap mapboxMap) {
    _styleChangeCounter++;
    final currentStyleChange = _styleChangeCounter;

    print('Map style changed, will reinitialize clustering after a delay');

    // Use debounce to avoid multiple reinitializations during rapid style changes
    _debounceReinitialization(() async {
      // Skip if another style change happened while waiting
      if (currentStyleChange != _styleChangeCounter) {
        print(
          'Skipping reinitialization as another style change was triggered',
        );
        return;
      }

      print('Reinitializing clustering after style change');

      // First attempt a cleanup
      try {
        await disposeClustering(mapboxMap);
        print("Successfully cleaned up previous clustering resources");
      } catch (e) {
        print("Warning: Error during clustering cleanup: $e");
        // Continue anyway
      }

      // Save current stations and selected station
      final currentStations = List<MapStation>.from(_currentStations);
      final savedSelectedStation = _selectedStation;

      // Reset initialization state
      _isInitialized = false;
      _currentStations = [];
      _setStatus(ClusteringStatus.initial);

      // Wait for style to be fully loaded
      await Future.delayed(const Duration(milliseconds: 800));

      // Now reinitialize
      final initialized = await initialize(mapboxMap);

      if (initialized && currentStations.isNotEmpty) {
        print(
          'Restoring ${currentStations.length} stations after style change',
        );
        // Restore selected station
        _selectedStation = savedSelectedStation;

        // Restore stations
        await updateStations(mapboxMap, currentStations);
      }
    }, duration: const Duration(milliseconds: 800));
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

    return _queueOperation(() async {
      try {
        final result = await disposeClustering(mapboxMap);

        result.fold(
          (failure) {
            print('Warning: Failed to clean up clustering: ${failure.message}');
          },
          (_) {
            _isInitialized = false;
            _currentStations = [];
            _selectedStation = null;
            _status = ClusteringStatus.disposed;
            print('Clustering cleaned up successfully');
          },
        );
      } catch (e) {
        print('Error during clustering cleanup: $e');
        // Still mark as disposed even if cleanup fails
        _isInitialized = false;
        _status = ClusteringStatus.disposed;
      }
    });
  }

  /// Select a station programmatically
  void selectStation(MapStation station) {
    // Store previous selection state to check if it changed
    final previouslySelected = _selectedStation?.stationId;

    // Update the selected station
    _selectedStation = station;

    // If we have a map with stations loaded, update the marker styling
    if (_isInitialized && _currentStations.isNotEmpty) {
      // Only trigger the operation if the selection actually changed
      if (previouslySelected != station.stationId) {
        print('Selection changed, updating markers with new selected station');
        notifyListeners();
      }
    } else {
      // Just notify listeners if we don't need to update markers
      notifyListeners();
    }
  }

  /// Deselect the current station
  void deselectStation() {
    if (_selectedStation != null) {
      _selectedStation = null;
      notifyListeners();
    }
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

  /// Attempt to recover from a style change by reinitializing
  Future<void> _recoverFromStyleChange(
    MapboxMap mapboxMap,
    List<MapStation> stations,
  ) async {
    if (_status == ClusteringStatus.disposed) return;

    print('Recovering from potential style change');

    // Save current selected station
    final savedSelectedStation = _selectedStation;

    // Reset initialization state
    _isInitialized = false;

    // Wait a moment for the style to fully load
    await Future.delayed(const Duration(milliseconds: 500));

    // Try to reinitialize
    final initialized = await initialize(mapboxMap);

    if (initialized && stations.isNotEmpty) {
      // Restore selected station
      _selectedStation = savedSelectedStation;

      // Restore stations
      await updateStations(mapboxMap, stations);
    }
  }

  /// Queue operations to prevent race conditions
  Future<T> _queueOperation<T>(Future<T> Function() operation) async {
    _pendingOperations.add(operation);

    // If already processing an operation, wait for the queue
    if (_isProcessingOperation) {
      // Create a completer to wait for our turn
      final completer = Completer<T>();

      // Check periodically if it's our turn
      Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (!_isProcessingOperation && _pendingOperations.first == operation) {
          timer.cancel();
          _processNextOperation().then((_) => completer.complete(operation()));
        }
      });

      return completer.future;
    }

    // Process the queue
    await _processNextOperation();
    return operation();
  }

  /// Process the next operation in the queue
  Future<void> _processNextOperation() async {
    if (_pendingOperations.isEmpty || _isProcessingOperation) return;

    _isProcessingOperation = true;

    try {
      final operation = _pendingOperations.removeAt(0);
      await operation();
    } finally {
      _isProcessingOperation = false;

      // Process the next operation if there are more
      if (_pendingOperations.isNotEmpty) {
        _processNextOperation();
      }
    }
  }

  /// Debounce reinitialization to avoid multiple calls
  void _debounceReinitialization(
    Future<void> Function() callback, {
    Duration? duration,
  }) {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }

    _debounceTimer = Timer(
      duration ?? const Duration(milliseconds: 500),
      () async {
        await callback();
      },
    );
  }

  // Helper methods
  void _setStatus(ClusteringStatus status) {
    if (_status != status) {
      _status = status;
      notifyListeners();
    }
  }

  void _setError(String message) {
    _errorMessage = message;
    _status = ClusteringStatus.error;
    notifyListeners();
  }
}
