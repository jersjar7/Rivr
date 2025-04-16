// lib/features/map/presentation/widgets/station_info_panel.dart

import 'package:flutter/material.dart';
import '../../domain/entities/map_station.dart';

class StationInfoPanel extends StatelessWidget {
  final MapStation station;
  final VoidCallback onClose;
  final VoidCallback? onViewForecast;
  final VoidCallback? onAddToFavorites;

  const StationInfoPanel({
    super.key,
    required this.station,
    required this.onClose,
    this.onViewForecast,
    this.onAddToFavorites,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 100,
      left: 16,
      right: 16,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      station.name ?? 'Station ${station.stationId}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (station.type != null) Text('Type: ${station.type}'),
              const SizedBox(height: 4),
              if (station.elevation != null)
                Text('Elevation: ${station.elevation!.toStringAsFixed(2)} m'),
              const SizedBox(height: 4),
              Text(
                'Coordinates: ${station.lat.toStringAsFixed(6)}, ${station.lon.toStringAsFixed(6)}',
              ),
              if (station.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  station.description!,
                  style: const TextStyle(fontSize: 14),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed:
                        onViewForecast ??
                        () {
                          // Default implementation navigates to forecast page
                          Navigator.pushNamed(
                            context,
                            '/forecast',
                            arguments: {
                              'reachId': station.stationId.toString(),
                              'stationName':
                                  station.name ??
                                  'Station ${station.stationId}',
                            },
                          );
                        },
                    icon: const Icon(Icons.analytics),
                    label: const Text('View Forecast'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed:
                        onAddToFavorites ??
                        () {
                          // Default implementation shows a snackbar
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Added to favorites'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                    icon: const Icon(Icons.favorite_border),
                    label: const Text('Favorite'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
