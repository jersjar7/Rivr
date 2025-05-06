// lib/features/favorites/presentation/widgets/favorite_card.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/favorite.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/favorites_provider.dart';
import '../widgets/edit_favorite_name_dialog.dart';

class FavoriteCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    // Default image if none specified - use river_images subfolder
    final imgNumber =
        favorite.imgNumber ?? (favorite.stationId.hashCode % 30 + 1);

    // Parse color or use default
    Color cardColor;
    if (favorite.color != null) {
      // Convert hex color to Color object
      try {
        final colorValue = int.parse(favorite.color!.replaceAll('#', '0xff'));
        cardColor = Color(colorValue);
      } catch (_) {
        cardColor = AppColors.primaryColor;
      }
    } else {
      cardColor = AppColors.primaryColor;
    }

    // Display name
    final displayName = _getDisplayName(favorite);

    // Check if this is a custom name by comparing with original API name
    final isCustomName =
        favorite.originalApiName != null &&
        favorite.name != favorite.originalApiName;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        color: Colors.white,
        child: InkWell(
          onTap: onTap,
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
                    tag: 'river_image_${favorite.stationId}',
                    child: Image.asset(
                      'assets/img/river_images/$imgNumber.jpeg',
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback image when the asset fails to load
                        return Container(
                          height: 160,
                          width: double.infinity,
                          color: cardColor.withValues(alpha: 0.3),
                          child: Icon(Icons.water, size: 80, color: cardColor),
                        );
                      },
                    ),
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
                          Colors.black.withValues(alpha: 0.7),
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
                        // Title
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(
                                        offset: Offset(1, 1),
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
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                onPressed: () => _showEditNameDialog(context),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Edit Name',
                              ),
                            ],
                          ),
                        ),

                        // Flow indicator color dot (could be tied to water level in future)
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _getFlowStatusColor(favorite.stationId),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
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
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.drag_handle,
                        color: Colors.white70,
                        size: 16,
                      ),
                    ),
                  ),

                  // Optional: Show indicator for custom-named rivers
                  if (isCustomName)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit_attributes,
                              size: 12,
                              color: AppColors.primaryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Custom Name',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryColor,
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
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Station ID: ${favorite.stationId}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),

                    // Action Buttons
                    Row(
                      children: [
                        // View button
                        ElevatedButton.icon(
                          onPressed: onTap,
                          icon: const Icon(Icons.analytics, size: 16),
                          label: const Text('View'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                        // Delete button
                        IconButton(
                          onPressed: () {
                            _showDeleteConfirmation(context);
                          },
                          icon: Icon(
                            Icons.delete_outline,
                            color: Colors.grey[600],
                          ),
                          tooltip: 'Remove from favorites',
                          splashRadius: 24,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Description (if any)
              if (favorite.description != null &&
                  favorite.description!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Divider(color: Colors.grey[300]),
                      const SizedBox(height: 8),
                      Text(
                        favorite.description!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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

  // Get a display name for the river, using fallbacks if needed
  String _getDisplayName(Favorite favorite) {
    // Simply return the name as-is, even if empty
    return favorite.name;
  }

  // This would ideally come from real-time data
  Color _getFlowStatusColor(String stationId) {
    // Mock implementation - in reality would be based on flow data
    final value = stationId.hashCode % 4;

    switch (value) {
      case 0:
        return Colors.green; // Normal flow
      case 1:
        return Colors.orange; // Higher than normal
      case 2:
        return Colors.red; // High/dangerous
      default:
        return Colors.blue; // Lower than normal
    }
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: const Text('Remove Favorite'),
            content: Text(
              favorite.name.isEmpty
                  ? 'Are you sure you want to remove this river from your favorites?'
                  : 'Are you sure you want to remove ${favorite.name} from your favorites?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  onDelete();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[400],
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                child: const Text('Remove'),
              ),
            ],
          ),
    );
  }

  // Show dialog to edit the river name
  void _showEditNameDialog(BuildContext context) async {
    final favoritesProvider = Provider.of<FavoritesProvider>(
      context,
      listen: false,
    );

    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => EditFavoriteNameDialog(
            currentName: favorite.name,
            stationId: favorite.stationId,
            originalApiName:
                favorite.originalApiName, // Pass the original API name
          ),
    );

    // If we got a new name and it's different from the current one
    if (result != null && result != favorite.name) {
      // Update the name
      final success = await favoritesProvider.updateFavoriteName(
        favorite.userId,
        favorite.stationId,
        result,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('River name updated successfully')),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update river name')));
      }
    }
  }
}
