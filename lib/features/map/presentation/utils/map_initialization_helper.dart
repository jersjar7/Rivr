// lib/features/map/presentation/utils/map_initialization_helper.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:rivr/common/data/local/database_helper.dart';

import '../../../../core/constants/map_constants.dart';
import '../providers/map_provider.dart';
import '../providers/station_provider.dart';
import '../providers/enhanced_clustered_map_provider.dart';
import 'map_style_manager.dart';

/// A helper class that handles map initialization and related operations
class MapInitializationHelper {
  // Map style manager instance
  MapStyleManager? _styleManager;

  /// Initialize the map when it's first created
  Future<void> initializeMap({
    required BuildContext context,
    required MapboxMap mapboxMap,
    required MapProvider mapProvider,
    required StationProvider stationProvider,
    required EnhancedClusteredMapProvider clusteredMapProvider,
    required bool is3DMode,
  }) async {
    try {
      // Initialize map in the provider
      mapProvider.onMapCreated(mapboxMap);

      // Create style manager
      _styleManager = MapStyleManager(
        mapboxMap: mapboxMap,
        clusterProvider: clusteredMapProvider,
        initialStyle: mapProvider.currentStyle,
      );

      // Check database structure and tables
      _checkDatabaseStructure(context);

      // Load map resources first
      await _loadMapResources(mapboxMap);

      // Initialize 3D terrain if needed
      if (is3DMode) {
        _styleManager!.enable3DTerrain(
          exaggeration: MapConstants.terrainExaggeration,
        );
      }

      print("MAP INIT: Map initialization completed");

      // Wait for a moment to ensure style is fully loaded
      await Future.delayed(const Duration(milliseconds: 500));

      // Initialize clustering with better error handling
      clusteredMapProvider.initialize(mapboxMap).then((success) {
        if (success) {
          print("MAP INIT: Clustering initialized successfully");

          // Load initial stations right away
          _loadInitialStations(
            mapboxMap,
            mapProvider,
            stationProvider,
            clusteredMapProvider,
          );
        } else {
          print("MAP INIT: Clustering initialization failed");
          // Retry once after a delay
          Future.delayed(const Duration(seconds: 1), () {
            print("MAP INIT: Retrying clustering initialization");
            clusteredMapProvider.initialize(mapboxMap).then((retrySuccess) {
              if (retrySuccess) {
                print("MAP INIT: Retry successful, loading stations");
                _loadInitialStations(
                  mapboxMap,
                  mapProvider,
                  stationProvider,
                  clusteredMapProvider,
                );
              } else {
                print(
                  "MAP INIT: Retry failed, falling back to regular markers",
                );
                // Could implement a fallback here
              }
            });
          });
        }
      });
    } catch (e) {
      print("MAP INIT: Error in initializeMap: $e");
    }
  }

