// lib/features/map/presentation/utils/user_location_marker_manager.dart

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:geolocator/geolocator.dart' as geolocator;
import '../../../../core/services/location_service.dart';

class UserLocationMarkerManager {
  mapbox.MapboxMap? _mapboxMap;
  mapbox.PointAnnotationManager? _userLocationAnnotationManager;
  mapbox.PointAnnotation? _userLocationAnnotation;
  mapbox.PointAnnotation? _accuracyCircleAnnotation;

  // Animation state
  Timer? _pulseTimer;
  Timer? _accuracyTimer;
  double _pulseOpacity = 1.0;
  double _pulseScale = 1.0;
  double _accuracyOpacity = 0.3;

  // Current position and accuracy
  geolocator.Position? _currentPosition;
  double _currentAccuracy = 50.0; // Default 50 meter accuracy

  // Animation settings
  static const Duration _pulseDuration = Duration(
    milliseconds: 2000,
  ); // Slow pulse
  static const Duration _accuracyAnimationDuration = Duration(
    milliseconds: 3000,
  ); // Subtle accuracy animation
  static const double _minPulseOpacity = 0.4;
  static const double _maxPulseOpacity = 1.0;
  static const double _minPulseScale = 0.8;
  static const double _maxPulseScale = 1.2;
  static const double _minAccuracyOpacity = 0.1;
  static const double _maxAccuracyOpacity = 0.4;

  final LocationService _locationService = LocationService.instance;
  BuildContext? _context;

  /// Initialize the user location marker manager
  Future<void> initialize(
    mapbox.MapboxMap mapboxMap,
    BuildContext context,
  ) async {
    _mapboxMap = mapboxMap;
    _context = context;

    try {
      // Create separate annotation manager for user location (below station markers)
      _userLocationAnnotationManager =
          await mapboxMap.annotations.createPointAnnotationManager();
      print('UserLocationMarker: Annotation manager created');

      // Load custom marker images
      await _loadMarkerImages();
    } catch (e) {
      print('UserLocationMarker: Error initializing: $e');
    }
  }

  /// Load custom marker images for user location
  Future<void> _loadMarkerImages() async {
    if (_mapboxMap == null) return;

    try {
      // Create green dot marker
      final greenDotImage = await _createGreenDotImage();
      await _mapboxMap!.style.addStyleImage(
        "user-location-dot",
        1.0,
        greenDotImage,
        false,
        [],
        [],
        null,
      );

      // Create accuracy circle marker
      final accuracyCircleImage = await _createAccuracyCircleImage();
      await _mapboxMap!.style.addStyleImage(
        "user-location-accuracy",
        1.0,
        accuracyCircleImage,
        false,
        [],
        [],
        null,
      );

      print('UserLocationMarker: Custom marker images loaded');
    } catch (e) {
      print('UserLocationMarker: Error loading marker images: $e');
    }
  }

