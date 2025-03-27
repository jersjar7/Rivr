// lib/features/map/presentation/pages/map_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:rivr/core/network/connection_monitor.dart';
import 'package:rivr/core/widgets/empty_state.dart';
import 'package:rivr/core/widgets/loading_indicator.dart';
import 'package:rivr/features/map/presentation/providers/map_provider.dart';
import 'package:rivr/features/map/presentation/widgets/enhanced_info_bubble_widget.dart';
import 'package:rivr/features/map/presentation/widgets/enhanced_map_controls.dart';

class MapPage extends StatefulWidget {
  final double lat;
  final double lon;

  const MapPage({super.key, this.lat = 0.0, this.lon = 0.0});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  LatLng? _selectedMarkerPosition;
  LatLng? _currentPosition;
  bool _isLoading = false;
  String? _errorMessage;
  String _currentBaseMap = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  bool _satelliteMode = false;
  int? _selectedStationId;
  String? _selectedStationName;

  @override
  void initState() {
    super.initState();
    // Initialize with provided coordinates or default
    _currentPosition = LatLng(
      widget.lat != 0.0 ? widget.lat : 40.7128,
      widget.lon != 0.0 ? widget.lon : -74.0060,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStations();
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadStations() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final mapProvider = Provider.of<MapProvider>(context, listen: false);

      final bounds = _mapController.camera.visibleBounds;

      await mapProvider.loadStationsInBounds(
        bounds.south,
        bounds.north,
        bounds.west,
        bounds.east,
        _selectedMarkerPosition,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load stations: ${e.toString()}';
        });
      }
    }
  }

  void _onMapEvent(MapEvent event) {
    if (event is MapEventMoveEnd) {
      // Load new stations when the map is moved
      _loadStations();
    }
  }

  void _onMarkerTapped(LatLng position, int stationId, String stationName) {
    setState(() {
      _selectedMarkerPosition = position;
      _selectedStationId = stationId;
      _selectedStationName = stationName;
    });
  }

  void _dismissInfoBubble() {
    setState(() {
      _selectedMarkerPosition = null;
      _selectedStationId = null;
      _selectedStationName = null;
    });
  }

  void _onAddToFavorites(int stationId) {
    // Implement favorite adding logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Added to favorites'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _onGetForecast(int stationId) {
    Navigator.of(context).pushNamed(
      '/forecast',
      arguments: {
        'reachId': stationId.toString(),
        'stationName': _selectedStationName ?? 'Station $stationId',
      },
    );
  }

  void _onBaseMapChanged(String urlTemplate) {
    setState(() {
      _currentBaseMap = urlTemplate;
    });
  }

  void _onLayerToggle(bool value) {
    setState(() {
      _satelliteMode = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ConnectionAwareWidget(
      offlineBuilder:
          (context, status) => Scaffold(
            appBar: AppBar(title: const Text('Map')),
            body: Column(
              children: [
                const ConnectionStatusBanner(),
                Expanded(
                  child: NetworkErrorView(
                    onRetry: _loadStations,
                    isPermanentlyOffline: status.isConnected == false,
                  ),
                ),
              ],
            ),
          ),
      child: Scaffold(
        appBar: AppBar(title: const Text('Map')),
        body: _buildMapContent(),
      ),
    );
  }

  Widget _buildMapContent() {
    return Consumer<MapProvider>(
      builder: (context, mapProvider, child) {
        final markers = mapProvider.markers;

        if (_errorMessage != null) {
          return ErrorStateView(
            message: _errorMessage!,
            onRetry: _loadStations,
          );
        }

        // If no markers found after loading, show empty state
        if (!_isLoading && markers.isEmpty) {
          return _buildEmptyStationsView();
        }

        return Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentPosition!,
                initialZoom: 10.0,
                onMapEvent: _onMapEvent,
              ),
              children: [
                TileLayer(
                  urlTemplate: _currentBaseMap,
                  subdomains: const ['a', 'b', 'c'],
                ),
                if (_satelliteMode)
                  TileLayer(
                    urlTemplate:
                        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                    // opacity: 0.7,
                  ),
                MarkerLayer(
                  markers:
                      markers.map((marker) {
                        // Extract station info from marker data
                        // This would be properly implemented based on your marker data structure
                        final stationId =
                            12345; // Replace with actual station ID extraction
                        final stationName =
                            'Example Station'; // Replace with actual station name extraction

                        return Marker(
                          width: 40.0,
                          height: 40.0,
                          point: marker.point,
                          child: GestureDetector(
                            onTap:
                                () => _onMarkerTapped(
                                  marker.point,
                                  stationId,
                                  stationName,
                                ),
                            child: const Icon(
                              Icons.water_drop,
                              color: Colors.blue,
                              size: 30,
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ],
            ),

            // Map controls
            EnhancedMapControls(
              mapController: _mapController,
              currentLocation: _currentPosition,
              onLayerToggle: _onLayerToggle,
              onBaseMapChanged: _onBaseMapChanged,
              currentBaseMap: _currentBaseMap,
              satelliteMode: _satelliteMode,
            ),

            // Loading indicator
            if (_isLoading)
              const Positioned(
                top: 70,
                left: 0,
                right: 0,
                child: Center(
                  child: LoadingIndicator(
                    message: 'Loading stations...',
                    withBackground: true,
                    size: 30,
                  ),
                ),
              ),

            // Info bubble for selected station
            if (_selectedMarkerPosition != null && _selectedStationId != null)
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: EnhancedInfoBubble(
                  stationId: _selectedStationId!,
                  stationName: _selectedStationName ?? 'River Station',
                  latitude: _selectedMarkerPosition!.latitude,
                  longitude: _selectedMarkerPosition!.longitude,
                  onAddToFavorites: _onAddToFavorites,
                  onGetForecast: _onGetForecast,
                  onDismiss: _dismissInfoBubble,
                ),
              ),
          ],
        );
      },
    );
  }

  // Add an empty state widget for when no stations are found
  Widget _buildEmptyStationsView() {
    return NoStationsFoundView(
      onChangeLocation: () {
        // Reset to a default location
        _mapController.move(
          LatLng(40.7128, -74.0060), // New York City
          8.0,
        );
        _loadStations();
      },
    );
  }
}
