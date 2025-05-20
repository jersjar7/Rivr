// lib/core/widgets/empty_state.dart
import 'package:flutter/material.dart';

/// A reusable empty state widget with proper theming for both light and dark modes
class EmptyStateView extends StatelessWidget {
  final String title;
  final String? message;
  final IconData icon;
  final Widget? actionButton;
  final Color? iconColor; // Optional custom color
  final double iconSize;

  const EmptyStateView({
    super.key,
    required this.title,
    this.message,
    required this.icon,
    this.actionButton,
    this.iconColor, // No default, will use theme
    this.iconSize = 64,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final brightness = theme.brightness;
    final isDarkMode = brightness == Brightness.dark;

    // Default icon color based on theme if none provided
    final effectiveIconColor = iconColor ?? colors.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: iconSize, color: effectiveIconColor),

            const SizedBox(height: 24),

            // Title text with proper theme styling
            Text(
              title,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                // Ensure high contrast in dark mode
                color: isDarkMode ? Colors.white : colors.onSurface,
              ),
              textAlign: TextAlign.center,
            ),

            // Optional message with proper theme styling
            if (message != null) ...[
              const SizedBox(height: 12),
              Text(
                message!,
                style: textTheme.bodyMedium?.copyWith(
                  // Slightly dimmed in both modes but readable
                  color:
                      isDarkMode
                          ? Colors.white.withValues(alpha: 0.7)
                          : colors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

/// Specific implementation for no favorites
class EmptyFavoritesView extends StatelessWidget {
  final VoidCallback? onExploreMap;

  const EmptyFavoritesView({super.key, this.onExploreMap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final brightness = theme.brightness;
    final isDarkMode = brightness == Brightness.dark;

    return EmptyStateView(
      title: 'No Favorite Rivers Yet',
      message:
          'Add your favorite rivers to track their flow conditions and get forecasts at a glance.',
      icon: Icons.favorite_border,
      // Use appropriate color based on mode
      iconColor: isDarkMode ? colors.primary : colors.primaryContainer,
      actionButton:
          onExploreMap != null
              ? ElevatedButton.icon(
                onPressed: onExploreMap,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Explore Map'),
                style: ElevatedButton.styleFrom(
                  // Use appropriate colors based on mode
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              )
              : null,
    );
  }
}

/// Error state view
class ErrorStateView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const ErrorStateView({
    super.key,
    this.title = 'Something Went Wrong',
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return EmptyStateView(
      title: title,
      message: message,
      icon: Icons.error_outline,
      // Use theme's error color
      iconColor: colors.error,
      actionButton:
          onRetry != null
              ? OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: OutlinedButton.styleFrom(
                  // Use theme's primary color
                  foregroundColor: colors.primary,
                  side: BorderSide(color: colors.primary),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              )
              : null,
    );
  }
}

/// No forecast data state
class NoForecastDataView extends StatelessWidget {
  final String stationName;
  final VoidCallback? onRefresh;

  const NoForecastDataView({
    super.key,
    required this.stationName,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return EmptyStateView(
      title: 'No Forecast Data Available',
      message:
          'We couldn\'t find forecast data for $stationName. This could be temporary or the station might not have forecast data.',
      icon: Icons.cloud_off,
      // Use theme's error color
      iconColor: colors.error,
      actionButton:
          onRefresh != null
              ? OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
                style: OutlinedButton.styleFrom(
                  // Use theme's primary color
                  foregroundColor: colors.primary,
                  side: BorderSide(color: colors.primary),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              )
              : null,
    );
  }
}

/// Network error state
class NetworkErrorView extends StatelessWidget {
  final VoidCallback? onRetry;
  final bool isPermanentlyOffline;

  const NetworkErrorView({
    super.key,
    this.onRetry,
    this.isPermanentlyOffline = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return EmptyStateView(
      title: 'Connection Issue',
      message:
          isPermanentlyOffline
              ? 'No internet connection detected. Check your network settings and try again.'
              : 'We\'re having trouble connecting to the server. This might be temporary.',
      icon: Icons.cloud_off,
      iconColor: colors.tertiary, // "call-out" accent
      actionButton:
          onRetry != null
              ? ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Connection'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              )
              : null,
    );
  }
}

/// No stations found state
class NoStationsFoundView extends StatelessWidget {
  final VoidCallback? onChangeLocation;

  const NoStationsFoundView({super.key, this.onChangeLocation});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return EmptyStateView(
      title: 'No Stations Found',
      message:
          'We couldn\'t find any river stations in this area. Try a different location or zoom out to see more.',
      icon: Icons.location_off,
      iconColor: colors.secondary, // secondary (sea green)
      actionButton:
          onChangeLocation != null
              ? OutlinedButton.icon(
                onPressed: onChangeLocation,
                icon: const Icon(Icons.search),
                label: const Text('Search New Location'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.primary,
                  side: BorderSide(color: colors.primary),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              )
              : null,
    );
  }
}
