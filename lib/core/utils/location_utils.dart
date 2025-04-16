// lib/core/utils/location_utils.dart

import 'dart:math';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class LocationUtils {
  /// Calculates the distance between two points using the Haversine formula
  /// Returns the distance in kilometers
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const int earthRadius = 6371; // km

    final double latDiff = _degreesToRadians(lat2 - lat1);
    final double lonDiff = _degreesToRadians(lon2 - lon1);

    final double a =
        (sin(latDiff / 2) * sin(latDiff / 2)) +
        (cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(lonDiff / 2) *
            sin(lonDiff / 2));

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  /// Converts degrees to radians
  static double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  /// Calculates a bounding box around a center point with a given radius in km
  static CoordinateBounds calculateBoundingBox(
    double centerLat,
    double centerLon,
    double radiusKm,
  ) {
    // Approximate degrees for the given distance
    // 1 degree of latitude = ~111 km
    final double latChange = radiusKm / 111.0;

    // 1 degree of longitude = ~111 km * cos(latitude)
    final double lonChange =
        radiusKm / (111.0 * cos(_degreesToRadians(centerLat)));

    return CoordinateBounds(
      southwest: Point(
        coordinates: Position(centerLon - lonChange, centerLat - latChange),
      ),
      northeast: Point(
        coordinates: Position(centerLon + lonChange, centerLat + latChange),
      ),
      infiniteBounds: false,
    );
  }

  /// Formats coordinates to a human-readable string
  static String formatCoordinates(double lat, double lon, {int precision = 6}) {
    final latDirection = lat >= 0 ? 'N' : 'S';
    final lonDirection = lon >= 0 ? 'E' : 'W';

    return '${lat.abs().toStringAsFixed(precision)}° $latDirection, ${lon.abs().toStringAsFixed(precision)}° $lonDirection';
  }

  /// Get cardinal direction from bearing
  static String getCardinalDirection(double bearing) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW', 'N'];
    return directions[(((bearing + 22.5) % 360) / 45).floor()];
  }
}
