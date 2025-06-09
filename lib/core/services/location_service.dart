// lib/core/services/location_service.dart

import 'dart:async';

import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import '../error/app_exception.dart';
import '../constants/map_constants.dart';

class LocationService {
  static LocationService? _instance;
  static LocationService get instance => _instance ??= LocationService._();
  LocationService._();

  geolocator.Position? _lastKnownPosition;
  geolocator.Position? get lastKnownPosition => _lastKnownPosition;

  /// Check if location services are enabled and permissions are granted
  Future<bool> isLocationAvailable() async {
    bool serviceEnabled =
        await geolocator.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    geolocator.LocationPermission permission =
        await geolocator.Geolocator.checkPermission();
    return permission == geolocator.LocationPermission.always ||
        permission == geolocator.LocationPermission.whileInUse;
  }

  /// Request location permission from the user
  Future<bool> requestLocationPermission() async {
    bool serviceEnabled =
        await geolocator.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationException(
        message:
            'Location services are disabled. Please enable them in settings.',
        code: 'location_disabled',
      );
    }

    geolocator.LocationPermission permission =
        await geolocator.Geolocator.checkPermission();

    if (permission == geolocator.LocationPermission.denied) {
      permission = await geolocator.Geolocator.requestPermission();
      if (permission == geolocator.LocationPermission.denied) {
        throw PermissionException(
          message: 'Location permission denied',
          code: 'permission_denied',
        );
      }
    }

    if (permission == geolocator.LocationPermission.deniedForever) {
      throw PermissionException(
        message:
            'Location permissions are permanently denied. Please enable them in app settings.',
        code: 'permission_denied_forever',
      );
    }

    return permission == geolocator.LocationPermission.always ||
        permission == geolocator.LocationPermission.whileInUse;
  }

  /// Get the current position of the device
  Future<geolocator.Position?> getCurrentPosition({
    bool highAccuracy = true,
    Duration? timeout,
  }) async {
    try {
      // Check and request permission
      bool hasPermission = await isLocationAvailable();
      if (!hasPermission) {
        hasPermission = await requestLocationPermission();
        if (!hasPermission) {
          return null;
        }
      }

      // Get current position
      final position = await geolocator.Geolocator.getCurrentPosition(
        desiredAccuracy:
            highAccuracy
                ? geolocator.LocationAccuracy.high
                : geolocator.LocationAccuracy.medium,
        timeLimit: timeout ?? const Duration(seconds: 15),
      );

      _lastKnownPosition = position;
      print(
        'LocationService: Got current position: ${position.latitude}, ${position.longitude}',
      );
      return position;
    } on TimeoutException {
      print('LocationService: Timeout getting current position');
      // Return last known position if available
      return _lastKnownPosition;
    } catch (e) {
      print('LocationService: Error getting current position: $e');
      if (e is geolocator.LocationServiceDisabledException) {
        throw LocationException(
          message: 'Location services are disabled',
          code: 'location_disabled',
          originalError: e,
        );
      } else if (e is geolocator.PermissionDeniedException) {
        throw PermissionException(
          message: 'Location permission denied',
          code: 'permission_denied',
          originalError: e,
        );
      }
      return null;
    }
  }

  /// Get current position as a Mapbox Point (with fallback to default)
  Future<mapbox.Point> getCurrentPositionAsPoint() async {
    final position = await getCurrentPosition();
    if (position == null) {
      print(
        'LocationService: No current position available, using default center',
      );
      return MapConstants.defaultCenter;
    }

    return mapbox.Point(
      coordinates: mapbox.Position(position.longitude, position.latitude),
    );
  }

  /// Start listening to position changes (for live location tracking)
  Stream<geolocator.Position> getPositionStream({
    geolocator.LocationSettings? locationSettings,
  }) {
    return geolocator.Geolocator.getPositionStream(
      locationSettings:
          locationSettings ??
          const geolocator.LocationSettings(
            accuracy: geolocator.LocationAccuracy.high,
            distanceFilter: 10, // Only emit when user moves 10 meters
          ),
    );
  }

  /// Calculate distance between two positions in meters
  double distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return geolocator.Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Check if a position is within a certain distance from current location
  Future<bool> isWithinDistance(
    double targetLat,
    double targetLon,
    double maxDistanceMeters,
  ) async {
    final currentPos = await getCurrentPosition();
    if (currentPos == null) return false;

    final distance = distanceBetween(
      currentPos.latitude,
      currentPos.longitude,
      targetLat,
      targetLon,
    );

    return distance <= maxDistanceMeters;
  }
}
