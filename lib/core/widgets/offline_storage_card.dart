// lib/core/widgets/offline_storage_card.dart

import 'package:flutter/material.dart';

class OfflineStorageCard extends StatelessWidget {
  final int cachedStationCount;
  final int cachedForecastCount;
  final int cachedTileCount;
  final int cacheSizeInMb;
  final VoidCallback onClearCache;

  const OfflineStorageCard({
    super.key,
    required this.cachedStationCount,
    required this.cachedForecastCount,
    required this.cachedTileCount,
    required this.cacheSizeInMb,
    required this.onClearCache,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.storage, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Offline Storage',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onClearCache,
                  tooltip: 'Clear Cache',
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStorageStat(
              context,
              'Map Tiles',
              cachedTileCount,
              Icons.map,
              Colors.green,
            ),
            const Divider(),
            _buildStorageStat(
              context,
              'Stations',
              cachedStationCount,
              Icons.place,
              Colors.orange,
            ),
            const Divider(),
            _buildStorageStat(
              context,
              'Forecasts',
              cachedForecastCount,
              Icons.cloud,
              Colors.blue,
            ),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Storage Used',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '$cacheSizeInMb MB',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _calculateStoragePercentage(cacheSizeInMb),
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                _getStorageColor(cacheSizeInMb),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getStorageMessage(cacheSizeInMb),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageStat(
    BuildContext context,
    String title,
    int count,
    IconData icon,
    Color color,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        Text(
          count.toString(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  double _calculateStoragePercentage(int sizeInMb) {
    // Assuming a reasonable maximum cache size of 1GB (1000MB)
    const maxSizeInMb = 1000;
    return sizeInMb / maxSizeInMb;
  }

  Color _getStorageColor(int sizeInMb) {
    if (sizeInMb < 100) {
      return Colors.green;
    } else if (sizeInMb < 500) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  String _getStorageMessage(int sizeInMb) {
    if (sizeInMb < 50) {
      return 'Minimal storage used - you can download more areas';
    } else if (sizeInMb < 200) {
      return 'Moderate storage used - plenty of space available';
    } else if (sizeInMb < 500) {
      return 'Significant storage used - consider clearing unused areas';
    } else {
      return 'Large amount of storage used - recommend clearing some cache';
    }
  }
}
