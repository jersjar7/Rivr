// lib/features/map/domain/repositories/map_stations_repository.dart
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

abstract class MapStationsRepository {
  Future<List<Marker>> getMarkersFromVisibleBounds(
    double minLat,
    double maxLat,
    double minLon,
    double maxLon,
    LatLng? selectedMarkerPosition,
  );
}
