import 'dart:math' as Math;
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:rivr/core/services/offline_manager_service.dart'; // Updated import
import 'package:rivr/core/network/connection_monitor.dart'; // Added import
import 'package:rivr/features/map/domain/entities/map_station.dart';
import 'package:rivr/features/auth/presentation/providers/auth_provider.dart';
import 'package:rivr/features/favorites/presentation/providers/favorites_provider.dart';

import '../providers/enhanced_clustered_map_provider.dart';
import '../providers/station_provider.dart';
import '../providers/map_provider.dart';
import '../widgets/stream_info_panel.dart';
import '../../../../core/widgets/offline_aware_station_info_panel.dart'; // Added import for offline-aware panel
import '../../../../core/constants/map_constants.dart';
import '../../../../core/di/service_locator.dart'; // For service locator

class MapTapHandler {
  final MapboxMap mapboxMap;
  final BuildContext context;
  final Function? onStationAddedToFavorites;

  // Replace with OfflineManagerService
  final OfflineManagerService _offlineManager;
  final ConnectionMonitor _connectionMonitor;

  // Track the currently displayed info panel
  StreamInfoPanel? _currentInfoPanel;
  OverlayEntry? _overlayEntry;

  // Store provider references to avoid context issues
  late final AuthProvider _authProvider;
  late final FavoritesProvider _favoritesProvider;