  /// Check database structure and display warnings if needed
  void _checkDatabaseStructure(BuildContext context) {
    final databaseHelper = DatabaseHelper();
    databaseHelper.database.then((db) {
      db
          .rawQuery("SELECT COUNT(*) as count FROM Geolocations")
          .then((result) {
            final count = result.first['count'] as int;
            print("MAP INIT: Geolocations table has $count stations");

            if (count == 0) {
              // Show no data error
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No station data found in database!'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 5),
                ),
              );
            }
          })
          .catchError((e) {
            print("MAP INIT: Error checking Geolocations table: $e");
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error accessing station data: $e'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 5),
              ),
            );
          });
    });
  }

  /// Load map resources like marker images
  Future<void> _loadMapResources(MapboxMap mapboxMap) async {
    try {
      // Preload marker images for better display
      final defaultMarkerData = await rootBundle.load(
        'assets/img/marker_default.png',
      );
      final selectedMarkerData = await rootBundle.load(
        'assets/img/marker_selected.png',
      );

      // For proper image loading, you need to get the actual image dimensions
      final defaultImage = await decodeImageFromList(
        defaultMarkerData.buffer.asUint8List(),
      );
      final selectedImage = await decodeImageFromList(
        selectedMarkerData.buffer.asUint8List(),
      );

      // Create MbxImage objects with proper dimensions
      final defaultMbxImage = MbxImage(
        width: defaultImage.width,
        height: defaultImage.height,
        data: defaultMarkerData.buffer.asUint8List(),
      );

      final selectedMbxImage = MbxImage(
        width: selectedImage.width,
        height: selectedImage.height,
        data: selectedMarkerData.buffer.asUint8List(),
      );

      // Add images to style with proper parameters
      await mapboxMap.style.addStyleImage(
        "marker-default",
        1.0, // scale
        defaultMbxImage,
        false, // sdf
        [], // stretchX
        [], // stretchY
        null, // content
      );

      await mapboxMap.style.addStyleImage(
        "marker-selected",
        1.0, // scale
        selectedMbxImage,
        false, // sdf
        [], // stretchX
        [], // stretchY
        null, // content
      );

      print("MAP INIT: Marker resources loaded successfully");
      return;
    } catch (e) {
      print("MAP INIT: Error loading marker resources: $e");
      // Don't rethrow - we can continue without custom markers
      return;
    }
  }

  /// Load initial stations from visible map region
  void _loadInitialStations(
    MapboxMap mapboxMap,
    MapProvider mapProvider,
    StationProvider stationProvider,
    EnhancedClusteredMapProvider clusteredMapProvider,
  ) {
    print("MAP INIT: Loading initial stations");

    // Grab the current visible region from your MapProvider
    final region = mapProvider.visibleRegion;
    if (region == null) {
      print("MAP INIT: No visible region yet, skipping station load");
      return;
    }

    // Load every station in that region
    stationProvider
        .loadStationsInRegion(
          region,
          limit: MapConstants.maxMarkersForPerformance,
        )
        .then((_) {
          final stations = stationProvider.stations;
          print("MAP INIT: Loaded ${stations.length} stations in region");

          if (stations.isEmpty) {
            print("MAP INIT: No stations in database for this region!");
            return;
          }

          // Push them into your clustering provider
          clusteredMapProvider
              .updateStations(mapboxMap, stations)
              .then((_) => print("MAP INIT: Initial clusters updated"))
              .catchError((e) => print("MAP INIT: Clustering failed: $e"));
        })
        .catchError((e) {
          print("MAP INIT: Failed to load stations in region: $e");
        });
  }

  /// Change map style
  Future<void> changeMapStyle({
    required MapboxMap mapboxMap,
    required String newStyle,
    required bool is3DMode,
    required MapProvider mapProvider,
    required StationProvider stationProvider,
    required EnhancedClusteredMapProvider clusteredMapProvider,
  }) async {
    if (_styleManager == null) return;

    print("MAP INIT: Starting style change to $newStyle");

    _styleManager!.changeMapStyle(
      newStyle,
      onStyleChanged: () {
        print("MAP INIT: Style changed callback triggered");

        // Update the style in map provider
        if (mapProvider.currentStyle != newStyle) {
          mapProvider.setCurrentStyle(newStyle);
        }

        // Restore 3D terrain if needed
        if (is3DMode) {
          _styleManager!.enable3DTerrain();
        }

        print("MAP INIT: Style change completed");

        // NOTE: Station restoration is handled automatically by MapStyleManager
        // via clusterProvider.handleMapStyleChanged(mapboxMap) - no manual intervention needed
      },
    );
  }

  /// Toggle 3D terrain
  Future<void> toggle3DTerrain({
    required MapboxMap mapboxMap,
    required bool enable,
  }) async {
    if (_styleManager == null) return;

    _styleManager!.toggle3DTerrain(enable);
  }

  /// Refresh stations
  Future<void> refreshStations({
    required MapboxMap mapboxMap,
    required MapProvider mapProvider,
    required StationProvider stationProvider,
    required EnhancedClusteredMapProvider clusteredMapProvider,
  }) async {
    await mapProvider.updateVisibleRegion();
    final bounds = mapProvider.visibleRegion;
    if (bounds == null) return;

    stationProvider
        .loadStationsInRegion(bounds)
        .then(
          (_) => clusteredMapProvider.updateStations(
            mapboxMap,
            stationProvider.stations,
          ),
        )
        .catchError((e) => print("MAP INIT: Error refreshing stations: $e"));
  }
}
