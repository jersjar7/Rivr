// lib/core/constants/map_constants.dart

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

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
  static const String defaultMapStyle = MapboxStyles.MAPBOX_STREETS;

  // Default map center (Utah, USA)
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
