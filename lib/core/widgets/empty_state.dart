// lib/core/widgets/empty_state.dart
import 'package:flutter/material.dart';
import 'package:rivr/core/theme/app_theme.dart';

/// A reusable empty state widget
class EmptyStateView extends StatelessWidget {
  final String title;
  final String? message;
  final IconData icon;
  final Widget? actionButton;
  final Color iconColor;
  final double iconSize;

  const EmptyStateView({
    super.key,
    required this.title,
    this.message,
    required this.icon,
    this.actionButton,
    this.iconColor = Colors.grey,
    this.iconSize = 64,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: iconSize, color: iconColor),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 12),
              Text(
                message!,
                style: const TextStyle(fontSize: 16, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionButton != null) ...[
              const SizedBox(height: 24),
              actionButton!,
            ],
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
    return EmptyStateView(
      title: 'No Favorite Rivers Yet',
      message:
          'Add your favorite rivers to track their flow conditions easily.',
      icon: Icons.favorite_border,
      iconColor: Colors.blue.shade200,
      actionButton: ElevatedButton.icon(
        onPressed: onExploreMap,
        icon: const Icon(Icons.map),
        label: const Text('Explore Map'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
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
    return EmptyStateView(
      title: title,
      message: message,
      icon: Icons.error_outline,
      iconColor: Colors.red.shade400,
      actionButton:
          onRetry != null
              ? OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryColor,
                  side: BorderSide(color: AppColors.primaryColor),
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
    return EmptyStateView(
      title: 'No Forecast Data Available',
      message:
          'We couldn\'t find forecast data for $stationName. This could be temporary or the station might not have forecast data.',
      icon: Icons.cloud_off,
      iconColor: Colors.grey.shade400,
      actionButton:
          onRefresh != null
              ? OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryColor,
                  side: BorderSide(color: AppColors.primaryColor),
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
    return EmptyStateView(
      title: 'Connection Issue',
      message:
          isPermanentlyOffline
              ? 'No internet connection detected. Check your network settings and try again.'
              : 'We\'re having trouble connecting to the server. This might be temporary.',
      icon: Icons.cloud_off,
      iconColor: Colors.orange.shade400,
      actionButton:
          onRetry != null
              ? ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Connection'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
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
    return EmptyStateView(
      title: 'No Stations Found',
      message:
          'We couldn\'t find any river stations in this area. Try a different location or zoom out to see more.',
      icon: Icons.location_off,
      iconColor: Colors.indigo.shade200,
      actionButton:
          onChangeLocation != null
              ? OutlinedButton.icon(
                onPressed: onChangeLocation,
                icon: const Icon(Icons.search),
                label: const Text('Search New Location'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryColor,
                  side: BorderSide(color: AppColors.primaryColor),
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
