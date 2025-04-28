// lib/features/map/presentation/pages/map_page.dart

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:rivr/features/map/presentation/utils/map_tap_handler.dart';

import '../../../../core/constants/map_constants.dart';
import '../../../../core/network/connection_monitor.dart';
import '../../../../core/widgets/empty_state.dart';
import '../providers/map_provider.dart';
import '../providers/station_provider.dart';
import '../providers/enhanced_clustered_map_provider.dart';
import '../utils/map_initialization_helper.dart';
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

  const OptimizedMapPage({super.key, this.lat = 0.0, this.lon = 0.0});

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

  // State management
  bool _isMapCreated = false;
  bool _isResetting = false;
  bool _is3DMode = true;
  bool _showZoomHint = true;
  bool _hasUserInteracted = false;

  // Helper instance
  late MapInitializationHelper _initHelper;

  MapTapHandler? _mapTapHandler;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Log token status on init
    MapConstants.logTokenStatus();

    // Initialize center point from given coordinates or default
    if (widget.lat != 0.0 && widget.lon != 0.0) {
      _initialCenter = Point(coordinates: Position(widget.lon, widget.lat));
    }

    // Create initialization helper
    _initHelper = MapInitializationHelper();

    print("OPTIMIZED MAP PAGE: initState completed");
  }

  @override
  void didUpdateWidget(OptimizedMapPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If lat/lon changes significantly, recreate the map
    if ((oldWidget.lat != widget.lat || oldWidget.lon != widget.lon) &&
        (widget.lat != 0.0 || widget.lon != 0.0)) {
      _initialCenter = Point(coordinates: Position(widget.lon, widget.lat));
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
    _cleanupMapResources();
    super.dispose();
  }

  // Clean up map resources properly
  void _cleanupMapResources() {
    if (_mapboxMap != null) {
      final mapProvider = Provider.of<MapProvider>(context, listen: false);
      final clusteredMapProvider = Provider.of<EnhancedClusteredMapProvider>(
        context,
        listen: false,
      );

      // Clean up clustering resources first
      clusteredMapProvider.cleanupClustering(_mapboxMap!);

      // Then dispose the map
      mapProvider.disposeMap();

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
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      _isResetting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const StationListDrawer(),
      body: ConnectionAwareWidget(
        offlineBuilder: (context, status) => _buildOfflineView(),
        child: Stack(
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
                backgroundColor: Theme.of(context).primaryColor,
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
                        MapLoadingIndicator(),
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
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    return Consumer<MapProvider>(
      builder: (context, mapProvider, child) {
        print(
          "OPTIMIZED MAP: Building map with style: ${mapProvider.currentStyle}",
        );

        try {
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
            styleUri: mapProvider.currentStyle,
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
          return MapErrorView(error: e.toString(), onRetry: _resetMap);
        }
      },
    );
  }

  Widget _buildOfflineView() {
    return Scaffold(
      body: Center(
        child: NetworkErrorView(
          onRetry: () {
            final connectionMonitor = Provider.of<ConnectionMonitor>(
              context,
              listen: false,
            );
            connectionMonitor.resetOfflineStatus();
          },
        ),
      ),
    );
  }

  // Handle map creation with proper initialization
  void _onMapCreated(MapboxMap mapboxMap, MapProvider mapProvider) {
    print("OPTIMIZED MAP: onMapCreated called");

    // Prevent multiple initializations
    if (_isMapCreated) {
      print("OPTIMIZED MAP: Map already created, skipping initialization");
      return;
    }

    _isMapCreated = true;
    _mapboxMap = mapboxMap;

    // Initialize map tap handler
    _mapTapHandler = MapTapHandler(mapboxMap: mapboxMap, context: context);
    _mapTapHandler!.setupTapHandlers();

    // Get providers
    final stationProvider = Provider.of<StationProvider>(
      context,
      listen: false,
    );
    final clusteredMapProvider = Provider.of<EnhancedClusteredMapProvider>(
      context,
      listen: false,
    );

    // Initialize the map
    _initHelper.initializeMap(
      context: context,
      mapboxMap: mapboxMap,
      mapProvider: mapProvider,
      stationProvider: stationProvider,
      clusteredMapProvider: clusteredMapProvider,
      is3DMode: _is3DMode,
    );
  }

  // Handle camera change events with debouncing
  void _handleCameraChanged(CameraChangedEventData data) {
    if (!_hasUserInteracted) {
      _hasUserInteracted = true;
      return; // skip the first, system-driven change
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

    setState(() {
      _is3DMode = enable;
    });

    _initHelper.toggle3DTerrain(mapboxMap: _mapboxMap!, enable: enable);
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
