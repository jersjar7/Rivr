// lib/features/map/presentation/utils/map_tap_handler.dart

import 'dart:math' as Math;
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:rivr/core/di/service_locator.dart';
import 'package:rivr/core/services/stream_name_service.dart';
import 'package:rivr/features/map/domain/entities/map_station.dart';
import 'package:rivr/features/auth/presentation/providers/auth_provider.dart';

import '../helpers/stream_info_helper.dart';
import '../providers/enhanced_clustered_map_provider.dart';
import '../providers/station_provider.dart';
import '../providers/map_provider.dart';
import '../widgets/stream_info_panel.dart';
import 'user_location_marker_manager.dart';
import '../../../../core/constants/map_constants.dart';

class MapTapHandler {
  final MapboxMap mapboxMap;
  final BuildContext context;
  final Function? onStationAddedToFavorites;
  final UserLocationMarkerManager?
  locationMarkerManager; // Add location marker manager

  // Track the currently displayed info panel
  StreamInfoPanel? _currentInfoPanel;
  OverlayEntry? _overlayEntry;

  // Store provider references to avoid context issues
  late final AuthProvider _authProvider;

  late final StreamNameService _streamNameService;
  late final StreamInfoHelper _streamInfoHelper;

  MapTapHandler({
    required this.mapboxMap,
    required this.context,
    this.onStationAddedToFavorites,
    this.locationMarkerManager, // Add location marker manager parameter
  }) {
    // Initialize provider references immediately
    _authProvider = Provider.of<AuthProvider>(context, listen: false);

    _streamNameService = sl<StreamNameService>();
    _streamInfoHelper = StreamInfoHelper(streamNameService: _streamNameService);
  }

  /// Set up the tap handler
  Future<void> setupTapHandlers() async {
    print("MapTapHandler: Setting up tap handlers");
    // The actual handling will be done via the handleMapTap method
  }

  /// Handle tap events from the map
  Future<void> handleMapTap(MapContentGestureContext tapContext) async {
    try {
      // Get providers
      final clusteredMapProvider = Provider.of<EnhancedClusteredMapProvider>(
        context,
        listen: false,
      );
      final stationProvider = Provider.of<StationProvider>(
        context,
        listen: false,
      );
      final mapProvider = Provider.of<MapProvider>(context, listen: false);

      // Get tap coordinates
      final screenCoord = tapContext.touchPosition;
      final mapCoord = tapContext.point;

      print(
        "Map tapped at screen coord: $screenCoord, map coord: ${mapCoord.coordinates.lat}, ${mapCoord.coordinates.lng}",
      );

      // First check if tap is on user location marker (if location marker manager is available)
      if (locationMarkerManager != null) {
        final isLocationMarkerTap = await _checkLocationMarkerTap(
          screenCoord,
          mapCoord,
        );
        if (isLocationMarkerTap) {
          locationMarkerManager!.handleLocationMarkerTap();
          return; // Early return if location marker was tapped
        }
      }

      // Query for features at the tap location (stations/clusters)
      final features = await queryFeaturesAtPoint(screenCoord);

      // If no features found, deselect current station and remove info panel
      if (features.isEmpty) {
        print("No features found at tap location, deselecting station");
        clusteredMapProvider.deselectStation();
        _removeInfoPanel();
        return;
      }

      // Process the tap based on the features found
      await processFeatures(
        features,
        mapCoord,
        clusteredMapProvider,
        stationProvider,
        mapProvider,
      );
    } catch (e) {
      print("Error handling map tap: $e");
    }
  }

