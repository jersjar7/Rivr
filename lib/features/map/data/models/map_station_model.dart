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
    return MapStationModel(
      stationId:
          map['stationId'] is int
              ? map['stationId']
              : int.parse(map['stationId'].toString()),
      lat:
          map['lat'] is double
              ? map['lat']
              : double.parse(map['lat'].toString()),
      lon:
          map['lon'] is double
              ? map['lon']
              : double.parse(map['lon'].toString()),
      elevation:
          map['elevation'] != null
              ? (map['elevation'] is double
                  ? map['elevation']
                  : double.parse(map['elevation'].toString()))
              : null,
      name: map['name'] as String?,
      type: map['type'] as String?,
      description: map['description'] as String?,
      color: map['color'] as String? ?? '#2389DA',
    );
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
}
