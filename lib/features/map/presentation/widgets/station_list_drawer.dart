// lib/features/map/presentation/widgets/station_list_drawer.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../domain/entities/map_station.dart';
import '../providers/map_provider.dart';
import '../providers/station_provider.dart';
import '../../../../core/utils/location_utils.dart';
import '../../../../core/widgets/loading_indicator.dart';

class StationListDrawer extends StatefulWidget {
  const StationListDrawer({super.key});

  @override
  State<StationListDrawer> createState() => _StationListDrawerState();
}

class _StationListDrawerState extends State<StationListDrawer> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _sortByDistance = true;
  double? _userLat;
  double? _userLon;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);

    // Get current map center for distance calculations
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mapProvider = Provider.of<MapProvider>(context, listen: false);
      _updateMapCenter(mapProvider);
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  void _updateMapCenter(MapProvider mapProvider) async {
    if (mapProvider.mapboxMap != null) {
      try {
        final cameraState = await mapProvider.mapboxMap!.getCameraState();
        setState(() {
          _userLat = cameraState.center.coordinates.lat.toDouble();
          _userLon = cameraState.center.coordinates.lng.toDouble();
        });
      } catch (e) {
        print('Error getting camera state: $e');
      }
    }
  }

  void _toggleSortOrder() {
    setState(() {
      _sortByDistance = !_sortByDistance;
    });
  }

  void _selectStation(BuildContext context, MapStation station) {
    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    final stationProvider = Provider.of<StationProvider>(
      context,
      listen: false,
    );

    // Select the station
    stationProvider.selectStation(station);

    // Navigate to the station on map
    mapProvider.goToLocation(
      Point(coordinates: Position(station.lon, station.lat)),
    );

    // Close the drawer
    Navigator.of(context).pop();
  }

  List<MapStation> _getFilteredAndSortedStations(List<MapStation> stations) {
    // First apply search filter
    List<MapStation> filteredStations =
        _searchQuery.isEmpty
            ? stations
            : stations.where((station) {
              final name = station.name?.toLowerCase() ?? '';
              final id = station.stationId.toString();
              return name.contains(_searchQuery) || id.contains(_searchQuery);
            }).toList();

    // Then sort them
    if (_sortByDistance && _userLat != null && _userLon != null) {
      filteredStations.sort((a, b) {
        final distA = LocationUtils.calculateDistance(
          a.lat,
          a.lon,
          _userLat!,
          _userLon!,
        );
        final distB = LocationUtils.calculateDistance(
          b.lat,
          b.lon,
          _userLat!,
          _userLon!,
        );
        return distA.compareTo(distB);
      });
    } else {
      // Sort by name or ID if no name
      filteredStations.sort((a, b) {
        final nameA = a.name?.toLowerCase() ?? a.stationId.toString();
        final nameB = b.name?.toLowerCase() ?? b.stationId.toString();
        return nameA.compareTo(nameB);
      });
    }

    return filteredStations;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      child: Column(
        children: [
          // Drawer header with search
          Container(
            padding: const EdgeInsets.only(
              top: 16,
              left: 16,
              right: 16,
              bottom: 8,
            ),
            color: theme.primaryColor,
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Stations',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search stations',
                      hintStyle: TextStyle(color: Colors.white70),
                      prefixIcon: Icon(Icons.search, color: Colors.white70),
                      suffixIcon:
                          _searchQuery.isNotEmpty
                              ? IconButton(
                                icon: Icon(Icons.clear, color: Colors.white70),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              )
                              : null,
                      filled: true,
                      fillColor: theme.primaryColor.withOpacity(0.8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text('Sort by:', style: TextStyle(color: Colors.white70)),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text('Distance'),
                        selected: _sortByDistance,
                        onSelected: (_) => _toggleSortOrder(),
                        selectedColor: Colors.white,
                        backgroundColor: theme.primaryColor.withOpacity(0.7),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text('Name'),
                        selected: !_sortByDistance,
                        onSelected: (_) => _toggleSortOrder(),
                        selectedColor: Colors.white,
                        backgroundColor: theme.primaryColor.withOpacity(0.7),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Station list
          Expanded(
            child: Consumer<StationProvider>(
              builder: (context, stationProvider, child) {
                if (stationProvider.status == StationLoadingStatus.loading) {
                  return Center(
                    child: LoadingIndicator(
                      message: 'Loading stations...',
                      size: 30,
                    ),
                  );
                }

                if (stationProvider.status == StationLoadingStatus.error) {
                  return Center(
                    child: Text(
                      stationProvider.errorMessage ?? 'An error occurred',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red),
                    ),
                  );
                }

                final stations = stationProvider.stations;

                if (stations.isEmpty) {
                  return Center(
                    child: Text(
                      'No stations available.\nTry zooming in on the map.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                  );
                }

                final filteredStations = _getFilteredAndSortedStations(
                  stations,
                );

                if (filteredStations.isEmpty) {
                  return Center(
                    child: Text(
                      'No stations match your search.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredStations.length,
                  itemBuilder: (context, index) {
                    final station = filteredStations[index];
                    final isSelected =
                        stationProvider.selectedStation?.stationId ==
                        station.stationId;

                    // Calculate distance if we have user location
                    String? distanceText;
                    if (_userLat != null && _userLon != null) {
                      final distance = LocationUtils.calculateDistance(
                        station.lat,
                        station.lon,
                        _userLat!,
                        _userLon!,
                      );
                      // Format distance
                      distanceText =
                          distance < 1
                              ? '${(distance * 1000).toStringAsFixed(0)} m'
                              : '${distance.toStringAsFixed(1)} km';
                    }

                    return ListTile(
                      title: Text(
                        station.name ?? 'Station ${station.stationId}',
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (station.type != null)
                            Text('Type: ${station.type}'),
                          Text(
                            LocationUtils.formatCoordinates(
                              station.lat,
                              station.lon,
                              precision: 4,
                            ),
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      trailing:
                          distanceText != null
                              ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    distanceText,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: theme.primaryColor,
                                    ),
                                  ),
                                  Icon(
                                    Icons.place,
                                    color:
                                        isSelected
                                            ? theme.primaryColor
                                            : Colors.grey,
                                    size: 16,
                                  ),
                                ],
                              )
                              : null,
                      selected: isSelected,
                      selectedTileColor: theme.primaryColor.withOpacity(0.1),
                      onTap: () => _selectStation(context, station),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