  /// Create green dot image for user location
  Future<mapbox.MbxImage> _createGreenDotImage() async {
    const size = 20; // Smaller and subtle
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw green dot with white border
    final paint =
        Paint()
          ..color = Colors.green
          ..style = PaintingStyle.fill;

    final borderPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

    const center = Offset(size / 2, size / 2);
    const radius = size / 2 - 2;

    canvas.drawCircle(center, radius, paint);
    canvas.drawCircle(center, radius, borderPaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return mapbox.MbxImage(
      width: size,
      height: size,
      data: byteData!.buffer.asUint8List(),
    );
  }

  /// Create semi-transparent accuracy circle image
  Future<mapbox.MbxImage> _createAccuracyCircleImage() async {
    const size = 100; // Base size, will be scaled based on accuracy
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw semi-transparent green circle
    final paint =
        Paint()
          ..color = Colors.green.withValues(alpha: 0.2)
          ..style = PaintingStyle.fill;

    final borderPaint =
        Paint()
          ..color = Colors.green.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;

    const center = Offset(size / 2, size / 2);
    const radius = size / 2 - 2;

    canvas.drawCircle(center, radius, paint);
    canvas.drawCircle(center, radius, borderPaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return mapbox.MbxImage(
      width: size,
      height: size,
      data: byteData!.buffer.asUint8List(),
    );
  }

  /// Show user location marker (only when auto-location is enabled)
  Future<void> showLocationMarker() async {
    if (_userLocationAnnotationManager == null || _currentPosition == null) {
      return;
    }

    try {
      // Remove existing marker first
      await hideLocationMarker();

      // Get current zoom to calculate accuracy circle size
      final cameraState = await _mapboxMap!.getCameraState();
      final zoom = cameraState.zoom;
      final accuracySize = _calculateAccuracyCircleSize(_currentAccuracy, zoom);

      final point = mapbox.Point(
        coordinates: mapbox.Position(
          _currentPosition!.longitude,
          _currentPosition!.latitude,
        ),
      );

      // Create accuracy circle annotation (below dot)
      _accuracyCircleAnnotation = await _userLocationAnnotationManager!.create(
        mapbox.PointAnnotationOptions(
          geometry: point,
          iconImage: "user-location-accuracy",
          iconSize: accuracySize,
          iconOpacity: _accuracyOpacity,
        ),
      );

      // Create green dot annotation (above accuracy circle)
      _userLocationAnnotation = await _userLocationAnnotationManager!.create(
        mapbox.PointAnnotationOptions(
          geometry: point,
          iconImage: "user-location-dot",
          iconSize: _pulseScale,
          iconOpacity: _pulseOpacity,
        ),
      );

      // Start animations
      _startPulseAnimation();
      _startAccuracyAnimation();

      print(
        'UserLocationMarker: Location marker shown at ${_currentPosition!.latitude}, ${_currentPosition!.longitude}',
      );
    } catch (e) {
      print('UserLocationMarker: Error showing location marker: $e');
    }
  }

  /// Hide user location marker (when auto-location is disabled)
  Future<void> hideLocationMarker() async {
    if (_userLocationAnnotationManager == null) return;

    try {
      // Stop animations
      _stopAnimations();

      // Remove all annotations
      await _userLocationAnnotationManager!.deleteAll();
      _userLocationAnnotation = null;
      _accuracyCircleAnnotation = null;

      print('UserLocationMarker: Location marker hidden');
    } catch (e) {
      print('UserLocationMarker: Error hiding location marker: $e');
    }
  }

  /// Update user location marker position (when "My Location" button is pressed)
  Future<void> updateLocationMarker() async {
    try {
      // Get fresh location
      final position = await _locationService.getCurrentPosition();
      if (position == null) return;

      _currentPosition = position;
      _currentAccuracy = position.accuracy;

      print(
        'UserLocationMarker: Updated position to ${position.latitude}, ${position.longitude}, accuracy: ${position.accuracy}m',
      );

      // Refresh the marker display
      await showLocationMarker();
    } catch (e) {
      print('UserLocationMarker: Error updating location: $e');
    }
  }

  /// Calculate accuracy circle size based on GPS accuracy and map zoom
  double _calculateAccuracyCircleSize(double accuracyMeters, double zoom) {
    // Convert meters to pixels based on zoom level
    // At zoom 15, 1 meter ≈ 0.5 pixels (rough approximation)
    final metersPerPixel = 156543.03392 * math.cos(0) / math.pow(2, zoom);
    final pixelRadius = accuracyMeters / metersPerPixel;

    // Clamp to reasonable size range
    final size = (pixelRadius * 2).clamp(20.0, 200.0);

    // Return as icon size multiplier (1.0 = base size)
    return size / 100.0; // Base accuracy image is 100px
  }

  /// Start pulsing animation for green dot
  void _startPulseAnimation() {
    _stopPulseAnimation();

    int animationStep = 0;
    const totalSteps = 60; // 2 seconds at ~30fps

    _pulseTimer = Timer.periodic(
      Duration(milliseconds: _pulseDuration.inMilliseconds ~/ totalSteps),
      (timer) {
        if (_userLocationAnnotation == null) {
          timer.cancel();
          return;
        }

        // Calculate sine wave for smooth pulsing
        final progress = (animationStep % totalSteps) / totalSteps;
        final sineValue = math.sin(progress * 2 * math.pi);

        // Update opacity and scale
        _pulseOpacity =
            _minPulseOpacity +
            (_maxPulseOpacity - _minPulseOpacity) * ((sineValue + 1) / 2);
        _pulseScale =
            _minPulseScale +
            (_maxPulseScale - _minPulseScale) * ((sineValue + 1) / 2);

        // Update annotation
        _updateDotAnnotation();

        animationStep++;
      },
    );
  }

  /// Start subtle animation for accuracy circle
  void _startAccuracyAnimation() {
    _stopAccuracyAnimation();

    int animationStep = 0;
    const totalSteps = 90; // 3 seconds at ~30fps

    _accuracyTimer = Timer.periodic(
      Duration(
        milliseconds: _accuracyAnimationDuration.inMilliseconds ~/ totalSteps,
      ),
      (timer) {
        if (_accuracyCircleAnnotation == null) {
          timer.cancel();
          return;
        }

        // Subtle opacity breathing effect
        final progress = (animationStep % totalSteps) / totalSteps;
        final sineValue = math.sin(progress * 2 * math.pi);

        _accuracyOpacity =
            _minAccuracyOpacity +
            (_maxAccuracyOpacity - _minAccuracyOpacity) * ((sineValue + 1) / 2);

        // Update accuracy circle annotation
        _updateAccuracyCircleAnnotation();

        animationStep++;
      },
    );
  }

  /// Update green dot annotation with current animation values
  Future<void> _updateDotAnnotation() async {
    if (_userLocationAnnotation == null ||
        _userLocationAnnotationManager == null ||
        _currentPosition == null) {
      return;
    }

    try {
      // Update the annotation properties directly
      _userLocationAnnotation!.iconSize = _pulseScale;
      _userLocationAnnotation!.iconOpacity = _pulseOpacity;

      // Call update with just the annotation
      await _userLocationAnnotationManager!.update(_userLocationAnnotation!);
    } catch (e) {
      // Silently handle animation update errors
    }
  }

  /// Update accuracy circle annotation with current animation values
  Future<void> _updateAccuracyCircleAnnotation() async {
    if (_accuracyCircleAnnotation == null ||
        _userLocationAnnotationManager == null ||
        _currentPosition == null) {
      return;
    }

    try {
      // Update the annotation properties directly
      _accuracyCircleAnnotation!.iconOpacity = _accuracyOpacity;

      // Call update with just the annotation
      await _userLocationAnnotationManager!.update(_accuracyCircleAnnotation!);
    } catch (e) {
      // Silently handle animation update errors
    }
  }

  /// Handle tap on user location marker - show coordinates in snackbar
  void handleLocationMarkerTap() {
    if (_context == null || _currentPosition == null) return;

    final lat = _currentPosition!.latitude.toStringAsFixed(6);
    final lon = _currentPosition!.longitude.toStringAsFixed(6);
    final accuracy = _currentAccuracy.toStringAsFixed(1);

    final coordinates = '$lat, $lon';

    ScaffoldMessenger.of(_context!).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.location_on, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Current Location'),
                  Text(
                    '$coordinates (±${accuracy}m)',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: coordinates));
                ScaffoldMessenger.of(_context!).hideCurrentSnackBar();
                ScaffoldMessenger.of(_context!).showSnackBar(
                  const SnackBar(
                    content: Text('Coordinates copied to clipboard'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              child: const Text('COPY', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Stop all animations
  void _stopAnimations() {
    _stopPulseAnimation();
    _stopAccuracyAnimation();
  }

  /// Stop pulse animation
  void _stopPulseAnimation() {
    _pulseTimer?.cancel();
    _pulseTimer = null;
  }

  /// Stop accuracy animation
  void _stopAccuracyAnimation() {
    _accuracyTimer?.cancel();
    _accuracyTimer = null;
  }

  /// Dispose of resources
  void dispose() {
    _stopAnimations();
    _userLocationAnnotationManager = null;
    _userLocationAnnotation = null;
    _accuracyCircleAnnotation = null;
    _mapboxMap = null;
    _context = null;
  }
}