  /// Check if the tap is on the user location marker
  Future<bool> _checkLocationMarkerTap(
    ScreenCoordinate screenCoord,
    Point mapCoord,
  ) async {
    if (locationMarkerManager == null) return false;

    try {
      // Query for features at the tap location specifically looking for user location markers
      final geometry = RenderedQueryGeometry.fromScreenCoordinate(screenCoord);
      final options = RenderedQueryOptions(
        layerIds: [], // Empty to query all layers
        filter: null,
      );

      final features = await mapboxMap.queryRenderedFeatures(geometry, options);

      // Check if any of the features are user location markers
      for (final feature in features) {
        if (feature?.queriedFeature.feature['iconImage'] ==
            'user-location-dot') {
          print("MapTapHandler: User location marker tapped");
          return true;
        }
      }

      return false;
    } catch (e) {
      print("MapTapHandler: Error checking location marker tap: $e");
      return false;
    }
  }

  /// Query for features at the given screen coordinate
  Future<List<QueriedRenderedFeature?>> queryFeaturesAtPoint(
    ScreenCoordinate point,
  ) async {
    try {
      // Create a rendered query geometry for the point
      final geometry = RenderedQueryGeometry.fromScreenCoordinate(point);

      // Query for rendered features at this point (excluding user location markers)
      final options = RenderedQueryOptions(
        layerIds: [
          'clusters',
          'unclustered-points',
          'unclustered-points-circle',
        ],
        filter: null,
      );

      final features = await mapboxMap.queryRenderedFeatures(geometry, options);

      if (features.isNotEmpty) {
        print("Found ${features.length} features at tap location");
      }

      return features;
    } catch (e) {
      print("Error querying features: $e");
      return [];
    }
  }

  /// Process the features found at the tap location
  Future<void> processFeatures(
    List<QueriedRenderedFeature?> features,
    Point mapCoord,
    EnhancedClusteredMapProvider clusteredMapProvider,
    StationProvider stationProvider,
    MapProvider mapProvider,
  ) async {
    if (features.isEmpty) return;

    // Get the first feature that is not null
    final feature = features.firstWhere((f) => f != null, orElse: () => null);
    if (feature == null) return;

    try {
      // Safely extract properties from the feature
      final Map<String, dynamic> properties = {};

      // Extract properties from the feature
      final queryFeature = feature.queriedFeature.feature;
      queryFeature.forEach((key, value) {
        if (key is String) {
          properties[key] = value;
        }
      });

      print("Feature properties: $properties");

      // Check for different cluster property patterns - both top-level and nested
      bool isCluster = false;

      // Check top-level properties
      if (properties.containsKey('cluster') && properties['cluster'] == true) {
        isCluster = true;
      } else if (properties.containsKey('point_count')) {
        isCluster = true;
      }

      // Check nested properties
      if (!isCluster &&
          properties.containsKey('properties') &&
          properties['properties'] is Map) {
        final nestedProps = properties['properties'] as Map;
        if (nestedProps.containsKey('cluster') &&
            nestedProps['cluster'] == true) {
          isCluster = true;
        } else if (nestedProps.containsKey('point_count')) {
          isCluster = true;
        }
      }

      print("DEBUG: Is cluster? $isCluster");

      // Handle cluster tap - USE THE isCluster VARIABLE
      if (isCluster) {
        print("DEBUG: Handling cluster tap");
        // Extract cluster properties from nested object if needed
        Map<String, dynamic> clusterProps = properties;
        if (properties.containsKey('properties') &&
            properties['properties'] is Map) {
          clusterProps = Map<String, dynamic>.from(properties);
          final nestedProps = properties['properties'] as Map;
          clusterProps.addAll(Map<String, dynamic>.from(nestedProps));
        }
        await handleClusterTap(clusterProps, mapCoord, mapProvider);
        // Remove info panel when zooming into a cluster
        _removeInfoPanel();
        return;
      }

      // Handle station tap - check for 'id' or 'properties.id'
      String? stationId;
      if (properties.containsKey('id')) {
        stationId = properties['id'].toString();
      } else if (properties.containsKey('properties') &&
          properties['properties'] is Map &&
          (properties['properties'] as Map).containsKey('id')) {
        stationId = properties['properties']['id'].toString();
      }

      if (stationId != null) {
        await handleStationTap(
          stationId,
          mapCoord,
          properties,
          clusteredMapProvider,
          stationProvider,
          mapProvider,
        );
        return;
      }
    } catch (e) {
      print("Error processing features: $e");
    }
  }

