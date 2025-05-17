// lib/features/forecast/presentation/widgets/location_info_row.dart

import 'package:flutter/material.dart';
import '../../../../core/models/location_info.dart';
import 'map_overlay.dart';

class LocationInfoRow extends StatelessWidget {
  final LocationInfo? locationInfo;
  final double lat;
  final double lon;
  final String riverName;
  final VoidCallback? onRefresh;
  final bool isLoading;

  const LocationInfoRow({
    super.key,
    this.locationInfo,
    required this.lat,
    required this.lon,
    required this.riverName,
    this.onRefresh,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locationText =
        locationInfo != null
            ? locationInfo!.formattedLocation
            : 'Location unavailable';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Location information
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: theme.colorScheme.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'River Location',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    isLoading
                        ? _buildLoadingIndicator(theme)
                        : Text(
                          locationText,
                          style: theme.textTheme.bodyMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                  ],
                ),
              ),
            ),

            // Mini map preview that opens the map overlay when tapped
            GestureDetector(
              onTap: () {
                _showMapOverlay(context);
              },
              child: Container(
                width: 100,
                height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outline,
                    width: 1,
                  ),
                  image: const DecorationImage(
                    image: AssetImage('assets/img/mini-map.png'),
                    fit: BoxFit.contain,
                  ),
                ),
                child: Stack(
                  children: [
                    // "View map" text at the bottom
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        color: theme.colorScheme.surface.withOpacity(0.7),
                        child: Text(
                          'View map',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator(ThemeData theme) {
    return Row(
      children: [
        SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('Loading location...', style: theme.textTheme.bodySmall),
      ],
    );
  }

  void _showMapOverlay(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (context) => MapOverlay(
            lat: lat,
            lon: lon,
            locationInfo: locationInfo,
            riverName: riverName,
          ),
    );
  }
}
