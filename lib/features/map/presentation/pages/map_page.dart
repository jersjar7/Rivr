// lib/features/map/presentation/pages/map_page.dart

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/map_constants.dart';
import '../../../../core/network/connection_monitor.dart';
import '../../../../core/widgets/empty_state.dart';
import '../providers/map_provider.dart';
import '../providers/station_provider.dart';
import '../widgets/map_controls.dart';
import '../widgets/map_search_bar.dart';
import '../widgets/station_marker_manager.dart';
import '../widgets/station_list_drawer.dart';

class MapPage extends StatefulWidget {
  final double lat;
  final double lon;

  const MapPage({super.key, this.lat = 0.0, this.lon = 0.0});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  StationMarkerManager? _markerManager;
  Point? _initialCenter;
  bool _isMapCreated = false;
  Key _mapKey = UniqueKey(); // Add a unique key for the map widget
  bool _isResetting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Add observer for app lifecycle

    // Log token status
    MapConstants.logTokenStatus();

    // Initialize center point from given coordinates or default
    if (widget.lat != 0.0 && widget.lon != 0.0) {
      _initialCenter = Point(coordinates: Position(widget.lon, widget.lat));
    }
    print("MAP PAGE: initState completed");
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Initialize marker manager if not already created
    if (_markerManager == null) {
      final mapProvider = Provider.of<MapProvider>(context, listen: false);
      final stationProvider = Provider.of<StationProvider>(
        context,
        listen: false,
      );
      _markerManager = StationMarkerManager(mapProvider, stationProvider);
    }
  }

  @override
  void didUpdateWidget(MapPage oldWidget) {
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
    // Handle app lifecycle changes to properly clean up the map
    if (state == AppLifecycleState.detached ||
        state == AppLifecycleState.paused) {
      _cleanupMap();
    }
  }

  @override
  void dispose() {
    print("MAP PAGE: dispose called");
    WidgetsBinding.instance.removeObserver(this);
    // Clean up map resources
    _cleanupMap();
    super.dispose();
  }

  // Clean up map resources
  void _cleanupMap() {
    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    mapProvider.disposeMap();
    _markerManager = null;
    _isMapCreated = false;
  }

  // Reset the map by creating a new instance with a new key
  void _resetMap() {
    if (_isResetting) return;

    _isResetting = true;
    _cleanupMap();

    setState(() {
      _mapKey = UniqueKey(); // This will recreate the MapWidget
    });

    Future.delayed(Duration(milliseconds: 500), () {
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
            // Mapbox Map
            _buildMap(),

            // UI Elements
            SafeArea(
              child: Column(
                children: [
                  // Map Content - Takes remaining space
                  Expanded(
                    child: Stack(
                      children: [
                        // Zoom message overlay
                        _buildZoomMessage(),

                        // Loading indicator
                        _buildLoadingIndicator(),

                        // Station info panel
                        const StationInfoPanel(),

                        // Station list button (positioned at top-left)
                        Positioned(
                          top: 16,
                          left: 16,
                          child: FloatingActionButton(
                            heroTag: 'stationListBtn',
                            onPressed: () {
                              _scaffoldKey.currentState?.openDrawer();
                            },
                            backgroundColor: Colors.white,
                            foregroundColor: Theme.of(context).primaryColor,
                            tooltip: 'Show station list',
                            child: const Icon(Icons.list),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Search Bar - Now at the bottom
                  const MapSearchBar(),
                  const SizedBox(height: 30),
                ],
              ),
            ),

            // Map Controls overlay
            const MapControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    return Consumer<MapProvider>(
      builder: (context, mapProvider, child) {
        print("MAP PAGE: Building map with style: ${mapProvider.currentStyle}");
        print(
          "MAP PAGE: Using token: ${MapConstants.accessToken.substring(0, 5)}...",
        );

        try {
          // Use a unique key for the MapWidget
          return MapWidget(
            key: _mapKey,
            onMapCreated: _onMapCreated,
            cameraOptions: CameraOptions(
              center: _initialCenter ?? MapConstants.defaultCenter,
              zoom: MapConstants.defaultZoom,
              pitch: mapProvider.is3DMode ? MapConstants.defaultTilt : 0.0,
              bearing: 0,
            ),
            styleUri: mapProvider.currentStyle,
            onCameraChangeListener: _handleCameraChanged,
          );
        } catch (e) {
          print("MAP PAGE: Exception building map: $e");
          return Container(
            color: Colors.grey[300],
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.map, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading map: $e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _resetMap,
                    child: const Text('Retry Loading Map'),
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildZoomMessage() {
    return Consumer<MapProvider>(
      builder: (context, mapProvider, child) {
        if (!mapProvider.showZoomMessage) {
          return const SizedBox.shrink();
        }

        return Positioned(
          bottom: 150,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Zoom in to see stations',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingIndicator() {
    return Consumer<StationProvider>(
      builder: (context, stationProvider, child) {
        if (stationProvider.status != StationLoadingStatus.loading) {
          return const SizedBox.shrink();
        }

        return Positioned(
          bottom: 100,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Loading stations...'),
                ],
              ),
            ),
          ),
        );
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

  void _onMapCreated(MapboxMap mapboxMap) {
    print("MAP PAGE: onMapCreated called");

    // Prevent multiple initializations
    if (_isMapCreated) {
      print("MAP PAGE: Map already created, skipping initialization");
      return;
    }

    _isMapCreated = true;

    // Get providers
    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    final stationProvider = Provider.of<StationProvider>(
      context,
      listen: false,
    );

    try {
      // Initialize map in the provider once
      mapProvider.onMapCreated(mapboxMap);
      print("MAP PAGE: Map initialization completed");

      // Load initial stations only after map is fully set up
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          stationProvider.loadSampleStations();
          print("MAP PAGE: Initial stations loaded");
        }
      });
    } catch (e) {
      print("MAP PAGE: Error in onMapCreated: $e");
    }
  }

  // Implement the camera change handler
  void _handleCameraChanged(CameraChangedEventData data) {
    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    final stationProvider = Provider.of<StationProvider>(
      context,
      listen: false,
    );

    // Debounce map movements
    mapProvider.triggerDebounceTimer(() {
      _onMapMoved(mapProvider, stationProvider);
    });
  }

  void _onMapMoved(MapProvider mapProvider, StationProvider stationProvider) {
    if (!mounted) return;

    mapProvider.updateVisibleRegion().then((_) {
      if (!mounted) return;

      if (mapProvider.currentZoom >= MapConstants.minZoomForMarkers) {
        // Zoomed in enough to show detailed stations
        if (mapProvider.visibleRegion != null) {
          stationProvider.loadStationsInRegion(mapProvider.visibleRegion!);
        }
      } else if (stationProvider.stations.isNotEmpty &&
          stationProvider.stations.length > 10) {
        // Zoomed out, show only sample stations
        stationProvider.clearStations();
        stationProvider.loadSampleStations();
      }
    });
  }
}
