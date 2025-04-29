// lib/features/favorites/presentation/widgets/favorite_item.dart

import 'package:flutter/material.dart';
import '../../domain/entities/favorite.dart';

class FavoriteItem extends StatelessWidget {
  final Favorite favorite;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const FavoriteItem({
    super.key,
    required this.favorite,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Default image if none specified
    final imgNumber = favorite.imgNumber ?? 1;

    // Parse color or use default
    Color cardColor;
    if (favorite.color != null) {
      // Convert hex color to Color object
      try {
        final colorValue = int.parse(favorite.color!.replaceAll('#', '0xff'));
        cardColor = Color(colorValue);
      } catch (_) {
        cardColor = theme.colorScheme.primary;
      }
    } else {
      cardColor = theme.colorScheme.primary;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            // Image Section
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: cardColor.withOpacity(0.8),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
                image: DecorationImage(
                  image: AssetImage(
                    'assets/img/river_${imgNumber % 5 + 1}.jpg',
                  ),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    cardColor.withOpacity(0.3),
                    BlendMode.srcOver,
                  ),
                ),
              ),
              child: Stack(
                children: [
                  // Station Name
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 48,
                    child: Text(
                      favorite.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            offset: Offset(1, 1),
                            blurRadius: 2,
                            color: Colors.black45,
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Delete button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          // Show confirmation dialog
                          showDialog(
                            context: context,
                            builder:
                                (context) => AlertDialog(
                                  title: const Text('Remove Favorite'),
                                  content: Text(
                                    'Are you sure you want to remove ${favorite.name} from your favorites?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        onDelete();
                                      },
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                      child: const Text('Remove'),
                                    ),
                                  ],
                                ),
                          );
                        },
                        tooltip: 'Remove from favorites',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Details Section
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  // Station ID
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Station ID',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        favorite.stationId,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // View Forecast Button
                  ElevatedButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.analytics),
                    label: const Text('View Forecast'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Description (if any)
            if (favorite.description != null &&
                favorite.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
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
    );
  }
}
