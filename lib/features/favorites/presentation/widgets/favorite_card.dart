// lib/features/favorites/presentation/widgets/favorite_card.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:rivr/core/models/location_info.dart';
import 'package:rivr/core/services/geocoding_service.dart';
import 'package:rivr/features/favorites/services/favorite_image_service.dart';
import '../../domain/entities/favorite.dart';
import '../../../../core/services/stream_name_service.dart';
import '../../../../core/di/service_locator.dart';

class FavoriteCard extends StatefulWidget {
  final Favorite favorite;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const FavoriteCard({
    super.key,
    required this.favorite,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<FavoriteCard> createState() => _FavoriteCardState();
}

class _FavoriteCardState extends State<FavoriteCard> {
  late StreamNameService _streamNameService;
  String? _displayName;
  bool _isLoadingName = true;
  bool _isCustomName = false;

  // Add location-related state variables
  LocationInfo? _locationInfo;

  @override
  void initState() {
    super.initState();
    _streamNameService = sl<StreamNameService>();
    _loadNameInfo();

    // Load location information if coordinates are available
    if (widget.favorite.lat != null && widget.favorite.lon != null) {
      _loadLocationInfo();
    }
  }

  // Add method to load location information
  Future<void> _loadLocationInfo() async {
    /// Skip if no coordinates available or if we already have city and state
    if (widget.favorite.lat == null ||
        widget.favorite.lon == null ||
        (_locationInfo != null && _locationInfo!.city.isNotEmpty)) {
      return;
    }

    try {
      // Get geocoding service from service locator
      final geocodingService = sl<GeocodingService>();

      // Get location info from coordinates
      final locationInfo = await geocodingService.getLocationInfo(
        widget.favorite.lat!,
        widget.favorite.lon!,
      );

      if (mounted) {
        setState(() {
          _locationInfo = locationInfo;
        });
      }
    } catch (e) {
      print('Error loading location info: $e');
    }
  }

  // Load name information from the service
  Future<void> _loadNameInfo() async {
    setState(() => _isLoadingName = true);

    try {
      // Get the current name from StreamNameService
      final nameInfo = await _streamNameService.getNameInfo(
        widget.favorite.stationId,
      );

      // Check if it's a custom name
      bool isCustom = false;
      if (nameInfo.originalApiName != null &&
          nameInfo.originalApiName!.isNotEmpty &&
          nameInfo.displayName != nameInfo.originalApiName) {
        isCustom = true;
      }

      // Update state if the widget is still mounted
      if (mounted) {
        setState(() {
          _displayName = nameInfo.displayName;
          _isCustomName = isCustom;
          _isLoadingName = false;
        });
      }
    } catch (e) {
      print("Error loading name info: $e");
      // Fallback to the favorite's name
      if (mounted) {
        setState(() {
          _displayName = widget.favorite.name;
          // Check if it's a custom name using the favorite entity
          final String? apiName =
              widget.favorite.originalApiName == "null"
                  ? null
                  : widget.favorite.originalApiName;
          _isCustomName =
              apiName != null &&
              widget.favorite.name != apiName &&
              apiName.isNotEmpty;
          _isLoadingName = false;
        });
      }
    }
  }

  @override
  void didUpdateWidget(FavoriteCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reload name info if the favorite has changed
    if (oldWidget.favorite.stationId != widget.favorite.stationId ||
        oldWidget.favorite.name != widget.favorite.name ||
        oldWidget.favorite.lastUpdated != widget.favorite.lastUpdated) {
      _loadNameInfo();
    }

    // Reload location info if coordinates changed
    if (oldWidget.favorite.lat != widget.favorite.lat ||
        oldWidget.favorite.lon != widget.favorite.lon) {
      if (widget.favorite.lat != null && widget.favorite.lon != null) {
        _loadLocationInfo();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final brightness = theme.brightness;

    // Default image if none specified
    final imgNumber =
        widget.favorite.imgNumber ??
        (widget.favorite.stationId.hashCode % 30 + 1);

    // Parse custom color or fall back to primary
    Color cardColor;
    try {
      cardColor =
          widget.favorite.color != null
              ? Color(int.parse(widget.favorite.color!.replaceAll('#', '0xff')))
              : colors.primary;
    } catch (_) {
      cardColor = colors.primary;
    }

    // Determine display name
    final displayName =
        _isLoadingName
            ? widget.favorite.name
            : (_displayName ?? widget.favorite.name);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Material(
        elevation: 4, // Increased elevation for better visibility in dark mode
        clipBehavior: Clip.antiAlias,
        color: colors.surface,
        // Add a border that's visible in dark mode with borderRadius included in shape
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color:
                brightness == Brightness.dark
                    ? colors.outline.withOpacity(0.3)
                    : Colors.transparent,
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: widget.onTap,
          splashColor: cardColor.withOpacity(0.1),
          highlightColor: cardColor.withOpacity(0.05),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Image with Gradient Overlay
              Stack(
                children: [
                  // River Image
                  Hero(
                    tag: 'river_image_${widget.favorite.stationId}',
                    child:
                        widget.favorite.customImagePath != null &&
                                widget.favorite.customImagePath!.isNotEmpty
                            ? FutureBuilder<String?>(
                              future: FavoriteImageService.getImagePath(
                                widget.favorite.customImagePath!,
                              ),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return Container(
                                    height: 160,
                                    width: double.infinity,
                                    color: cardColor.withOpacity(0.2),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(
                                          colors.primary,
                                        ),
                                      ),
                                    ),
                                  );
                                }

                                final imagePath = snapshot.data;
                                if (imagePath != null) {
                                  return Image.file(
                                    File(imagePath),
                                    height: 160,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      // Fallback to default image
                                      return _buildDefaultImage(
                                        imgNumber,
                                        cardColor,
                                      );
                                    },
                                  );
                                } else {
                                  // Fallback to default image
                                  return _buildDefaultImage(
                                    imgNumber,
                                    cardColor,
                                  );
                                }
                              },
                            )
                            : _buildDefaultImage(imgNumber, cardColor),
                  ),

                  // Gradient Overlay - Enhanced for better visibility in dark mode
                  Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(
                            0.6,
                          ), // Darker overlay for better contrast
                        ],
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),

                  // Station name at the bottom of the image
                  Positioned(
                    bottom: 30,
                    left: 16,
                    right: 16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Title with loading indicator if needed
                        Expanded(
                          child: Row(
                            children: [
                              if (_isLoadingName)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                              if (_isLoadingName) const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  displayName,
                                  style: textTheme.titleMedium?.copyWith(
                                    color:
                                        Colors
                                            .white, // Always white for better visibility
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(
                                        offset: const Offset(1, 1),
                                        blurRadius: 3,
                                        color: Colors.black.withOpacity(
                                          0.7,
                                        ), // Darker shadow
                                      ),
                                      Shadow(
                                        offset: const Offset(1, 1),
                                        blurRadius: 2,
                                        color:
                                            Colors.black, // Additional shadow
                                      ),
                                    ],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Location information display
                  if (widget.favorite.city != null &&
                      widget.favorite.state != null)
                    Positioned(
                      bottom: 10, // Position above the station name
                      left: 16,
                      right: 16,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 12,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${widget.favorite.city}, ${widget.favorite.state}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Drag Handle Indicator - Enhanced for dark mode
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color:
                            brightness == Brightness.dark
                                ? Colors.black.withOpacity(0.6)
                                : colors.onSurface.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 0.5,
                        ),
                      ),
                      child: Icon(
                        Icons.drag_handle,
                        size: 18,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ),

                  // Optional: Show indicator for custom-named rivers
                  if (_isCustomName)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              brightness == Brightness.dark
                                  ? Colors.black.withOpacity(0.6)
                                  : colors.surface.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colors.primary.withOpacity(0.3),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit_attributes,
                              size: 12,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Custom Name',
                              style: textTheme.labelSmall?.copyWith(
                                color:
                                    brightness == Brightness.dark
                                        ? Colors.white
                                        : colors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              // Content Section
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Station ID with icon
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Station ID: ${widget.favorite.stationId}',
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),

                    // Action Buttons
                    Row(
                      children: [
                        // View button
                        ElevatedButton.icon(
                          onPressed: widget.onTap,
                          icon: Icon(
                            Icons.analytics,
                            size: 16,
                            color:
                                brightness == Brightness.dark
                                    ? colors.onPrimary
                                    : Colors.white,
                          ),
                          label: Text(
                            'View',
                            style: textTheme.bodySmall?.copyWith(
                              color:
                                  brightness == Brightness.dark
                                      ? colors.onPrimary
                                      : Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            textStyle: textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultImage(int imgNumber, Color cardColor) {
    return Image.asset(
      'assets/img/river_images/$imgNumber.png',
      height: 160,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        // Fallback image when the asset fails to load
        return Container(
          height: 160,
          width: double.infinity,
          color: cardColor.withAlpha(80),
          child: Icon(Icons.water, size: 80, color: cardColor),
        );
      },
    );
  }
}
