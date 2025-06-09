// lib/features/map/presentation/pages/map_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:rivr/features/map/presentation/utils/map_tap_handler.dart';

import '../../../../core/constants/map_constants.dart';
import '../providers/map_provider.dart';
import '../providers/station_provider.dart';
import '../providers/enhanced_clustered_map_provider.dart';
import '../utils/map_initialization_helper.dart';
import '../utils/user_location_marker_manager.dart';
import '../widgets/map_search_bar.dart';
import '../widgets/station_list_drawer.dart';
import '../widgets/drawer_pull_tag.dart';
import '../widgets/zoom_hint.dart';
import '../widgets/map_components/map_controls.dart';
import '../widgets/map_components/map_error_view.dart';
import '../widgets/map_components/map_loading_indicator.dart';

class OptimizedMapPage extends StatefulWidget {
  final double lat;
  final double lon;
  final Function? onStationAddedToFavorites;

  const OptimizedMapPage({
    super.key,
    this.lat = 0.0,
    this.lon = 0.0,
    this.onStationAddedToFavorites,
  });

  @override
  State<OptimizedMapPage> createState() => _OptimizedMapPageState();
}

class _OptimizedMapPageState extends State<OptimizedMapPage>
    with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Map components
  Point? _initialCenter;
  MapboxMap? _mapboxMap;
  Key _mapKey = UniqueKey();

  // Store provider references to avoid accessing context during dispose
  MapProvider? _mapProvider;
  StationProvider? _stationProvider;
  EnhancedClusteredMapProvider? _clusteredMapProvider;

  // State management
  bool _isMapCreated = false;
  bool _isResetting = false;
  bool _is3DMode = true;
  bool _showZoomHint = true;
  bool _hasUserInteracted = false;

  // Location-related state
  bool _isLoadingInitialLocation = true;
  bool _useCurrentLocation = true;
  bool _hasUserManuallyMoved = false;

  // Helper instances
  late MapInitializationHelper _initHelper;
  late UserLocationMarkerManager _locationMarkerManager;

  // Map tap handler
  MapTapHandler? _mapTapHandler;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Log token status on init
    MapConstants.logTokenStatus();

    // Create helper instances
    _initHelper = MapInitializationHelper();
    _locationMarkerManager = UserLocationMarkerManager();

    // Initialize map center based on provided coordinates or current location
    _initializeMapCenter();

    print("OPTIMIZED MAP PAGE: initState completed");
  }

  /// Initialize the map center based on provided coordinates or current location
  Future<void> _initializeMapCenter() async {
    try {
      // If lat/lon are provided and not zero, use them (disable auto-location)
      if (widget.lat != 0.0 && widget.lon != 0.0) {
        _initialCenter = Point(coordinates: Position(widget.lon, widget.lat));
        _useCurrentLocation =
            false; // Don't try current location if coordinates provided
        setState(() {
          _isLoadingInitialLocation = false;
        });
        print(
          "OPTIMIZED MAP PAGE: Using provided coordinates: ${widget.lat}, ${widget.lon}",
        );
        return;
      }

      // Otherwise, try to get current location if user hasn't disabled it
      final center = await MapConstants.getInitialCenter(
        useCurrentLocation: _useCurrentLocation,
      );

      setState(() {
        _initialCenter = center;
        _isLoadingInitialLocation = false;
      });

      // Log whether we got actual location or fallback
      if (MapConstants.isDefaultLocation(center)) {
        print("OPTIMIZED MAP PAGE: Using default Utah location");
      } else {
        print("OPTIMIZED MAP PAGE: Using current device location");
      }
    } catch (e) {
      print("OPTIMIZED MAP PAGE: Error initializing map center: $e");
      // Fallback to default center
      setState(() {
        _initialCenter = MapConstants.defaultCenter;
        _isLoadingInitialLocation = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Cache provider references when the widget is active
    _mapProvider = Provider.of<MapProvider>(context, listen: false);
    _stationProvider = Provider.of<StationProvider>(context, listen: false);
    _clusteredMapProvider = Provider.of<EnhancedClusteredMapProvider>(
      context,
      listen: false,
    );
  }

  @override
  void didUpdateWidget(OptimizedMapPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If lat/lon changes significantly, recreate the map
    if ((oldWidget.lat != widget.lat || oldWidget.lon != widget.lon) &&
        (widget.lat != 0.0 || widget.lon != 0.0)) {
      _initialCenter = Point(coordinates: Position(widget.lon, widget.lat));
      _useCurrentLocation =
          false; // Disable auto-location when coordinates are provided
      Future.microtask(() => _resetMap());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle changes to properly clean up resources
    if (state == AppLifecycleState.detached ||
        state == AppLifecycleState.paused) {
      _cleanupMapResources();
    }
  }

  @override
  void dispose() {
    print("OPTIMIZED MAP PAGE: dispose called");
    WidgetsBinding.instance.removeObserver(this);
    // Schedule cleanup for next frame instead of doing it immediately
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _cleanupMapResources();
    });
    super.dispose();
  }

  // Clean up map resources properly
  void _cleanupMapResources() {
    if (_mapboxMap != null) {
      // Clean up the map tap handler
      if (_mapTapHandler != null) {
        _mapTapHandler!.dispose();
        _mapTapHandler = null;
      }

      // Clean up location marker manager
      _locationMarkerManager.dispose();

      // Clean up clustering resources first using the cached provider reference
      if (_clusteredMapProvider != null) {
        try {
          _clusteredMapProvider!.cleanupClustering(_mapboxMap!);
        } catch (e) {
          print("Error cleaning up clustering resources: $e");
        }
      }

      // Then dispose the map using the cached provider reference
      if (_mapProvider != null) {
        try {
          _mapProvider!.disposeMap();
        } catch (e) {
          print("Error disposing map provider: $e");
        }
      }

      _mapboxMap = null;
      _isMapCreated = false;
    }
  }

  // Reset the map by creating a new instance
  void _resetMap() {
    if (_isResetting) return;

    _isResetting = true;
    _cleanupMapResources();

    setState(() {
      _mapKey = UniqueKey(); // This will recreate the MapWidget
      _hasUserManuallyMoved = false; // Reset user interaction flag
    });

    // Re-initialize map center
    _isLoadingInitialLocation = true;
    _initializeMapCenter();

    Future.delayed(const Duration(milliseconds: 500), () {
      _isResetting = false;
    });
  }

  // Handle the back button press
  Future<bool> _onWillPop() async {
    // If a station was added to favorites, execute the callback before popping
    if (widget.onStationAddedToFavorites != null) {
      widget.onStationAddedToFavorites!();
    }
    return true; // Allow the page to be popped
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    // Show loading indicator while determining initial location
    if (_isLoadingInitialLocation) {
      return Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(
          title: Text(
            'Add River',
            style: textTheme.titleMedium?.copyWith(
              color: colors.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                _useCurrentLocation
                    ? 'Getting your location...'
                    : 'Loading map...',
                style: textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: colors.surface,
        drawer: const StationListDrawer(),
        appBar: AppBar(
          title: Text(
            'Add River',
            style: textTheme.titleMedium?.copyWith(
              color: colors.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          elevation: 2,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: colors.onPrimary),
            onPressed: () {
              if (widget.onStationAddedToFavorites != null) {
                widget.onStationAddedToFavorites!();
              }
              Navigator.of(context).pop();
            },
          ),
        ),
        body: Stack(
          children: [
            // Mapbox Map (bottommost layer)
            _buildMap(),

            // Add the hint widget
            ZoomHintWidget(
              show: _showZoomHint,
              onClose: () => setState(() => _showZoomHint = false),
            ),

            // Drawer pull tag - Move to main Stack to always be visible
            Positioned(
              left: 0,
              top: MediaQuery.of(context).padding.top + 100,
              child: DrawerPullTag(
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
                backgroundColor:
                    colors.brightness == Brightness.dark
                        ? colors.secondary
                        : colors.primary,
              ),
            ),

            // UI Elements
            SafeArea(
              child: Column(
                children: [
                  // Map Content - Takes remaining space
                  Expanded(
                    child: Stack(
                      children: [
                        // Loading indicator
                        const MapLoadingIndicator(),
                      ],
                    ),
                  ),

                  // Search Bar - at the bottom
                  const MapSearchBar(),
                  const SizedBox(height: 30),
                ],
              ),
            ),

            // Map Controls overlay
            Consumer<MapProvider>(
              builder: (context, mapProvider, _) {
                return MapControls(
                  is3DMode: _is3DMode,
                  currentStyle: mapProvider.currentStyle,
                  onStyleChanged: _changeMapStyle,
                  onToggle3D: _toggle3DTerrain,
                  onRefresh: _refreshStations,
                  onZoomIn: _zoomIn,
                  onZoomOut: _zoomOut,
                  // Location control properties
                  userLocationEnabled: mapProvider.userLocationEnabled,
                  isGettingLocation: mapProvider.isGettingLocation,
                  onToggleUserLocation: () => _toggleUserLocation(mapProvider),
                  onGoToCurrentLocation:
                      () => _goToCurrentLocationFromControls(mapProvider),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Toggle user location marker from controls
  Future<void> _toggleUserLocation(MapProvider mapProvider) async {
    mapProvider.toggleUserLocationEnabled();

    // Update location marker manager
    if (mapProvider.userLocationEnabled) {
      await _locationMarkerManager.updateLocationMarker();
      await _locationMarkerManager.showLocationMarker();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location marker enabled'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      await _locationMarkerManager.hideLocationMarker();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location marker disabled'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Go to current location from map controls
  Future<void> _goToCurrentLocationFromControls(MapProvider mapProvider) async {
    final success = await mapProvider.goToCurrentLocation();

    if (!mounted) return;

    // Update location marker if enabled and location was successful
    if (success && mapProvider.userLocationEnabled) {
      await _locationMarkerManager.updateLocationMarker();
      await _locationMarkerManager.showLocationMarker();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Centered on your current location'),
          duration: Duration(seconds: 2),
        ),
      );
    } else if (!success) {
      // Error message will be shown by MapProvider, but we can add additional feedback
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not get current location'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildMap() {
    return Consumer<MapProvider>(
      builder: (context, mapProvider, child) {
        print(
          "OPTIMIZED MAP: Building map with style: ${mapProvider.currentStyle}",
        );

        try {
          // Get the current brightness from the theme
          final brightness = Theme.of(context).brightness;
          String styleUri = mapProvider.currentStyle;

          // Automatically switch to a dark map style when in dark mode
          // and to a light style when in light mode
          if (brightness == Brightness.dark) {
            // Only switch if not already using a dark style
            if (!styleUri.contains('dark') && !styleUri.contains('satellite')) {
              styleUri = MapConstants.mapboxDark;

              // Update the provider's style (without rebuilding)
              // This ensures the stored style stays in sync
              Future.microtask(() {
                mapProvider.setCurrentStyleWithoutRebuild(styleUri);
              });
            }
          } else {
            // For light mode, switch back to a light style if using dark
            if (styleUri.contains('dark')) {
              styleUri =
                  MapConstants.mapboxStandard; // Or any other light style

              // Update the provider's style (without rebuilding)
              Future.microtask(() {
                mapProvider.setCurrentStyleWithoutRebuild(styleUri);
              });
            }
          }

          // Use a unique key for the MapWidget to force recreation when needed
          return MapWidget(
            key: _mapKey,
            onMapCreated: (mapboxMap) => _onMapCreated(mapboxMap, mapProvider),
            cameraOptions: CameraOptions(
              center: _initialCenter ?? MapConstants.defaultCenter,
              zoom: MapConstants.defaultZoom,
              pitch: _is3DMode ? MapConstants.defaultTilt : 0.0,
              bearing: 0,
            ),
            styleUri: styleUri,
            onCameraChangeListener: _handleCameraChanged,
            // Add the onTapListener here
            onTapListener: (tapData) {
              if (_mapTapHandler != null) {
                _mapTapHandler!.handleMapTap(tapData);
              } else {
                print("Warning: MapTapHandler is null, can't process tap");
              }
            },
          );
        } catch (e) {
          print("OPTIMIZED MAP: Exception building map: $e");
          // Pass theme context to the error view
          return MapErrorView(error: e.toString(), onRetry: _resetMap);
        }
      },
    );
  }

  // Handle map creation with proper initialization
  void _onMapCreated(MapboxMap mapboxMap, MapProvider mapProvider) async {
    print("OPTIMIZED MAP: onMapCreated called");

    // Prevent multiple initializations
    if (_isMapCreated) {
      print("OPTIMIZED MAP: Map already created, skipping initialization");
      return;
    }

    _isMapCreated = true;
    _mapboxMap = mapboxMap;

    // Get providers (update our cached references)
    _mapProvider = mapProvider;
    _stationProvider = Provider.of<StationProvider>(context, listen: false);
    _clusteredMapProvider = Provider.of<EnhancedClusteredMapProvider>(
      context,
      listen: false,
    );

    // Initialize the location marker manager
    await _locationMarkerManager.initialize(mapboxMap, context);

    // Initialize the map tap handler, passing the callback and location marker manager
    _mapTapHandler = MapTapHandler(
      mapboxMap: mapboxMap,
      context: context,
      onStationAddedToFavorites: widget.onStationAddedToFavorites,
      locationMarkerManager:
          _locationMarkerManager, // Pass reference for tap handling
    );
    _mapTapHandler!.setupTapHandlers();

    // Initialize the map
    _initHelper.initializeMap(
      context: context,
      mapboxMap: mapboxMap,
      mapProvider: mapProvider,
      stationProvider: _stationProvider!,
      clusteredMapProvider: _clusteredMapProvider!,
      is3DMode: _is3DMode,
    );

    // Show location marker if auto-location is enabled and we have a location
    if (_useCurrentLocation &&
        !MapConstants.isDefaultLocation(
          _initialCenter ?? MapConstants.defaultCenter,
        )) {
      await _locationMarkerManager.updateLocationMarker();
      await _locationMarkerManager.showLocationMarker();
    }
  }

  // Handle camera change events with debouncing
  void _handleCameraChanged(CameraChangedEventData data) {
    if (!_hasUserInteracted) {
      _hasUserInteracted = true;
      return; // skip the first, system-driven change
    }

    // Mark that user has manually moved the map (prevents auto-return to location)
    if (!_hasUserManuallyMoved) {
      setState(() {
        _hasUserManuallyMoved = true;
      });
      print("OPTIMIZED MAP: User has manually moved the map");
    }

    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    mapProvider.triggerDebounceTimer(_onMapMoved);
  }

  // Handle map movement with dynamic clustering
  Future<void> _onMapMoved() async {
    if (!mounted || _mapboxMap == null) return;

    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    final stationProvider = Provider.of<StationProvider>(
      context,
      listen: false,
    );
    final clusteredMapProvider = Provider.of<EnhancedClusteredMapProvider>(
      context,
      listen: false,
    );

    // Update visible region & zoom
    await mapProvider.updateVisibleRegion();
    final bounds = mapProvider.visibleRegion;
    if (bounds == null) return;
    final zoom = mapProvider.currentZoom;

    // Update zoom hint visibility
    if (zoom < MapConstants.minZoomForMarkers && !_showZoomHint) {
      setState(() => _showZoomHint = true);
    } else if (zoom >= MapConstants.minZoomForMarkers && _showZoomHint) {
      setState(() => _showZoomHint = false);
    }

    // Skip loading if zoom too low
    if (zoom < MapConstants.minZoomForMarkers) {
      clusteredMapProvider.cleanupClustering(_mapboxMap!);
      return;
    }

    // Load & cluster stations
    stationProvider
        .loadStationsInRegion(
          bounds,
          limit: MapConstants.maxMarkersForPerformance,
        )
        .then(
          (_) {
            clusteredMapProvider.updateStations(
              _mapboxMap!,
              stationProvider.stations,
            );
          },
          onError: (e) {
            debugPrint("ERROR updating stations: $e");
          },
        );
  }

  // Change map style
  void _changeMapStyle(String newStyle) {
    if (_mapboxMap == null) return;

    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    final stationProvider = Provider.of<StationProvider>(
      context,
      listen: false,
    );
    final clusteredMapProvider = Provider.of<EnhancedClusteredMapProvider>(
      context,
      listen: false,
    );

    _initHelper.changeMapStyle(
      mapboxMap: _mapboxMap!,
      newStyle: newStyle,
      is3DMode: _is3DMode,
      mapProvider: mapProvider,
      stationProvider: stationProvider,
      clusteredMapProvider: clusteredMapProvider,
    );
  }

  // Toggle 3D terrain
  void _toggle3DTerrain(bool enable) {
    if (_mapboxMap == null) return;

    // 1. Get providers
    final mapProvider = Provider.of<MapProvider>(context, listen: false);

    // 2. Update local state
    setState(() {
      _is3DMode = enable;
    });

    // 3. Call MapProvider's toggle method to ensure proper state sync
    if (mapProvider.is3DMode != enable) {
      mapProvider.toggle3DTerrain();
    }

    // 4. Also call helper to ensure map styling updates correctly
    _initHelper.toggle3DTerrain(mapboxMap: _mapboxMap!, enable: enable).then((
      _,
    ) {
      // 5. Set camera pitch to reinforce the change
      if (enable) {
        mapProvider.setCameraPitch(MapConstants.defaultTilt);
      } else {
        mapProvider.setCameraPitch(0);
      }
    });
  }

  // Refresh stations
  void _refreshStations() {
    if (_mapboxMap == null) return;

    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    final stationProvider = Provider.of<StationProvider>(
      context,
      listen: false,
    );
    final clusteredMapProvider = Provider.of<EnhancedClusteredMapProvider>(
      context,
      listen: false,
    );

    _initHelper.refreshStations(
      mapboxMap: _mapboxMap!,
      mapProvider: mapProvider,
      stationProvider: stationProvider,
      clusteredMapProvider: clusteredMapProvider,
    );
  }

  // Zoom in
  void _zoomIn() {
    if (_mapboxMap == null) return;

    final mapProvider = Provider.of<MapProvider>(context, listen: false);

    mapProvider.zoomIn().then((_) {
      mapProvider.triggerDebounceTimer(() {
        _onMapMoved();
      });
    });
  }

  // Zoom out
  void _zoomOut() {
    if (_mapboxMap == null) return;

    final mapProvider = Provider.of<MapProvider>(context, listen: false);

    mapProvider.zoomOut().then((_) {
      mapProvider.triggerDebounceTimer(() {
        _onMapMoved();
      });
    });
  }
}
