// lib/features/favorites/presentation/widgets/favorite_card.dart

import 'package:flutter/material.dart';
import '../../domain/entities/favorite.dart';
import '../../../../core/theme/app_theme.dart';

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
    // Default image if none specified
    final imgNumber =
        favorite.imgNumber ?? (favorite.stationId.hashCode % 5 + 1);

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
                          child: Text(
                            favorite.name,
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
                          color: AppColors.textColor.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Station ID: ${favorite.stationId}',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textColor.withValues(alpha: 0.7),
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
                          color: AppColors.textColor.withValues(alpha: 0.8),
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
              'Are you sure you want to remove ${favorite.name} from your favorites?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.textColor),
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
}
