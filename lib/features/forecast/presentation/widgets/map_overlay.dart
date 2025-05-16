// lib/features/forecast/presentation/widgets/map_overlay.dart

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/models/location_info.dart';

class MapOverlay extends StatefulWidget {
  final double lat;
  final double lon;
  final LocationInfo? locationInfo;
  final String riverName;

  const MapOverlay({
    super.key,
    required this.lat,
    required this.lon,
    this.locationInfo,
    required this.riverName,
  });

  @override
  State<MapOverlay> createState() => _MapOverlayState();
}

class _MapOverlayState extends State<MapOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isMapReady = false;
  MapboxMap? _mapboxMap;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();

    // Set up animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );

    // Start animation
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return GestureDetector(
          onTap: () {
            _closeOverlay();
          },
          child: Container(
            width: screenSize.width,
            height: screenSize.height,
            color: Colors.black.withValues(alpha: 0.5 * _animation.value),
            child: Center(
              child: GestureDetector(
                onTap: () {}, // Prevent closing when tapping the map container
                child: Container(
                  width: screenSize.width * 0.9 * _animation.value,
                  height: screenSize.height * 0.7 * _animation.value,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            border: Border(
                              bottom: BorderSide(
                                color: theme.dividerColor,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.riverName,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (widget.locationInfo != null)
                                      Text(
                                        widget.locationInfo!.formattedLocation,
                                        style: theme.textTheme.bodySmall,
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: _closeOverlay,
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ),

                        // Map
                        Expanded(
                          child: Stack(
                            children: [
                              // Show loading indicator or static map until MapBox is ready
                              if (!_isMapReady)
                                Container(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircularProgressIndicator(
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                theme.colorScheme.primary,
                                              ),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Loading map...',
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                              // Error message if map fails to load
                              if (_errorMessage.isNotEmpty)
                                Container(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  padding: const EdgeInsets.all(16),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          color: theme.colorScheme.error,
                                          size: 48,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Could not load map',
                                          style: theme.textTheme.titleMedium,
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _errorMessage,
                                          style: theme.textTheme.bodyMedium,
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                              // Mapbox map
                              if (_errorMessage.isEmpty)
                                Positioned.fill(
                                  child: MapWidget(
                                    key: ValueKey(
                                      'map_${widget.lat}_${widget.lon}',
                                    ),
                                    onMapCreated: _onMapCreated,
                                    styleUri: MapboxStyles.STANDARD,
                                    cameraOptions: CameraOptions(
                                      center: Point(
                                        coordinates: Position(
                                          widget.lon,
                                          widget.lat,
                                        ),
                                      ),
                                      zoom: 12.0,
                                    ),
                                  ),
                                ),

                              // Attribution
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '© Mapbox',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 10,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    // Add a marker at the river's location
    try {
      // Delay slightly to ensure map is fully initialized
      await Future.delayed(const Duration(milliseconds: 500));

      // Create a point annotation manager
      final annotationManager =
          await mapboxMap.annotations.createPointAnnotationManager();

      // Load image from assets
      final ByteData bytes = await rootBundle.load(
        'assets/img/marker_selected.png',
      );
      final Uint8List assetBytes = bytes.buffer.asUint8List();

      // Get image dimensions for proper loading
      final completer = Completer<ui.Image>();
      ui.decodeImageFromList(assetBytes, (image) {
        completer.complete(image);
      });
      final markerImage = await completer.future;

      // Create MbxImage object with proper dimensions
      final mbxImage = MbxImage(
        width: markerImage.width,
        height: markerImage.height,
        data: assetBytes,
      );

      // Add the image to the style
      final imageId = 'selected-marker';
      await mapboxMap.style.addStyleImage(
        imageId,
        1.0, // scale
        mbxImage,
        false, // sdf
        [], // stretchX
        [], // stretchY
        null, // content
      );

      // Create a marker at the river's location
      final markerOptions = PointAnnotationOptions(
        geometry: Point(coordinates: Position(widget.lon, widget.lat)),
        iconSize: 0.5,
        iconOffset: [0, 0],
        symbolSortKey: 10,
        iconImage: imageId,
      );

      // Add the annotation to the map
      await annotationManager.create(markerOptions);

      // Update state to show the map
      if (mounted) {
        setState(() {
          _isMapReady = true;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error setting up map: $e');
      }

      if (mounted) {
        setState(() {
          _errorMessage = 'Could not display map. Please try again later.';
        });
      }
    }
  }

  void _closeOverlay() {
    // Reverse animation and then close
    _animationController.reverse().then((_) {
      // Dispose the map before popping to avoid "used after being disposed" error
      final mapToDispose = _mapboxMap;
      _mapboxMap = null; // Clear the reference first

      // Now it's safe to pop the route
      Navigator.of(context).pop();

      // Dispose the map after we've popped the route
      // We use a microtask to ensure this happens after the frame is complete
      if (mapToDispose != null) {
        Future.microtask(() {
          try {
            mapToDispose.dispose();
          } catch (e) {
            // Ignore errors if the map was already disposed
            if (kDebugMode) {
              print('Error disposing map: $e');
            }
          }
        });
      }
    });
  }
}
