// lib/features/map/presentation/widgets/station_list_drawer.dart
// Enhanced with StreamNameService integration

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../domain/entities/map_station.dart';
import '../providers/map_provider.dart';
import '../providers/station_provider.dart';
import '../../../../core/utils/location_utils.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/services/stream_name_service.dart'; // Add StreamNameService import
import '../../../../core/di/service_locator.dart'; // For accessing service locator

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

  // Add StreamNameService reference
  late StreamNameService _streamNameService;

  // Cache for station names to avoid excessive database queries
  final Map<String, StationNameInfo> _nameCache = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);

    // Initialize StreamNameService
    _streamNameService = sl<StreamNameService>();

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

    // Select the station in the provider
    stationProvider.selectStation(station);

    // Navigate to the station with a close-up zoom level
    mapProvider.goToLocation(
      Point(coordinates: Position(station.lon, station.lat)),
      zoom: 14.0, // Specify desired zoom level here
    );

    // Close the drawer
    Navigator.of(context).pop();
  }

  // Get station name information async
  Future<StationNameInfo> _getStationNameInfo(String stationId) async {
    // Check cache first
    if (_nameCache.containsKey(stationId)) {
      return _nameCache[stationId]!;
    }

    try {
      // Get name from StreamNameService
      final nameInfo = await _streamNameService.getNameInfo(stationId);

      // Cache it for future use
      _nameCache[stationId] = StationNameInfo(
        displayName: nameInfo.displayName,
        isCustomName:
            nameInfo.originalApiName != null &&
            nameInfo.originalApiName!.isNotEmpty &&
            nameInfo.displayName != nameInfo.originalApiName,
      );

      return _nameCache[stationId]!;
    } catch (e) {
      print("Error getting station name: $e");
      // Return default info on error
      return StationNameInfo(
        displayName: 'Station $stationId',
        isCustomName: false,
      );
    }
  }

  List<MapStation> _getFilteredAndSortedStations(List<MapStation> stations) {
    // First apply search filter - but using our internal name cache when possible
    List<MapStation> filteredStations = stations;

    if (_searchQuery.isNotEmpty) {
      filteredStations =
          stations.where((station) {
            final id = station.stationId.toString();
            // Check if ID matches search directly
            if (id.contains(_searchQuery)) {
              return true;
            }

            // For names, check our cache if possible
            final stationId = station.stationId.toString();
            if (_nameCache.containsKey(stationId)) {
              final name = _nameCache[stationId]!.displayName.toLowerCase();
              return name.contains(_searchQuery);
            }

            // Fall back to station.name if not in cache
            final name = station.name?.toLowerCase() ?? '';
            return name.contains(_searchQuery);
          }).toList();
    }

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
      // Sort by name - but using our name cache when possible
      filteredStations.sort((a, b) {
        final stationIdA = a.stationId.toString();
        final stationIdB = b.stationId.toString();

        String nameA;
        String nameB;

        // Use cached names if available
        if (_nameCache.containsKey(stationIdA)) {
          nameA = _nameCache[stationIdA]!.displayName.toLowerCase();
        } else {
          nameA = a.name?.toLowerCase() ?? a.stationId.toString();
        }

        if (_nameCache.containsKey(stationIdB)) {
          nameB = _nameCache[stationIdB]!.displayName.toLowerCase();
        } else {
          nameB = b.name?.toLowerCase() ?? b.stationId.toString();
        }

        return nameA.compareTo(nameB);
      });
    }

    return filteredStations;
  }

  // New widget to build a station list item with StreamNameService
  Widget _buildStationListItem(
    BuildContext context,
    MapStation station,
    bool isSelected,
    ThemeData theme,
    String? distanceText,
  ) {
    final stationId = station.stationId.toString();

    // Use FutureBuilder to display name asynchronously
    return FutureBuilder<StationNameInfo>(
      future: _getStationNameInfo(stationId),
      initialData: _nameCache[stationId],
      builder: (context, snapshot) {
        String displayName;
        bool isCustomName = false;

        if (snapshot.hasData) {
          displayName = snapshot.data!.displayName;
          isCustomName = snapshot.data!.isCustomName;
        } else if (snapshot.hasError) {
          displayName = station.name ?? 'Station $stationId';
        } else {
          // Loading state, use station name or ID as fallback
          displayName = station.name ?? 'Station $stationId';
        }

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 8.0,
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  displayName,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 16,
                  ),
                ),
              ),
              // Show custom name indicator if applicable
              if (isCustomName)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Custom',
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.tag, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'ID: ${station.stationId}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              if (station.type != null) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.category, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Type: ${station.type}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.location_on, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    LocationUtils.formatCoordinates(
                      station.lat,
                      station.lon,
                      precision: 4,
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          trailing:
              distanceText != null
                  ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? theme.primaryColor.withOpacity(0.2)
                              : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          distanceText,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                isSelected
                                    ? theme.primaryColor
                                    : Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Icon(
                          Icons.place,
                          color: isSelected ? theme.primaryColor : Colors.grey,
                          size: 14,
                        ),
                      ],
                    ),
                  )
                  : null,
          selected: isSelected,
          selectedTileColor: theme.primaryColor.withOpacity(0.1),
          onTap: () => _selectStation(context, station),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85, // Make drawer wider
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
                      const Text(
                        'River Streams',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Find and select water monitoring stations',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search stations by name or ID',
                      hintStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.white70,
                      ),
                      suffixIcon:
                          _searchQuery.isNotEmpty
                              ? IconButton(
                                icon: const Icon(
                                  Icons.clear,
                                  color: Colors.white70,
                                ),
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
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text(
                        'Sort by:',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Distance'),
                        selected: _sortByDistance,
                        onSelected: (_) => _toggleSortOrder(),
                        selectedColor: Colors.white,
                        backgroundColor: theme.primaryColor.withOpacity(0.7),
                        labelStyle: TextStyle(
                          color:
                              _sortByDistance
                                  ? theme.primaryColor
                                  : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Name'),
                        selected: !_sortByDistance,
                        onSelected: (_) => _toggleSortOrder(),
                        selectedColor: Colors.white,
                        backgroundColor: theme.primaryColor.withOpacity(0.7),
                        labelStyle: TextStyle(
                          color:
                              !_sortByDistance
                                  ? theme.primaryColor
                                  : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
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
                  return const Center(
                    child: LoadingIndicator(
                      message: 'Loading stations...',
                      size: 30,
                    ),
                  );
                }

                if (stationProvider.status == StationLoadingStatus.error) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          stationProvider.errorMessage ?? 'An error occurred',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                        ),
                      ],
                    ),
                  );
                }

                final stations = stationProvider.stations;

                if (stations.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_off,
                          color: Colors.grey[400],
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32.0),
                          child: Text(
                            'No stations available in this area',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try zooming out on the map or moving to a different location',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.map),
                          label: const Text('Back to Map'),
                        ),
                      ],
                    ),
                  );
                }

                final filteredStations = _getFilteredAndSortedStations(
                  stations,
                );

                if (filteredStations.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off,
                          color: Colors.grey[400],
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No stations match your search',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '"${_searchController.text}"',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => _searchController.clear(),
                          child: const Text('Clear Search'),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    // Station count information
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      color: Colors.grey[100],
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Showing ${filteredStations.length} of ${stations.length} stations',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            Text(
                              'Filtered by: $_searchQuery',
                              style: TextStyle(
                                color: theme.primaryColor,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Station list
                    Expanded(
                      child: ListView.separated(
                        itemCount: filteredStations.length,
                        separatorBuilder:
                            (context, index) => const Divider(height: 1),
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

                          // Use our new station list item builder that supports StreamNameService
                          return _buildStationListItem(
                            context,
                            station,
                            isSelected,
                            theme,
                            distanceText,
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Helper class to store station name information
class StationNameInfo {
  final String displayName;
  final bool isCustomName;

  StationNameInfo({required this.displayName, required this.isCustomName});
}
