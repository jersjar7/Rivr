// lib/features/favorites/presentation/widgets/favorite_list_item.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rivr/features/favorites/presentation/providers/favorites_provider.dart';

class FavoriteListItem extends StatelessWidget {
  final FavoriteRiver favorite;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  const FavoriteListItem({
    super.key,
    required this.favorite,
    this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final flowCategory = favorite.flowCategory ?? 'Unknown';

    // Determine color based on flow category
    Color categoryColor;
    switch (flowCategory) {
      case 'Low':
        categoryColor = Colors.blue.shade200;
        break;
      case 'Normal':
        categoryColor = Colors.green;
        break;
      case 'Moderate':
        categoryColor = Colors.yellow.shade700;
        break;
      case 'High':
        categoryColor = Colors.orange;
        break;
      case 'Very High':
        categoryColor = Colors.deepOrange;
        break;
      case 'Extreme':
        categoryColor = Colors.red;
        break;
      case 'Catastrophic':
        categoryColor = Colors.purple;
        break;
      default:
        categoryColor = Colors.grey;
    }

    final flowFormatter = NumberFormat('#,##0.0');
    final dateFormatter = DateFormat('MMM d, h:mm a');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Flow indicator circle
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: categoryColor.withOpacity(0.2),
                  border: Border.all(color: categoryColor, width: 2),
                ),
                child: Center(
                  child:
                      favorite.lastFlow != null
                          ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                flowFormatter.format(favorite.lastFlow!),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: categoryColor,
                                ),
                              ),
                              const Text(
                                'ft³/s',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          )
                          : const Icon(Icons.water_drop, color: Colors.grey),
                ),
              ),

              const SizedBox(width: 16),

              // River info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      favorite.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (favorite.latitude != null && favorite.longitude != null)
                      Text(
                        'Lat: ${favorite.latitude!.toStringAsFixed(5)}, Lon: ${favorite.longitude!.toStringAsFixed(5)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    const SizedBox(height: 4),
                    if (favorite.lastUpdated != null)
                      Text(
                        'Updated: ${dateFormatter.format(favorite.lastUpdated!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),

              // Flow status
              if (favorite.flowCategory != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: categoryColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    favorite.flowCategory!,
                    style: TextStyle(
                      color:
                          categoryColor.computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              // Remove button (optional)
              if (onRemove != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.red.shade400,
                  onPressed: onRemove,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
