// lib/features/map/presentation/widgets/stream_info_content.dart

import 'package:flutter/material.dart';
import '../../../../core/utils/location_utils.dart';

/// Widget for displaying stream information content
class StreamInfoContent extends StatelessWidget {
  final String streamName;
  final bool isCustomName;
  final Map<String, dynamic>? reachData;
  final Function(String, String) onViewForecast;
  final Function() onAddToFavorites;
  final String stationId;
  final double lat;
  final double lon;
  final double? elevation;
  final VoidCallback onClose;

  const StreamInfoContent({
    super.key,
    required this.streamName,
    required this.isCustomName,
    required this.reachData,
    required this.onViewForecast,
    required this.onAddToFavorites,
    required this.stationId,
    required this.lat,
    required this.lon,
    required this.onClose,
    this.elevation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    // Extract river class and difficulty information
    String? riverClass;
    String? difficulty;

    if (reachData != null) {
      if (reachData!.containsKey('class')) {
        riverClass = reachData!['class']?.toString();
      }

      if (reachData!.containsKey('difficulty')) {
        difficulty = reachData!['difficulty']?.toString();
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Station name with edit button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  streamName,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: colors.onSurfaceVariant),
                onPressed: onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),

          // Show custom name indicator if applicable
          if (isCustomName)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Custom Name',
                  style: TextStyle(
                    fontSize: 10,
                    color: colors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 8),

          // River classification if available
          if (riverClass != null || difficulty != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.water, size: 16, color: colors.primary),
                  const SizedBox(width: 4),
                  Text(
                    riverClass != null && difficulty != null
                        ? 'Class $riverClass - $difficulty'
                        : riverClass != null
                        ? 'Class $riverClass'
                        : difficulty != null
                        ? 'Difficulty: $difficulty'
                        : '',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          // Station details
          _buildDetailRow(context, Icons.pin_drop, 'Station ID: $stationId'),
          const SizedBox(height: 4),
          _buildDetailRow(
            context,
            Icons.location_on,
            LocationUtils.formatCoordinates(lat, lon),
          ),

          if (elevation != null) ...[
            const SizedBox(height: 4),
            _buildDetailRow(
              context,
              Icons.height,
              'Elevation: ${elevation!.toStringAsFixed(2)} m',
            ),
          ],

          // Additional stream info from API
          if (reachData != null &&
              reachData!.containsKey('description') &&
              reachData!['description'] != null) ...[
            const SizedBox(height: 8),
            _buildDetailRow(
              context,
              Icons.info_outline,
              reachData!['description'] as String,
              isMultiLine: true,
            ),
          ],

          // Show latitude and longitude from API if available
          if (reachData != null &&
              reachData!.containsKey('latitude') &&
              reachData!.containsKey('longitude')) ...[
            const SizedBox(height: 8),
            _buildDetailRow(
              context,
              Icons.place,
              'Coordinates: ${reachData!['latitude']}, ${reachData!['longitude']}',
            ),
          ],

          const SizedBox(height: 16),

          // Action buttons
          Padding(
            padding: const EdgeInsets.only(left: 2, right: 2),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment
                      .spaceBetween, // Keep this for spacing between the buttons
              children: [
                // Wrap the first button with Expanded
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onAddToFavorites,
                    icon: const Icon(Icons.add_circle_outlined, size: 25),
                    label: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: const Text(
                        'Add to \nMy Rivers',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.primary,
                      // You might want to add visualDensity or minimumSize if buttons look too big
                      // minimumSize: const Size.fromHeight(40), // Example
                    ),
                  ),
                ),
                const SizedBox(width: 8), // Spacer between buttons
                // Wrap the second button with Expanded
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => onViewForecast(stationId, streamName),
                    icon: const Icon(Icons.analytics, size: 25),
                    label: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: const Text(
                        'View \nForecast',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                      // You might want to add visualDensity or minimumSize if buttons look too big
                      // minimumSize: const Size.fromHeight(40), // Example
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String text, {
    bool isMultiLine = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment:
          isMultiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: colors.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: textTheme.bodyMedium?.copyWith(color: colors.onSurface),
            maxLines: isMultiLine ? 3 : 1,
            overflow: isMultiLine ? TextOverflow.ellipsis : TextOverflow.clip,
          ),
        ),
      ],
    );
  }
}

/// Widget for displaying error state in stream info panel
class StreamInfoErrorContent extends StatelessWidget {
  final String displayName;
  final bool isLoadingName;
  final String errorMessage;
  final String? errorRecovery;
  final bool isNetworkError;
  final String stationId;
  final double lat;
  final double lon;
  final double? elevation;
  final VoidCallback onRefresh;
  final VoidCallback onAddToFavorites;
  final Function(String, String) onViewForecast;
  final VoidCallback onClose;

  const StreamInfoErrorContent({
    super.key,
    required this.displayName,
    required this.isLoadingName,
    required this.errorMessage,
    this.errorRecovery,
    required this.isNetworkError,
    required this.stationId,
    required this.lat,
    required this.lon,
    this.elevation,
    required this.onRefresh,
    required this.onAddToFavorites,
    required this.onViewForecast,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    // Determine error colors based on error type
    final Color errorIconColor =
        isNetworkError ? colors.secondary : colors.error;
    final Color errorTextColor =
        isNetworkError ? colors.secondary : colors.error;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    if (isLoadingName)
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colors.primary,
                          ),
                        ),
                      ),
                    if (isLoadingName) const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        displayName,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: colors.onSurfaceVariant),
                onPressed: onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Icon(
            isNetworkError ? Icons.cloud_off : Icons.error_outline,
            color: errorIconColor,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage,
            style: textTheme.bodyMedium?.copyWith(
              color: errorTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (errorRecovery != null) ...[
            const SizedBox(height: 8),
            Text(
              errorRecovery!,
              style: textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
          if (isNetworkError) ...[
            const SizedBox(height: 8),
            Text(
              'Basic station information is still available below.',
              style: textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Basic station information
          _buildDetailRow(context, Icons.pin_drop, 'Station ID: $stationId'),
          const SizedBox(height: 4),
          _buildDetailRow(
            context,
            Icons.location_on,
            LocationUtils.formatCoordinates(lat, lon),
          ),

          if (elevation != null) ...[
            const SizedBox(height: 4),
            _buildDetailRow(
              context,
              Icons.height,
              'Elevation: ${elevation!.toStringAsFixed(2)} m',
            ),
          ],

          const SizedBox(height: 16),
          Center(
            child: OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: OutlinedButton.styleFrom(foregroundColor: colors.primary),
            ),
          ),

          // Action buttons - still available without reach data
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: onAddToFavorites,
                icon: const Icon(Icons.favorite_border),
                label: const Text('Add to Favorites'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.primary,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => onViewForecast(stationId, displayName),
                icon: const Icon(Icons.analytics),
                label: const Text('View Forecast'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String text, {
    bool isMultiLine = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment:
          isMultiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: colors.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: textTheme.bodyMedium?.copyWith(color: colors.onSurface),
            maxLines: isMultiLine ? 3 : 1,
            overflow: isMultiLine ? TextOverflow.ellipsis : TextOverflow.clip,
          ),
        ),
      ],
    );
  }
}
