// lib/features/forecast/presentation/widgets/map_overlay.dart

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/models/location_info.dart'; // Ensure this path is correct

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
  bool _closing = false;
  bool _isMapResourceDisposed = true; // Initialize as true (no map yet)

  @override
  void initState() {
    super.initState();
    print('🗺️ [MapOverlay] initState()');

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addStatusListener((status) {
      print('🗺️ [Animation] status: $status');
    });
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );

    // Forward animation for opening
    // It's good practice to start after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animationController.forward().then((_) {
          if (mounted) {
            print('🗺️ [Animation] forward complete');
          }
        });
      }
    });
  }

  void _closeOverlay() {
    if (_closing || !mounted) return;
    _closing = true;
    print(
      '🗺️ [MapOverlay] _closeOverlay() tapped - immediate close initiated',
    );

    // Pop the navigator. This will trigger MapOverlayState.dispose()
    // which will handle map resource cleanup.
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    print('🗺️ [MapOverlay] dispose(): Disposing _animationController.');
    _animationController.dispose();

    // Dispose map if it exists and hasn't been disposed yet.
    // This will be called when Navigator.pop() unmounts the widget.
    if (_mapboxMap != null && !_isMapResourceDisposed) {
      final mapToDisposeInstance = _mapboxMap; // Capture instance locally
      _mapboxMap =
          null; // Clear instance variable immediately to prevent further use

      print(
        '🗺️ [MapOverlay] dispose(): Scheduling native map disposal via addPostFrameCallback.',
      );
      // Schedule disposal for after the current frame, ensuring UI is unmounted.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        print(
          '🗺️ [MapOverlay] PostFrameCallback in dispose(): Now disposing native map.',
        );
        try {
          mapToDisposeInstance?.dispose(); // Use the captured instance
          print(
            '🗺️ [MapOverlay] PostFrameCallback in dispose(): map.dispose() succeeded.',
          );
        } catch (e, st) {
          print(
            '⚠️ [MapOverlay] PostFrameCallback in dispose(): map.dispose() threw: $e\n$st',
          );
        } finally {
          // This flag is managed by this dispose sequence.
          // No need to set _isMapResourceDisposed here as it's part of the state's own teardown.
        }
      });
      _isMapResourceDisposed = true; // Mark that disposal has been initiated.
    } else {
      if (_mapboxMap == null) {
        print('🗺️ [MapOverlay] dispose(): _mapboxMap is already null.');
      }
      if (_isMapResourceDisposed) {
        print(
          '🗺️ [MapOverlay] dispose(): Map resources already marked as disposed.',
        );
      }
      _mapboxMap = null; // Ensure it's null
      _isMapResourceDisposed = true; // Ensure flag reflects state
    }

    super.dispose();
    print('🗺️ [MapOverlay] dispose() done');
  }

  @override
  Widget build(BuildContext context) {
    print(
      '🗺️ [MapOverlay] build() — isMapReady=$_isMapReady, error="$_errorMessage"',
    );
    final screenSize = MediaQuery.of(context).size;
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        // Since _closeOverlay now pops immediately, the widget will disappear.
        // The _animation.value will be 1.0 (or its last state from opening).
        // ScaleTransition will use this value.

        return GestureDetector(
          onTap: _closeOverlay, // Tap background to close
          child: Container(
            color: Colors.black.withOpacity(
              0.5 * _animation.value,
            ), // Corrected
            child: Center(
              child: GestureDetector(
                // To prevent taps on the card from closing
                onTap: () {},
                child: ScaleTransition(
                  scale: _animation, // Opening animation still uses this
                  child: Container(
                    // CRITICAL CHANGE for RenderFlex and MapBox invalid size:
                    // Use fixed dimensions; ScaleTransition handles the visual scaling.
                    width: screenSize.width * 0.9,
                    height: screenSize.height * 0.7,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2), // Corrected
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    // Only build content if scale is not zero (avoids issues at start of animation)
                    child:
                        _animation.value == 0 &&
                                !_animationController.isAnimating
                            ? const SizedBox.shrink()
                            : ClipRRect(
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
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize:
                                                MainAxisSize.min, // Important
                                            children: [
                                              // CRITICAL CHANGE for RenderFlex: Wrap Text in Flexible
                                              Flexible(
                                                child: Text(
                                                  widget.riverName,
                                                  style: theme
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (widget.locationInfo != null)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 2.0,
                                                      ),
                                                  child: Text(
                                                    widget
                                                        .locationInfo!
                                                        .formattedLocation,
                                                    style:
                                                        theme
                                                            .textTheme
                                                            .bodySmall,
                                                    maxLines:
                                                        1, // Ensure this also truncates
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
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

                                  // Map Section
                                  Expanded(
                                    child: Stack(
                                      children: [
                                        // Loading Indicator
                                        if (!_isMapReady &&
                                            _errorMessage.isEmpty)
                                          Container(
                                            color:
                                                theme
                                                    .colorScheme
                                                    .surfaceContainerHighest,
                                            child: Center(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  CircularProgressIndicator(
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                          Color
                                                        >(
                                                          theme
                                                              .colorScheme
                                                              .primary,
                                                        ),
                                                  ),
                                                  const SizedBox(height: 16),
                                                  Text(
                                                    'Loading map...',
                                                    style:
                                                        theme
                                                            .textTheme
                                                            .bodyMedium,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        // Error Message
                                        if (_errorMessage.isNotEmpty)
                                          Container(
                                            color:
                                                theme
                                                    .colorScheme
                                                    .surfaceContainerHighest,
                                            padding: const EdgeInsets.all(16),
                                            child: Center(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.error_outline,
                                                    color:
                                                        theme.colorScheme.error,
                                                    size: 48,
                                                  ),
                                                  const SizedBox(height: 16),
                                                  Text(
                                                    'Could not load map',
                                                    style:
                                                        theme
                                                            .textTheme
                                                            .titleMedium,
                                                    textAlign: TextAlign.center,
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    _errorMessage,
                                                    style:
                                                        theme
                                                            .textTheme
                                                            .bodyMedium,
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        // MapWidget: Only build if no error and animation has progressed
                                        if (_errorMessage.isEmpty &&
                                            (_animation.value > 0 ||
                                                _animationController
                                                    .isCompleted))
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
                                        // Attribution (Mapbox logo)
                                        if (_isMapReady &&
                                            _errorMessage.isEmpty)
                                          Positioned(
                                            bottom: 4,
                                            right: 4,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(
                                                  0.7,
                                                ), // Corrected
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '© Mapbox',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
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
          ),
        );
      },
    );
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    if (!mounted || _closing) {
      print(
        '🗺️ [MapOverlay] onMapCreated: Widget not mounted or closing. Disposing newly created map.',
      );
      mapboxMap.dispose(); // Dispose this instance as it won't be used.
      return;
    }

    print('🗺️ [MapOverlay] onMapCreated → $mapboxMap');
    _mapboxMap = mapboxMap;
    _isMapResourceDisposed = false; // New map is active, not disposed.

    try {
      print('🗺️ [MapOverlay] setting up annotations…');
      // User's original delay, consider if still needed or can be shorter.
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted || _closing) return;

      final annotationManager =
          await mapboxMap.annotations.createPointAnnotationManager();
      if (!mounted || _closing) return;

      final ByteData bytes = await rootBundle.load(
        'assets/img/marker_selected.png',
      );
      if (!mounted || _closing) return;
      final Uint8List assetBytes = bytes.buffer.asUint8List();

      final completer = Completer<ui.Image>();
      ui.decodeImageFromList(assetBytes, (image) {
        if (!mounted) {
          // Check mounted state within this async callback too
          completer.completeError(
            StateError("Widget unmounted before image decoded."),
          );
          return;
        }
        completer.complete(image);
      });

      final markerImage = await completer.future;
      if (!mounted || _closing) return;

      final mbxImage = MbxImage(
        width: markerImage.width,
        height: markerImage.height,
        data: assetBytes,
      );

      final imageId = 'selected-marker';
      await mapboxMap.style.addStyleImage(
        imageId,
        1.0,
        mbxImage,
        false,
        [],
        [],
        null,
      );
      if (!mounted || _closing) return;

      final markerOptions = PointAnnotationOptions(
        geometry: Point(coordinates: Position(widget.lon, widget.lat)),
        iconSize: 0.1,
        iconOffset: [0, 0], // Default, can be omitted
        symbolSortKey: 10, // Optional
        iconImage: imageId,
      );

      await annotationManager.create(markerOptions);
      if (!mounted || _closing)
        return; // Check after last await before setState

      print('🗺️ [MapOverlay] marker created');
      if (mounted && !_closing) {
        // Final check before setState
        setState(() {
          _isMapReady = true;
          _errorMessage = ''; // Clear any previous error
        });
        print('🗺️ [MapOverlay] setState(_isMapReady=true)');
      }
    } catch (e, st) {
      if (kDebugMode) {
        print('Error setting up map: $e');
        print('⚠️ [MapOverlay] error in _onMapCreated: $e\n$st');
      }
      if (mounted && !_closing) {
        // Check before setState
        setState(() {
          _errorMessage =
              'Could not display map features. Please try again later.';
          _isMapReady = false; // Ensure map isn't considered ready on error
        });
      }
    }
  }
}
