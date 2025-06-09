// lib/core/constants/map_constants.dart

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../services/location_service.dart';

class MapConstants {
  // Access token from environment file
  static String get accessToken {
    final token = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
    if (token.isEmpty) {
      print("WARNING: Mapbox token is empty! Check your .env files.");
      // For development, you might want to hardcode a fallback token here
      // return "sk.eyJ1IjoiamVy..."; // Fallback for dev only
    }
    return token;
  }

  // Map styles
  static const String mapboxStreets = MapboxStyles.MAPBOX_STREETS;
  static const String mapboxLight = MapboxStyles.LIGHT;
  static const String mapboxDark = MapboxStyles.DARK;
  static const String mapboxSatelliteStreets = MapboxStyles.SATELLITE_STREETS;
  static const String mapboxStandard = MapboxStyles.STANDARD;
  static const String mapboxOutdoors = MapboxStyles.OUTDOORS;

  // Default map style
  static const String defaultMapStyle = MapboxStyles.STANDARD;

  // Default map center (Utah, USA) - fallback location
  static final Point defaultCenter = Point(
    coordinates: Position(-111.658531, 40.233845),
  );

  // Default zoom level
  static const double defaultZoom = 9.0;

  // Minimum zoom level to show station markers
  static const double minZoomForMarkers = 8.0;

  // 3D settings
  static const double defaultTilt = 45.0;
  static const double terrainExaggeration = 1.5;

  // Marker clustering
  static const int clusterRadius = 40; // pixels
  static const int clusterMaxZoom = 13; // max zoom to cluster points
  static const int maxMarkersForPerformance =
      1300000; // maximum markers to display

  // Marker style
  static const double defaultMarkerSize = 15.0;
  static const double selectedMarkerSize = 20.0;
  static const String defaultMarkerColor = "#2389DA"; // Blue
  static const String selectedMarkerColor = "#FF5733"; // Orange-red

  // Search
  static const String mapboxSearchApiUrl =
      'https://api.mapbox.com/geocoding/v5/mapbox.places/';
  static const int searchResultLimit = 5;

  // Animation durations
  static const int mapAnimationDurationMs = 5000;
  static const int mapAnimationDelayMs = 0;

  // Location settings
  static const Duration locationTimeout = Duration(seconds: 5);

  /// Get initial map center - tries current location first, falls back to Utah
  /// This method includes a 5-second timeout and proper error handling
  static Future<Point> getInitialCenter({
    bool useCurrentLocation = true,
  }) async {
    if (!useCurrentLocation) {
      print(
        "MAP CONSTANTS: Using default Utah location (user disabled current location)",
      );
      return defaultCenter;
    }

    try {
      print(
        "MAP CONSTANTS: Trying to get current location for initial map center...",
      );

      final locationService = LocationService.instance;
      final point = await locationService.getCurrentPositionAsPoint().timeout(
        locationTimeout,
        onTimeout: () {
          print(
            "MAP CONSTANTS: Location timeout after ${locationTimeout.inSeconds}s, using default center",
          );
          return defaultCenter;
        },
      );

      // Check if we got the actual current location or the fallback
      final currentPos = locationService.lastKnownPosition;
      if (currentPos != null) {
        print(
          "MAP CONSTANTS: Successfully got current location: ${currentPos.latitude}, ${currentPos.longitude}",
        );
      } else {
        print(
          "MAP CONSTANTS: Location service returned default center (no GPS)",
        );
      }

      return point;
    } catch (e) {
      print("MAP CONSTANTS: Error getting current location: $e");
      print("MAP CONSTANTS: Falling back to default Utah location");
      return defaultCenter;
    }
  }

  /// Check if a point is the default Utah location
  static bool isDefaultLocation(Point point) {
    const double tolerance =
        0.001; // Small tolerance for floating point comparison
    return (point.coordinates.lng - defaultCenter.coordinates.lng).abs() <
            tolerance &&
        (point.coordinates.lat - defaultCenter.coordinates.lat).abs() <
            tolerance;
  }

  // Add this method to log the token status
  static void logTokenStatus() {
    final token = accessToken;
    final tokenLength = token.length;
    final maskedToken =
        token.isNotEmpty
            ? '${token.substring(0, 5)}...${token.substring(token.length - 5)}'
            : 'EMPTY';

    print(
      "MAP CONSTANTS: Mapbox access token = $maskedToken (length: $tokenLength)",
    );

    if (token.isEmpty) {
      print(
        "MAP CONSTANTS: WARNING - Empty Mapbox access token will cause map tiles not to display",
      );
    }
  }
}
