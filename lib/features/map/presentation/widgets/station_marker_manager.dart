// lib/features/map/presentation/widgets/station_marker_manager.dart

import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
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
    if (pointAnnotationManager == null) {
      print("DEBUG: pointAnnotationManager is null, can't clear markers");
      return;
    }

    try {
      print("DEBUG: Clearing all markers");
      await pointAnnotationManager.deleteAll();
      print("DEBUG: All markers cleared");
    } catch (e) {
      print("ERROR: Error clearing annotations: $e");
    }
  }

  Future<void> addStationMarkers(List<MapStation> stations) async {
    final pointAnnotationManager = _mapProvider.pointAnnotationManager;
    if (pointAnnotationManager == null) {
      print("ERROR: pointAnnotationManager is null, can't add markers");
      return;
    }

    try {
      // First clear existing markers
      print("DEBUG: Adding ${stations.length} station markers");
      await clearMarkers();

      if (stations.isEmpty) {
        print("WARNING: No stations to add as markers");
        return;
      }

      // Create marker options for each station
      final pointAnnotationOptions =
          stations.map((station) {
            final isSelected =
                _stationProvider.selectedStation?.stationId ==
                station.stationId;

            print(
              "DEBUG: Creating marker for station ${station.stationId}, position=(${station.lat}, ${station.lon})",
            );

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
      print("DEBUG: Added ${stations.length} markers to the map");

      // Add click listener
      pointAnnotationManager.addOnPointAnnotationClickListener(
        StationClickListener(_mapProvider, _stationProvider, this),
      );
      print("DEBUG: Added click listener to markers");
    } catch (e) {
      print("ERROR: Error adding annotations: $e");
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
      print("DEBUG: Marker clicked: ${point.id}");
      final tappedPosition = point.geometry.coordinates;
      final stations = _stationProvider.stations;

      // Find the station that matches the tapped marker
      try {
        final tappedStation = stations.firstWhere(
          (station) =>
              station.lon == tappedPosition.lng &&
              station.lat == tappedPosition.lat,
        );

        print("DEBUG: Found matching station: ${tappedStation.stationId}");

        // Select the station in the provider
        _stationProvider.selectStation(tappedStation);

        // Center map on the selected station
        _mapProvider.goToLocation(
          Point(coordinates: Position(tappedStation.lon, tappedStation.lat)),
        );

        // Refresh markers to update the selected marker style
        _markerManager.addStationMarkers(stations);
      } catch (e) {
        print(
          "ERROR: No matching station found for position: (${tappedPosition.lng}, ${tappedPosition.lat})",
        );
        print("ERROR: Available stations:");
        for (var station in stations) {
          print(
            "Station ${station.stationId}: (${station.lon}, ${station.lat})",
          );
        }
      }
    } catch (e) {
      print("ERROR: Error handling marker tap: $e");
    }
  }
}
