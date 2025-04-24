// lib/features/map/presentation/pages/map_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:rivr/common/data/local/database_helper.dart';
import 'package:rivr/features/map/presentation/providers/enhanced_clustered_map_provider.dart';

import '../../../../core/constants/map_constants.dart';
import '../../../../core/network/connection_monitor.dart';
import '../../../../core/widgets/empty_state.dart';
import '../providers/map_provider.dart';
import '../providers/station_provider.dart';
import '../utils/map_style_manager.dart';
import '../widgets/map_search_bar.dart';
import '../widgets/station_info_panel.dart';
import '../widgets/station_list_drawer.dart';

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
  MapStyleManager? _styleManager;
  Key _mapKey = UniqueKey();

  // State management
  bool _isMapCreated = false;
  bool _isResetting = false;
  bool _is3DMode = true;

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
      _styleManager = null;
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
                        Consumer<EnhancedClusteredMapProvider>(
                          builder: (context, provider, child) {
                            if (provider.selectedStation == null) {
                              return const SizedBox.shrink();
                            }

                            return StationInfoPanel(
                              station: provider.selectedStation!,
                              onClose: () => provider.deselectStation(),
                            );
                          },
                        ),

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

                  // Search Bar - at the bottom
                  const MapSearchBar(),
                  const SizedBox(height: 30),
                ],
              ),
            ),

            // Map Controls overlay
            _buildMapControls(),
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
          );
        } catch (e) {
          print("OPTIMIZED MAP: Exception building map: $e");
          return _buildMapErrorView(e);
        }
      },
    );
  }

  // Create a styled map controls widget with proper integration
  Widget _buildMapControls() {
    return Consumer<MapProvider>(
      builder: (context, mapProvider, _) {
        // Return custom controls that work with the style manager
        return MapControlsWithStyleManager(
          is3DMode: _is3DMode,
          currentStyle: mapProvider.currentStyle,
          onStyleChanged: _changeMapStyle,
          onToggle3D: _toggle3DTerrain,
          onRefresh: _refreshStations,
          onZoomIn: _zoomIn,
          onZoomOut: _zoomOut,
        );
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
    return Consumer2<StationProvider, EnhancedClusteredMapProvider>(
      builder: (context, stationProvider, clusteredMapProvider, child) {
        final bool isLoading =
            stationProvider.status == StationLoadingStatus.loading ||
            clusteredMapProvider.status == ClusteringStatus.initializing ||
            clusteredMapProvider.status == ClusteringStatus.updating;

        if (!isLoading) {
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
                    color: Colors.black.withValues(alpha: 0.1),
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

  Widget _buildMapErrorView(dynamic error) {
    return Container(
      color: Colors.grey[300],
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error loading map: $error',
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

    // Get providers
    final stationProvider = Provider.of<StationProvider>(
      context,
      listen: false,
    );
    final clusteredMapProvider = Provider.of<EnhancedClusteredMapProvider>(
      context,
      listen: false,
    );

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
      final databaseHelper = DatabaseHelper();
      databaseHelper.database.then((db) {
        db
            .rawQuery("SELECT COUNT(*) as count FROM Geolocations")
            .then((result) {
              final count = result.first['count'] as int;
              print("OPTIMIZED MAP: Geolocations table has $count stations");

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
              print("OPTIMIZED MAP: Error checking Geolocations table: $e");
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error accessing station data: $e'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 5),
                ),
              );
            });
      });

      // Load map resources first
      _loadMapResources().then((_) {
        // Initialize 3D terrain if needed
        if (_is3DMode) {
          _styleManager!.enable3DTerrain(
            exaggeration: MapConstants.terrainExaggeration,
          );
        }

        print("OPTIMIZED MAP: Map initialization completed");

        // Wait for a moment to ensure style is fully loaded
        Future.delayed(const Duration(milliseconds: 500), () {
          // Initialize clustering with better error handling
          clusteredMapProvider.initialize(mapboxMap).then((success) {
            if (success) {
              print("OPTIMIZED MAP: Clustering initialized successfully");

              // Load initial stations right away
              _loadInitialStations(stationProvider, clusteredMapProvider);
            } else {
              print("OPTIMIZED MAP: Clustering initialization failed");
              // Retry once after a delay
              Future.delayed(const Duration(seconds: 1), () {
                print("OPTIMIZED MAP: Retrying clustering initialization");
                clusteredMapProvider.initialize(mapboxMap).then((retrySuccess) {
                  if (retrySuccess) {
                    print("OPTIMIZED MAP: Retry successful, loading stations");
                    _loadInitialStations(stationProvider, clusteredMapProvider);
                  } else {
                    print(
                      "OPTIMIZED MAP: Retry failed, falling back to regular markers",
                    );
                    // Could implement a fallback here
                  }
                });
              });
            }
          });
        });
      });
    } catch (e) {
      print("OPTIMIZED MAP: Error in onMapCreated: $e");
    }
  }

  // Add this new method to load map resources
  Future<void> _loadMapResources() async {
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
      await _mapboxMap!.style.addStyleImage(
        "marker-default",
        1.0, // scale
        defaultMbxImage,
        false, // sdf
        [], // stretchX
        [], // stretchY
        null, // content
      );

      await _mapboxMap!.style.addStyleImage(
        "marker-selected",
        1.0, // scale
        selectedMbxImage,
        false, // sdf
        [], // stretchX
        [], // stretchY
        null, // content
      );

      print("OPTIMIZED MAP: Marker resources loaded successfully");
      return;
    } catch (e) {
      print("OPTIMIZED MAP: Error loading marker resources: $e");
      // Don't rethrow - we can continue without custom markers
      return;
    }
  }

  // Load initial set of stations (always full region, no samples)
  void _loadInitialStations(
    StationProvider stationProvider,
    EnhancedClusteredMapProvider clusteredMapProvider,
  ) {
    print("DEBUG: Map page loading initial stations");

    // Grab the current visible region from your MapProvider
    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    final region = mapProvider.visibleRegion;
    if (region == null) {
      print("WARN: No visible region yet, skipping station load");
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
          print("DEBUG: Loaded ${stations.length} stations in region");

          if (stations.isEmpty) {
            print("ERROR: No stations in database for this region!");
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No stations found in this area!'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 5),
              ),
            );
            return;
          }

          // Push them into your clustering provider
          if (_mapboxMap != null) {
            clusteredMapProvider
                .updateStations(_mapboxMap!, stations)
                .then((_) => print("DEBUG: Initial clusters updated"))
                .catchError((e) => print("ERROR: Clustering failed: $e"));
          }
        })
        .catchError((e) {
          print("ERROR: Failed to load stations in region: $e");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading stations: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        });
  }

  // Handle camera change events with debouncing
  void _handleCameraChanged(CameraChangedEventData data) {
    if (_mapboxMap == null) return;

    final mapProvider = Provider.of<MapProvider>(context, listen: false);

    // Debounce map movements
    mapProvider.triggerDebounceTimer(() {
      _onMapMoved();
    });
  }

  // Handle map movement with proper station loading
  // Handle map movement with dynamic clustering radius
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

    // 1) Update the visible region & get the current zoom
    await mapProvider.updateVisibleRegion();
    final bounds = mapProvider.visibleRegion;
    if (bounds == null) return;
    final zoom = mapProvider.currentZoom;

    // 2) Pick a clusterRadius based on zoom
    final dynamicRadius =
        zoom < 5
            ? 500 // very zoomed out → huge clusters
            : zoom < 8
            ? 300 // mid zoom → medium clusters
            : MapConstants.clusterRadius; // default (e.g. 50)

    // 3) Apply it to your source before clustering
    try {
      await _mapboxMap!.style.setStyleSourceProperty(
        "stations-source", // your source ID
        "clusterRadius",
        dynamicRadius,
      );
    } catch (e) {
      print("WARN: could not update clusterRadius: $e");
    }

    // 4) Load and cluster stations normally
    stationProvider
        .loadStationsInRegion(
          bounds,
          limit: MapConstants.maxMarkersForPerformance,
        )
        .then((_) {
          clusteredMapProvider.updateStations(
            _mapboxMap!,
            stationProvider.stations,
          );
        })
        .catchError((e) => print("ERROR updating stations: $e"));
  }

  // Change map style using the style manager
  void _changeMapStyle(String newStyle) {
    if (_styleManager == null || _mapboxMap == null) return;

    final stationProvider = Provider.of<StationProvider>(
      context,
      listen: false,
    );
    final clusteredMapProvider = Provider.of<EnhancedClusteredMapProvider>(
      context,
      listen: false,
    );

    _styleManager!.changeMapStyle(
      newStyle,
      onStyleChanged: () {
        // Restore 3D terrain if needed
        if (_is3DMode) {
          _styleManager!.enable3DTerrain();
        }

        // Refresh stations after style change is complete
        final stations = stationProvider.stations;
        if (stations.isNotEmpty) {
          clusteredMapProvider
              .updateStations(_mapboxMap!, stations)
              .catchError(
                (e) => print(
                  "OPTIMIZED MAP: Error updating stations after style change: $e",
                ),
              );
        }
      },
    );
  }

  // Toggle 3D terrain
  void _toggle3DTerrain(bool enable) {
    if (_styleManager == null) return;

    setState(() {
      _is3DMode = enable;
    });

    _styleManager!.toggle3DTerrain(enable);
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

    mapProvider.updateVisibleRegion().then((_) {
      final bounds = mapProvider.visibleRegion;
      if (bounds == null) return;

      stationProvider
          .loadStationsInRegion(bounds)
          .then(
            (_) => clusteredMapProvider.updateStations(
              _mapboxMap!,
              stationProvider.stations,
            ),
          )
          .catchError((e) => print("Error refreshing stations: $e"));
    });
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

// A simplified version of MapControls that works with the style manager
class MapControlsWithStyleManager extends StatelessWidget {
  final bool is3DMode;
  final String currentStyle;
  final Function(String) onStyleChanged;
  final Function(bool) onToggle3D;
  final VoidCallback onRefresh;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const MapControlsWithStyleManager({
    super.key,
    required this.is3DMode,
    required this.currentStyle,
    required this.onStyleChanged,
    required this.onToggle3D,
    required this.onRefresh,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Control buttons at top-right
        Positioned(
          top: 26,
          right: 16,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Refresh button
                _buildControlButton(
                  context: context,
                  icon: Icons.refresh,
                  tooltip: 'Refresh stations',
                  onPressed: onRefresh,
                ),

                const SizedBox(height: 12),

                // Map style button
                _buildControlButton(
                  context: context,
                  icon: Icons.layers,
                  tooltip: 'Map style: ${_getStyleName(currentStyle)}',
                  onPressed: () => _showStyleSelector(context),
                  badge: _getStyleName(currentStyle).characters.first,
                ),

                const SizedBox(height: 12),

                // 3D/2D toggle button
                _build3DToggleButton(context),
              ],
            ),
          ),
        ),

        // Zoom controls at bottom-right
        Positioned(right: 16, bottom: 150, child: _buildZoomControls(context)),
      ],
    );
  }

  String _getStyleName(String styleUri) {
    switch (styleUri) {
      case MapboxStyles.MAPBOX_STREETS:
        return 'Streets';
      case MapboxStyles.OUTDOORS:
        return 'Outdoors';
      case MapboxStyles.LIGHT:
        return 'Light';
      case MapboxStyles.DARK:
        return 'Dark';
      case MapboxStyles.SATELLITE_STREETS:
        return 'Satellite';
      case MapboxStyles.STANDARD:
        return 'Standard';
      default:
        return 'Custom';
    }
  }

  Widget _buildControlButton({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    String? badge,
  }) {
    final Color activeColor = Theme.of(context).primaryColor;

    return Tooltip(
      message: tooltip,
      child: Container(
        height: 48,
        width: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Center(child: Icon(icon, color: Colors.black87, size: 24)),
                if (badge != null)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: activeColor,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          badge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _build3DToggleButton(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onToggle3D(!is3DMode),
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: Icon(
              is3DMode ? Icons.view_in_ar : Icons.map,
              color: is3DMode ? theme.primaryColor : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildZoomControls(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Zoom in button
          SizedBox(
            height: 48,
            width: 48,
            child: _buildZoomButton(
              icon: Icons.add,
              tooltip: 'Zoom in',
              onPressed: onZoomIn,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
          ),

          // Divider
          Container(
            height: 1,
            width: 36,
            color: Colors.grey.withValues(alpha: 0.3),
          ),

          // Zoom out button
          SizedBox(
            height: 48,
            width: 48,
            child: _buildZoomButton(
              icon: Icons.remove,
              tooltip: 'Zoom out',
              onPressed: onZoomOut,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoomButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required BorderRadius borderRadius,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: borderRadius,
          child: Center(child: Icon(icon)),
        ),
      ),
    );
  }

  void _showStyleSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => StyleSelectorSheet(
            currentStyle: currentStyle,
            onStyleSelected: (style) {
              onStyleChanged(style);
              Navigator.pop(context);
            },
          ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    );
  }
}

// A simplified style selector sheet
class StyleSelectorSheet extends StatelessWidget {
  final String currentStyle;
  final Function(String) onStyleSelected;

  const StyleSelectorSheet({
    super.key,
    required this.currentStyle,
    required this.onStyleSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 24, 8),
            child: Row(
              children: [
                const Text(
                  'Choose Map Style',
                  style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),

          // Style options grid
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStyleCard(
                  context,
                  'Standard',
                  MapboxStyles.STANDARD,
                  Icons.public,
                ),
                _buildStyleCard(
                  context,
                  'Streets',
                  MapboxStyles.MAPBOX_STREETS,
                  Icons.map,
                ),
                _buildStyleCard(
                  context,
                  'Outdoors',
                  MapboxStyles.OUTDOORS,
                  Icons.terrain,
                ),
                _buildStyleCard(
                  context,
                  'Satellite',
                  MapboxStyles.SATELLITE_STREETS,
                  Icons.satellite_alt,
                ),
                _buildStyleCard(
                  context,
                  'Light',
                  MapboxStyles.LIGHT,
                  Icons.light_mode,
                ),
                _buildStyleCard(
                  context,
                  'Dark',
                  MapboxStyles.DARK,
                  Icons.dark_mode,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyleCard(
    BuildContext context,
    String title,
    String styleUri,
    IconData iconData,
  ) {
    final bool isSelected = currentStyle == styleUri;
    final Color primaryColor = Theme.of(context).primaryColor;

    return GestureDetector(
      onTap: () => onStyleSelected(styleUri),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              iconData,
              size: 48,
              color: isSelected ? primaryColor : Colors.grey[700],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? primaryColor : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
