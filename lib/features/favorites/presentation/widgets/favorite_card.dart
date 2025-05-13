// lib/features/favorites/presentation/widgets/favorite_card.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rivr/features/favorites/services/favorite_image_service.dart';
import '../../domain/entities/favorite.dart';
import '../../../../core/services/stream_name_service.dart';
import '../../../../core/di/service_locator.dart';
import '../providers/favorites_provider.dart';
import '../widgets/edit_favorite_name_dialog.dart';

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

  @override
  void initState() {
    super.initState();
    _streamNameService = sl<StreamNameService>();
    _loadNameInfo();
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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

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
        elevation: 2,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        color: colors.surface,
        child: InkWell(
          onTap: widget.onTap,
          splashColor: cardColor.withValues(alpha: 0.1),
          highlightColor: cardColor.withValues(alpha: 0.05),
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
                                    color: cardColor.withValues(alpha: 0.2),
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

                  // Gradient Overlay
                  Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          colors.surface.withValues(alpha: 0.7),
                        ],
                        stops: const [0.6, 1.0],
                      ),
                    ),
                  ),

                  // Station name at the bottom of the image
                  Positioned(
                    bottom: 12,
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
                                    color: colors.onPrimary,
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(
                                        offset: const Offset(1, 1),
                                        blurRadius: 3,
                                        color: Colors.black54,
                                      ),
                                    ],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // Edit button next to the title
                              IconButton(
                                icon: Icon(
                                  Icons.edit,
                                  size: 18,
                                  color: colors.onPrimary,
                                ),
                                onPressed: () => _showEditNameDialog(context),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Edit Name',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Drag Handle Indicator
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: colors.onSurface.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        Icons.drag_handle,
                        size: 16,
                        color: colors.onSurfaceVariant,
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
                          color: colors.surface.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(12),
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
                                color: colors.primary,
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
                            color: colors.onPrimary,
                          ),
                          label: Text(
                            'View',
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.onPrimary,
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

                        // Delete button
                        IconButton(
                          onPressed: () {
                            _showDeleteConfirmation(context);
                          },
                          icon: Icon(Icons.delete_outline, color: colors.error),
                          tooltip: 'Remove from favorites',
                          splashRadius: 24,
                        ),
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
      'assets/img/river_images/$imgNumber.jpeg',
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

  // Confirmation dialog for deletion
  void _showDeleteConfirmation(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Text(
              'Remove Favorite',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            content: Text(
              _displayName == null || _displayName!.isEmpty
                  ? 'Are you sure you want to remove this river from your favorites?'
                  : 'Remove $_displayName from your favorites?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onDelete();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.error,
                  foregroundColor: colors.onError,
                  elevation: 0,
                ),
                child: const Text('Remove'),
              ),
            ],
          ),
    );
  }

  // Dialog to edit the river name
  void _showEditNameDialog(BuildContext context) async {
    final currentContext = context;
    final favoritesProvider = Provider.of<FavoritesProvider>(
      currentContext,
      listen: false,
    );

    // Get the original API name from StreamNameService if possible
    String? originalApiName;
    try {
      final nameInfo = await _streamNameService.getNameInfo(
        widget.favorite.stationId,
      );
      originalApiName = nameInfo.originalApiName;
    } catch (e) {
      print("Error getting original API name from service: $e");
      // Fall back to the favorite's originalApiName
      originalApiName =
          widget.favorite.originalApiName == "null"
              ? null
              : widget.favorite.originalApiName;
    }

    final currentName = _displayName ?? widget.favorite.name;

    final result = await showDialog<String>(
      context: currentContext,
      builder:
          (dialogContext) => EditFavoriteNameDialog(
            currentName: currentName,
            stationId: widget.favorite.stationId,
            originalApiName: originalApiName,
          ),
    );

    // Proceed with update if we got a result and it's different
    if (result != null && result != currentName) {
      try {
        // Update name in both the FavoritesProvider and StreamNameService
        final success = await favoritesProvider.updateFavoriteName(
          widget.favorite.userId,
          widget.favorite.stationId,
          result,
        );

        // Also try to update directly in StreamNameService for immediate effect
        try {
          await _streamNameService.updateDisplayName(
            widget.favorite.stationId,
            result,
          );

          // Update local state immediately
          if (mounted) {
            setState(() {
              _displayName = result;
              _isCustomName =
                  originalApiName != null &&
                  result != originalApiName &&
                  originalApiName.isNotEmpty;
            });
          }
        } catch (e) {
          print("Error updating StreamNameService directly: $e");
          // We'll eventually get the update when the FavoritesProvider refreshes
        }

        // Show feedback to user
        if (currentContext.mounted) {
          ScaffoldMessenger.of(currentContext).showSnackBar(
            SnackBar(
              content: Text(
                success
                    ? 'River name updated successfully'
                    : 'Failed to update river name',
              ),
            ),
          );
        }
      } catch (e) {
        print('Error updating favorite name: $e');
        if (currentContext.mounted) {
          ScaffoldMessenger.of(currentContext).showSnackBar(
            SnackBar(content: Text('Error updating river name: $e')),
          );
        }
      }
    }
  }
}