  MapTapHandler({
    required this.mapboxMap,
    required this.context,
    this.onStationAddedToFavorites,
    OfflineManagerService? offlineManager,
    ConnectionMonitor? connectionMonitor,
  }) : _offlineManager = offlineManager ?? sl<OfflineManagerService>(),
       _connectionMonitor = connectionMonitor ?? sl<ConnectionMonitor>() {
    // Initialize provider references immediately
    _authProvider = Provider.of<AuthProvider>(context, listen: false);
    _favoritesProvider = Provider.of<FavoritesProvider>(context, listen: false);
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

      // Query for features at the tap location
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

  /// Query for features at the given screen coordinate
  Future<List<QueriedRenderedFeature?>> queryFeaturesAtPoint(
    ScreenCoordinate point,
  ) async {
    try {
      // Create a rendered query geometry for the point
      final geometry = RenderedQueryGeometry.fromScreenCoordinate(point);

      // Query for rendered features at this point
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

      // Handle cluster tap
      if (properties.containsKey('cluster') && properties['cluster'] == true) {
        await handleClusterTap(properties, mapCoord, mapProvider);
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
      final int stationIdInt = int.parse(stationId);

      // Initialize as empty - we'll only use "Untitled Stream" if we can't find a name
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
      } else {
        // Check if we have a cached name using the new OfflineManagerService
        try {
          final cachedStation = await _offlineManager.getCachedStation(
            stationIdInt,
          );
          if (cachedStation != null &&
              cachedStation['station'] != null &&
              cachedStation['station']['name'] != null) {
            stationName = cachedStation['station']['name'] as String;
            print("Retrieved cached name for station $stationId: $stationName");
          }
        } catch (e) {
          print("Error retrieving cached name: $e");
          // Keep the name empty for now
        }
      }

      // If no name found or empty, ONLY THEN use "Untitled Stream"
      if (stationName.isEmpty) {
        stationName = "Untitled Stream";
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

      // Save station info in offline cache using the new OfflineManagerService
      await _offlineManager.cacheStation(tappedStation, {'name': stationName});

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

      // Now use the offline-aware station info panel instead
      final isConnected = await _connectionMonitor.testConnection();
      final isOfflineMode = _offlineManager.offlineModeEnabled;

      if (!isConnected || isOfflineMode) {
        // Show offline-aware panel in offline mode
        _showOfflineAwareInfoPanel(
          tappedStation,
          clusteredMapProvider,
          stationProvider,
          mapProvider,
        );
      } else {
        // Show regular panel in online mode
        _showInfoPanel(
          tappedStation,
          clusteredMapProvider,
          stationProvider,
          mapProvider,
        );
      }
    } catch (e) {
      print("Error handling station tap: $e");
    }
  }

  /// Show the offline-aware stream info panel
  Future<void> _showOfflineAwareInfoPanel(
    MapStation station,
    EnhancedClusteredMapProvider clusteredMapProvider,
    StationProvider stationProvider,
    MapProvider mapProvider,
  ) async {
    // Make method async
    try {
      // Remove existing panel first
      _removeInfoPanel();

      print(
        "Creating offline-aware info panel for station: ${station.stationId}",
      );

      // Find the overlay to add our widget to
      final overlay = Overlay.of(context);

      // Create the offline-aware panel
      final offlineAwarePanel = OfflineAwareStationInfoPanel(
        station: station,
        onClose: () {
          // When closed, deselect the station and remove the panel
          print("Closing info panel");
          clusteredMapProvider.deselectStation();
          _removeInfoPanel();
        },
        onAddToFavorites:
            onStationAddedToFavorites != null
                ? (station) async {
                  // Handle adding to favorites with offline awareness
                  final success = await _handleAddToFavorites(station);
                  if (success) {
                    _removeInfoPanel();
                    await Future.delayed(const Duration(milliseconds: 300));
                    onStationAddedToFavorites!();
                    Navigator.of(context).pop();
                  }
                }
                : null,
        onViewForecast: (reachId, stationName) {
          // Navigate to the forecast page
          Navigator.pushNamed(
            context,
            '/forecast',
            arguments: {'reachId': reachId, 'stationName': stationName},
          );
        },
      );

      // Create an overlay entry to show the panel
      _overlayEntry = OverlayEntry(builder: (context) => offlineAwarePanel);

      // Add the entry to the overlay
      overlay.insert(_overlayEntry!);
      print("Offline-aware info panel inserted into overlay");
    } catch (e) {
      print("Error showing offline-aware info panel: $e");
    }
  }

  /// Show the regular stream info panel for the selected station (online mode)
  Future<void> _showInfoPanel(
    MapStation station,
    EnhancedClusteredMapProvider clusteredMapProvider,
    StationProvider stationProvider,
    MapProvider mapProvider,
  ) async {
    // Make method async
    try {
      // Remove existing panel first
      _removeInfoPanel();

      print("Creating info panel for station: ${station.stationId}");

      // Find the overlay to add our widget to
      final overlay = Overlay.of(context);

      // Determine the display name before creating the panel
      String displayName = station.name ?? "";

      // If station name is empty, try to get a name from cache
      if (displayName.isEmpty) {
        try {
          // Try to get cached station data - needs to be awaited
          final cachedStation = await _offlineManager.getCachedStation(
            station.stationId,
            // Remove the ignoreExpiry parameter since it doesn't exist
          );

          if (cachedStation != null &&
              cachedStation['station'] != null &&
              cachedStation['station']['name'] != null) {
            displayName = cachedStation['station']['name'] as String;
          } else {
            displayName = "Untitled Stream";
          }
        } catch (e) {
          print("Error getting station name: $e");
          displayName = "Untitled Stream";
        }
      }

      // Create a new info panel with the determined display name
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
            arguments: {'reachId': reachId, 'stationName': displayName},
          );
        },
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
      // Add station to favorites using the stored provider reference
      print("Adding station ${station.stationId} to favorites");

      // Use the station name
      final displayName = station.name ?? "Untitled Stream";

      final success = await _favoritesProvider.addFavoriteFromStation(
        user.uid,
        station,
        displayName: displayName,
        description: "Added from map view",
      );

      if (success) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added $displayName to favorites'),
            duration: const Duration(seconds: 2),
          ),
        );

        return true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to add to favorites. Please try again.'),
            duration: Duration(seconds: 2),
          ),
        );
        return false;
      }
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
