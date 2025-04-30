// lib/features/offline/presentation/pages/offline_manager_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/offline_manager_provider.dart';
import '../widgets/offline_storage_card.dart';
import '../widgets/download_region_card.dart';
import '../widgets/offline_status_indicator.dart';

class OfflineManagerPage extends StatefulWidget {
  const OfflineManagerPage({super.key});

  @override
  State<OfflineManagerPage> createState() => _OfflineManagerPageState();
}

class _OfflineManagerPageState extends State<OfflineManagerPage> {
  @override
  void initState() {
    super.initState();
    // Refresh cache stats when page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<OfflineManagerProvider>(
        context,
        listen: false,
      );
      provider.refreshCacheStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Mode'),
        actions: [
          Consumer<OfflineManagerProvider>(
            builder: (context, provider, child) {
              return Switch(
                value: provider.offlineModeEnabled,
                onChanged: provider.toggleOfflineMode,
                activeColor: Theme.of(context).primaryColor,
              );
            },
          ),
        ],
      ),
      body: Consumer<OfflineManagerProvider>(
        builder: (context, provider, child) {
          if (provider.status == OfflineStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.status == OfflineStatus.error) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    provider.errorMessage ?? 'An error occurred',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.clearError(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.refreshCacheStats(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Offline Mode Status Card
                OfflineStatusIndicator(
                  isEnabled: provider.offlineModeEnabled,
                  onToggle: provider.toggleOfflineMode,
                ),

                const SizedBox(height: 16),

                // Storage Usage Card
                OfflineStorageCard(
                  cachedStationCount: provider.cachedStationCount,
                  cachedForecastCount: provider.cachedForecastCount,
                  cachedTileCount: provider.cachedTileCount,
                  cacheSizeInMb: provider.cacheSizeInMb,
                  onClearCache: () => _showClearCacheDialog(context),
                ),

                const SizedBox(height: 16),

                // Download Region Card
                if (!provider.isDownloading)
                  DownloadRegionCard(
                    onDownloadCurrentRegion:
                        () => Navigator.pushNamed(
                          context,
                          '/offline/download-current-region',
                        ),
                    onDownloadFavoriteAreas:
                        () => Navigator.pushNamed(
                          context,
                          '/offline/download-favorites',
                        ),
                    onDownloadCustomArea:
                        () => Navigator.pushNamed(
                          context,
                          '/offline/download-custom-area',
                        ),
                  )
                else
                  _buildDownloadProgressCard(provider),

                const SizedBox(height: 16),

                // Tips and Help Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tips for Using Offline Mode',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '• Download your favorite river areas before heading out',
                        ),
                        const Text(
                          '• Enable offline mode when you\'re in areas with poor connectivity',
                        ),
                        const Text(
                          '• Cached data will automatically update when you\'re back online',
                        ),
                        const Text(
                          '• Clear cache periodically to save storage space',
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: OutlinedButton(
                            onPressed: () => _showOfflineHelpDialog(context),
                            child: const Text('Learn More'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDownloadProgressCard(OfflineManagerProvider provider) {
    String downloadTypeText = '';
    switch (provider.currentDownloadType) {
      case OfflineDownloadType.currentMapRegion:
        downloadTypeText = 'Current Map Region';
        break;
      case OfflineDownloadType.favoriteAreas:
        downloadTypeText = 'Favorite Areas';
        break;
      case OfflineDownloadType.customArea:
        downloadTypeText = 'Custom Area';
        break;
      default:
        downloadTypeText = 'Region';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.download_rounded, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Downloading $downloadTypeText',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (provider.currentDownloadName != null)
              Text(
                provider.currentDownloadName!,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: provider.downloadProgress,
              minHeight: 10,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(provider.downloadProgress * 100).toStringAsFixed(1)}% complete',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                onPressed: () => provider.cancelDownload(),
                icon: const Icon(Icons.cancel),
                label: const Text('Cancel Download'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Clear Offline Cache'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'What would you like to clear?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildClearCacheOption(
                  context,
                  'All cached data',
                  'Removes all offline data including map tiles, station information, and forecasts.',
                  'all',
                ),
                const SizedBox(height: 8),
                _buildClearCacheOption(
                  context,
                  'Map tiles only',
                  'Removes only cached map tiles (largest component of storage usage).',
                  'map_tiles',
                ),
                const SizedBox(height: 8),
                _buildClearCacheOption(
                  context,
                  'Forecast data only',
                  'Removes only cached weather forecasts.',
                  'forecasts',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }

  Widget _buildClearCacheOption(
    BuildContext context,
    String title,
    String description,
    String cacheType,
  ) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        _confirmClearCache(context, title, cacheType);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    description,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _confirmClearCache(
    BuildContext context,
    String title,
    String cacheType,
  ) {
    final provider = Provider.of<OfflineManagerProvider>(
      context,
      listen: false,
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Clear $title?'),
            content: const Text(
              'This action cannot be undone. You will need to download this data again to use it offline.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  if (cacheType == 'all') {
                    provider.clearAllCache();
                  } else {
                    provider.clearCacheByType(cacheType);
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$title cleared successfully')),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Clear'),
              ),
            ],
          ),
    );
  }

  void _showOfflineHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Using Offline Mode'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'What is saved offline?',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('• Map tiles: Visual map data for navigation'),
                  Text(
                    '• Station data: Basic information about river monitoring stations',
                  ),
                  Text(
                    '• Forecast data: The most recent forecasts you\'ve viewed',
                  ),
                  SizedBox(height: 16),
                  Text(
                    'How to prepare for offline use:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. Download regions you\'ll need before losing connectivity',
                  ),
                  Text(
                    '2. Browse station information and forecasts while online to cache them',
                  ),
                  Text(
                    '3. Enable offline mode when you\'re ready to use the app without internet',
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Limitations:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('• Forecasts and data will not update while offline'),
                  Text('• Some advanced features may be unavailable'),
                  Text('• Search functionality may be limited'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Got it'),
              ),
            ],
          ),
    );
  }
}
