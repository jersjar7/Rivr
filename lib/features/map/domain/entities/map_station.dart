// lib/features/map/domain/entities/map_station.dart

class MapStation {
  final int stationId;
  final double lat;
  final double lon;
  final double? elevation;
  final String? name;
  final String? type;
  final String? description;
  final String? color;

  const MapStation({
    required this.stationId,
    required this.lat,
    required this.lon,
    this.elevation,
    this.name,
    this.type,
    this.description,
    this.color,
  });
}