  /// Handle tap on a cluster
  Future<void> handleClusterTap(
    Map<String, dynamic> properties,
    Point mapCoord,
    MapProvider mapProvider,
  ) async {
    print("Tapped on cluster with ${properties['point_count']} points");

    // Show user-friendly message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please zoom in to select an individual station'),
        duration: Duration(seconds: 2),
      ),
    );

    // Zoom in to expand the cluster
    final newZoom = mapProvider.currentZoom + 2.0;

    mapboxMap.flyTo(
      CameraOptions(center: mapCoord, zoom: newZoom),
      MapAnimationOptions(
        duration: MapConstants.mapAnimationDurationMs,
        startDelay: MapConstants.mapAnimationDelayMs,
      ),
    );
  }

  // Helper function for parsing station IDs
  int parseStationId(String id) {
    try {
      // Try standard integer parsing first
      return int.parse(id);
    } catch (_) {
      try {
        // If that fails, try parsing as a double and converting to int
        return double.parse(id).toInt();
      } catch (_) {
        // As a last resort, try stripping the decimal part
        return int.parse(id.split('.')[0]);
      }
    }
  }

  /// Handle tap on an individual station
  Future<void> handleStationTap(
    String stationId,
    Point mapCoord,
    Map<String, dynamic> properties,
    EnhancedClusteredMapProvider clusteredMapProvider,
    StationProvider stationProvider,
    MapProvider mapProvider,
  ) async {
    print("Tapped on station with ID: $stationId");

    try {
      // Try to parse the station ID as an integer
      final int stationIdInt = parseStationId(stationId);

      // Initialize station name
      String stationName = "";

      // Extract station name from properties if available
      if (properties.containsKey('name') &&
          properties['name'] != null &&
          properties['name'].toString().isNotEmpty) {
        stationName = properties['name'].toString();
      } else if (properties.containsKey('properties') &&
          properties['properties'] is Map &&
          (properties['properties'] as Map).containsKey('name') &&
          (properties['properties'] as Map)['name'] != null &&
          (properties['properties'] as Map)['name'].toString().isNotEmpty) {
        stationName = (properties['properties'] as Map)['name'].toString();
      }

      print("Station name determined: $stationName");

      // Try to find the station in the provider's list
      MapStation? tappedStation;
      try {
        tappedStation = stationProvider.stations.firstWhere(
          (station) => station.stationId == stationIdInt,
        );
        print(
          "Found matching station in provider: ${tappedStation.stationId}, name: ${tappedStation.name}",
        );

        print(
          "MARKER TAPPED: Station ID: ${tappedStation.stationId}, Raw station name: '${tappedStation.name}'",
        );

        // Create a new station with our determined name
        tappedStation = MapStation(
          stationId: tappedStation.stationId,
          lat: tappedStation.lat,
          lon: tappedStation.lon,
          elevation: tappedStation.elevation,
          name: stationName, // Use our determined name
          type: tappedStation.type,
          description: tappedStation.description,
          color: tappedStation.color,
        );
      } catch (e) {
        // Station not found in provider's list, create a temporary one
        print("Station not found in provider, creating temporary station");
        tappedStation = MapStation(
          stationId: stationIdInt,
          lat: mapCoord.coordinates.lat.toDouble(),
          lon: mapCoord.coordinates.lng.toDouble(),
          name: stationName, // Use our determined name
        );
      }

      // Set this station as selected in the provider
      clusteredMapProvider.selectStation(tappedStation);

      // Center map on the selected station with a nice zoom level
      final currentZoom = await mapboxMap.getCameraState().then(
        (state) => state.zoom,
      );

      mapboxMap.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(tappedStation.lon, tappedStation.lat),
          ),
          zoom: Math.max(14.0, currentZoom), // Zoom in closer to the station
        ),
        MapAnimationOptions(
          duration: MapConstants.mapAnimationDurationMs,
          startDelay: MapConstants.mapAnimationDelayMs,
        ),
      );

      // Show the info panel for the selected station
      print("Showing info panel for station: ${tappedStation.stationId}");

      // Get the display name from StreamNameService
      String displayName = await _streamInfoHelper.getDisplayName(
        tappedStation,
        stationName,
      );

      _showInfoPanel(
        tappedStation,
        displayName,
        clusteredMapProvider,
        stationProvider,
        mapProvider,
      );
    } catch (e) {
      print("Error handling station tap: $e");
    }
  }

  /// Show the stream info panel for the selected station
  void _showInfoPanel(
    MapStation station,
    String displayName,
    EnhancedClusteredMapProvider clusteredMapProvider,
    StationProvider stationProvider,
    MapProvider mapProvider,
  ) {
    try {
      // Safety check - ensure we have a valid station ID
      if (station.stationId <= 0) {
        print("WARNING: Invalid station ID, not showing info panel");
        return;
      }

      // Remove existing panel first
      _removeInfoPanel();

      print("Creating info panel for station: ${station.stationId}");

      // Find the overlay to add our widget to
      final overlay = Overlay.of(context);

      // Create a new info panel
      _currentInfoPanel = StreamInfoPanel(
        station: station,
        displayName: displayName,
        onClose: () {
          // When closed, deselect the station and remove the panel
          print("Closing info panel");
          clusteredMapProvider.deselectStation();
          _removeInfoPanel();
        },
        onAddToFavorites: (station) async {
          await _handleAddToFavorites(station);
        },
        onViewForecast: (reachId, stationName) {
          // Navigate to the forecast page
          Navigator.pushNamed(
            context,
            '/forecast',
            arguments: {'reachId': reachId, 'stationName': stationName},
          );
        },
        onNavigateToFavorites: onStationAddedToFavorites,
      );

      // Create an overlay entry to show the panel
      _overlayEntry = OverlayEntry(builder: (context) => _currentInfoPanel!);

      // Add the entry to the overlay
      overlay.insert(_overlayEntry!);
      print("Info panel inserted into overlay");
    } catch (e) {
      print("Error showing info panel: $e");
    }
  }

  /// Helper method to handle adding to favorites
  Future<bool> _handleAddToFavorites(MapStation station) async {
    print("Handling add to favorites for station: ${station.stationId}");

    // Check if user is logged in using the stored provider reference
    final user = _authProvider.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need to be logged in to add favorites'),
          duration: Duration(seconds: 2),
        ),
      );
      return false;
    }

    try {
      // Use the helper to add to favorites
      final success = await _streamInfoHelper.addToFavorites(
        context,
        station,
        description: "Added from map view",
      );

      if (success) {
        // If there's a callback, execute it
        if (onStationAddedToFavorites != null) {
          _removeInfoPanel();
          await Future.delayed(const Duration(milliseconds: 300));
          onStationAddedToFavorites!();
        }
      }

      return success;
    } catch (e) {
      print("Error adding station to favorites: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          duration: const Duration(seconds: 3),
        ),
      );
      return false;
    }
  }

  /// Remove the current info panel if it exists
  void _removeInfoPanel() {
    if (_overlayEntry != null) {
      try {
        _overlayEntry!.remove();
        print("Info panel removed from overlay");
      } catch (e) {
        print("Error removing info panel: $e");
      } finally {
        _overlayEntry = null;
        _currentInfoPanel = null;
      }
    }
  }

  /// Clean up resources when map is disposed
  void dispose() {
    _removeInfoPanel();
  }
}
