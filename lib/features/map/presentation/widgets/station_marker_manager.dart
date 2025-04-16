// lib/features/map/presentation/widgets/station_marker_manager.dart

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/map_constants.dart';
import '../../domain/entities/map_station.dart';
import '../providers/map_provider.dart';
import '../providers/station_provider.dart';

class StationMarkerManager {
  final MapProvider _mapProvider;
  final StationProvider _stationProvider;

  StationMarkerManager(this._mapProvider, this._stationProvider);

  Future<void> clearMarkers() async {
    final pointAnnotationManager = _mapProvider.pointAnnotationManager;
    if (pointAnnotationManager == null) return;

    try {
      await pointAnnotationManager.deleteAll();
    } catch (e) {
      print('Error clearing annotations: $e');
    }
  }

  Future<void> addStationMarkers(List<MapStation> stations) async {
    final pointAnnotationManager = _mapProvider.pointAnnotationManager;
    if (pointAnnotationManager == null) return;

    try {
      // First clear existing markers
      await clearMarkers();

      // Create marker options for each station
      final pointAnnotationOptions =
          stations.map((station) {
            final isSelected =
                _stationProvider.selectedStation?.stationId ==
                station.stationId;

            return PointAnnotationOptions(
              geometry: Point(coordinates: Position(station.lon, station.lat)),
              iconSize:
                  isSelected
                      ? MapConstants.selectedMarkerSize / 10
                      : MapConstants.defaultMarkerSize / 10,
              iconOffset: [0, 0],
              symbolSortKey: isSelected ? 2.0 : 1.0,
              textField: station.name ?? station.stationId.toString(),
              textOffset: [0, 1.5],
              textSize: isSelected ? 14.0 : 12.0,
              textColor: isSelected ? 0xFFFFFFFF : 0xFF000000,
              iconImage: isSelected ? "marker-selected" : "marker-default",
              textHaloWidth: isSelected ? 2.0 : 1.0,
              textHaloColor: isSelected ? 0xFF000000 : 0xFFFFFFFF,
            );
          }).toList();

      // Add the markers to the map
      await pointAnnotationManager.createMulti(pointAnnotationOptions);

      // Add click listener
      pointAnnotationManager.addOnPointAnnotationClickListener(
        StationClickListener(_mapProvider, _stationProvider, this),
      );
    } catch (e) {
      print('Error adding annotations: $e');
    }
  }
}

// Create a separate class for the click listener
class StationClickListener extends OnPointAnnotationClickListener {
  final MapProvider _mapProvider;
  final StationProvider _stationProvider;
  final StationMarkerManager _markerManager;

  StationClickListener(
    this._mapProvider,
    this._stationProvider,
    this._markerManager,
  );

  @override
  void onPointAnnotationClick(PointAnnotation point) {
    try {
      final tappedPosition = point.geometry.coordinates;
      final stations = _stationProvider.stations;

      // Find the station that matches the tapped marker
      final tappedStation = stations.firstWhere(
        (station) =>
            station.lon == tappedPosition.lng &&
            station.lat == tappedPosition.lat,
      );

      // Select the station in the provider
      _stationProvider.selectStation(tappedStation);

      // Center map on the selected station
      _mapProvider.goToLocation(
        Point(coordinates: Position(tappedStation.lon, tappedStation.lat)),
      );

      // Refresh markers to update the selected marker style
      _markerManager.addStationMarkers(stations);
    } catch (e) {
      print('Error handling marker tap: $e');
    }
  }
}

class StationInfoPanel extends StatelessWidget {
  const StationInfoPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final stationProvider = Provider.of<StationProvider>(context);
    final selectedStation = stationProvider.selectedStation;

    if (selectedStation == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 100,
      left: 16,
      right: 16,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      selectedStation.name ??
                          'Station ${selectedStation.stationId}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => stationProvider.deselectStation(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (selectedStation.type != null)
                Text('Type: ${selectedStation.type}'),
              const SizedBox(height: 4),
              if (selectedStation.elevation != null)
                Text(
                  'Elevation: ${selectedStation.elevation!.toStringAsFixed(2)} m',
                ),
              const SizedBox(height: 4),
              Text(
                'Coordinates: ${selectedStation.lat.toStringAsFixed(6)}, ${selectedStation.lon.toStringAsFixed(6)}',
              ),
              if (selectedStation.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  selectedStation.description!,
                  style: const TextStyle(fontSize: 14),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to forecast page
                      Navigator.pushNamed(
                        context,
                        '/forecast',
                        arguments: {
                          'reachId': selectedStation.stationId.toString(),
                          'stationName':
                              selectedStation.name ??
                              'Station ${selectedStation.stationId}',
                        },
                      );
                    },
                    icon: const Icon(Icons.analytics),
                    label: const Text('View Forecast'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      // Add to favorites
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Added to favorites'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.favorite_border),
                    label: const Text('Favorite'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
