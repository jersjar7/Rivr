// lib/features/map/presentation/providers/map_provider.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:rivr/features/map/domain/repositories/map_stations_repository.dart';

class MapProvider with ChangeNotifier {
  final MapStationsRepository _repository;

  // State variables
  List<Marker> _markers = [];
  bool _isLoading = false;
  String? _errorMessage;
  LatLng? _selectedMarkerPosition;

  // Constructor
  MapProvider({required MapStationsRepository repository})
    : _repository = repository;

  // Getters
  List<Marker> get markers => _markers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  LatLng? get selectedMarkerPosition => _selectedMarkerPosition;

  // Load stations within visible map bounds
  Future<void> loadStationsInBounds(
    double minLat,
    double maxLat,
    double minLon,
    double maxLon,
    LatLng? selectedPosition,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    _selectedMarkerPosition = selectedPosition;
    notifyListeners();

    try {
      final loadedMarkers = await _repository.getMarkersFromVisibleBounds(
        minLat,
        maxLat,
        minLon,
        maxLon,
        selectedPosition,
      );

      _markers = loadedMarkers;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to load stations: ${e.toString()}';
      notifyListeners();
    }
  }

  // Select a marker
  void selectMarker(LatLng position) {
    _selectedMarkerPosition = position;
    notifyListeners();
  }

  // Clear selection
  void clearSelection() {
    _selectedMarkerPosition = null;
    notifyListeners();
  }

  // Update markers with new selection state
  Future<void> updateMarkers() async {
    if (_markers.isEmpty) return;

    // Get current bounds from existing markers
    double minLat = 90.0;
    double maxLat = -90.0;
    double minLon = 180.0;
    double maxLon = -180.0;

    for (final marker in _markers) {
      final lat = marker.point.latitude;
      final lon = marker.point.longitude;

      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lon < minLon) minLon = lon;
      if (lon > maxLon) maxLon = lon;
    }

    // Add some padding to the bounds
    const padding = 0.1; // degrees
    minLat -= padding;
    maxLat += padding;
    minLon -= padding;
    maxLon += padding;

    // Reload markers with updated selection
    await loadStationsInBounds(
      minLat,
      maxLat,
      minLon,
      maxLon,
      _selectedMarkerPosition,
    );
  }

  // Filter markers by search term
  Future<void> filterMarkers(String searchTerm) async {
    // This would be implemented to filter markers based on station names or other criteria
    // For now, this is a placeholder
    if (searchTerm.isEmpty) {
      await updateMarkers();
      return;
    }

    // In a real implementation, this would filter the markers based on the search term
    // This is a simplified example
    _isLoading = true;
    notifyListeners();

    // Simulate filtering
    await Future.delayed(const Duration(milliseconds: 300));

    _isLoading = false;
    notifyListeners();
  }

  // Add station to favorites
  Future<void> addStationToFavorites(int stationId) async {
    // This would call a favorites repository method
    // For now, just show success in console
    print('Added station $stationId to favorites');
  }

  // Check if a station is in favorites
  Future<bool> isStationInFavorites(int stationId) async {
    // This would call a favorites repository method
    // For now, just return false
    return false;
  }
}
