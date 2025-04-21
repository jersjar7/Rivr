// lib/features/map/data/models/map_station_model.dart

import '../../domain/entities/map_station.dart';

class MapStationModel extends MapStation {
  const MapStationModel({
    required super.stationId,
    required super.lat,
    required super.lon,
    super.elevation,
    super.name,
    super.type,
    super.description,
    super.color,
  });

  factory MapStationModel.fromMap(Map<String, dynamic> map) {
    // Ensure we have the required fields and parse them correctly
    int stationId;
    double lat;
    double lon;

    try {
      // Handle stationId - must be integer
      if (map['stationId'] is int) {
        stationId = map['stationId'];
      } else if (map['stationId'] is String) {
        stationId = int.parse(map['stationId']);
      } else {
        throw FormatException('Invalid stationId format: ${map['stationId']}');
      }

      // Handle lat - must be double
      if (map['lat'] is double) {
        lat = map['lat'];
      } else if (map['lat'] is num) {
        lat = (map['lat'] as num).toDouble();
      } else if (map['lat'] is String) {
        lat = double.parse(map['lat']);
      } else {
        throw FormatException('Invalid lat format: ${map['lat']}');
      }

      // Handle lon - must be double
      if (map['lon'] is double) {
        lon = map['lon'];
      } else if (map['lon'] is num) {
        lon = (map['lon'] as num).toDouble();
      } else if (map['lon'] is String) {
        lon = double.parse(map['lon']);
      } else {
        throw FormatException('Invalid lon format: ${map['lon']}');
      }

      // Handle optional elevation field
      double? elevation;
      if (map['elevation'] != null) {
        if (map['elevation'] is double) {
          elevation = map['elevation'];
        } else if (map['elevation'] is num) {
          elevation = (map['elevation'] as num).toDouble();
        } else if (map['elevation'] is String) {
          elevation = double.parse(map['elevation']);
        }
      }

      return MapStationModel(
        stationId: stationId,
        lat: lat,
        lon: lon,
        elevation: elevation,
        name: map['name'] as String?,
        type: map['type'] as String?,
        description: map['description'] as String?,
        color: map['color'] as String? ?? '#2389DA',
      );
    } catch (e) {
      print("ERROR: Failed to parse MapStationModel from map: $e");
      print("ERROR: Problematic map: $map");
      rethrow;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'stationId': stationId,
      'lat': lat,
      'lon': lon,
      'elevation': elevation,
      'name': name,
      'type': type,
      'description': description,
      'color': color,
    };
  }

  @override
  String toString() {
    return 'MapStationModel(stationId: $stationId, lat: $lat, lon: $lon, name: $name)';
  }
}
