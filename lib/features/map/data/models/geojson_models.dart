// lib/features/map/data/models/geojson_models.dart

import 'dart:convert';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../domain/entities/map_station.dart';

/// A Dart representation of a GeoJSON Feature
class GeoJsonFeature {
  final String type;
  final Map<String, dynamic> geometry;
  final Map<String, dynamic> properties;

  GeoJsonFeature({
    this.type = 'Feature',
    required this.geometry,
    required this.properties,
  });

  Map<String, dynamic> toJson() {
    return {'type': type, 'geometry': geometry, 'properties': properties};
  }
}

/// A Dart representation of a GeoJSON FeatureCollection
class GeoJsonFeatureCollection {
  final String type;
  final List<GeoJsonFeature> features;

  GeoJsonFeatureCollection({
    this.type = 'FeatureCollection',
    required this.features,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'features': features.map((feature) => feature.toJson()).toList(),
    };
  }

  /// Converts the collection to a JSON string
  String toJsonString() {
    return jsonEncode(toJson());
  }
}

/// Extension to convert from domain entities to GeoJSON format
extension MapStationToGeoJson on MapStation {
  GeoJsonFeature toGeoJsonFeature() {
    return GeoJsonFeature(
      geometry: {
        'type': 'Point',
        'coordinates': [lon, lat], // GeoJSON uses [longitude, latitude] order
      },
      properties: {
        'id': stationId.toString(),
        'name': name ?? 'Station $stationId',
        'type': type ?? 'unknown',
        'elevation': elevation,
        'description': description,
        'color': color ?? '#2389DA',
      },
    );
  }
}

/// Extension to convert a list of MapStations to a GeoJSON FeatureCollection
extension MapStationListToGeoJson on List<MapStation> {
  GeoJsonFeatureCollection toGeoJsonFeatureCollection() {
    return GeoJsonFeatureCollection(
      features: map((station) => station.toGeoJsonFeature()).toList(),
    );
  }
}
