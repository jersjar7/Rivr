// lib/core/utils/offline_debug_utils.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../services/offline_manager_service.dart';
import '../cache/services/cache_service.dart';

/// Helper class for debugging offline functionality
class OfflineDebugUtils {
  /// Output cache diagnostics to debug console
  static Future<void> logCacheDiagnostics(
    OfflineManagerService offlineManager,
  ) async {
    final cacheSize = await offlineManager.getCacheSizeInMb();

    print('==== OFFLINE CACHE DIAGNOSTICS ====');
    print('Cache size: $cacheSize MB');
    print('Cached stations: ${offlineManager.cachedStationCount}');
    print('Cached forecasts: ${offlineManager.cachedForecastCount}');
    print('Cached map tiles: ${offlineManager.cachedTileCount}');
    print('Offline mode enabled: ${offlineManager.offlineModeEnabled}');
    print('==================================');
  }

  /// Create a simple diagnostic file for debugging offline issues
  static Future<String> createDiagnosticFile(
    OfflineManagerService offlineManager,
  ) async {
    // Get app document directory
    final directory = await getApplicationDocumentsDirectory();
    final path = directory.path;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '$path/offline_diagnostics_$timestamp.txt';

    // Create file with diagnostic info
    final file = File(fileName);
    final sink = file.openWrite();

    // Write diagnostic data
    sink.writeln('RIVR APP OFFLINE DIAGNOSTICS');
    sink.writeln('Generated: ${DateTime.now().toIso8601String()}');
    sink.writeln('');
    sink.writeln('App State:');
    sink.writeln('Offline mode enabled: ${offlineManager.offlineModeEnabled}');
    sink.writeln(
      'Current download: ${offlineManager.isDownloading ? 'In progress' : 'None'}',
    );
    sink.writeln('');
    sink.writeln('Cache Statistics:');
    sink.writeln('Cache size: ${await offlineManager.getCacheSizeInMb()} MB');
    sink.writeln('Cached stations: ${offlineManager.cachedStationCount}');
    sink.writeln('Cached forecasts: ${offlineManager.cachedForecastCount}');
    sink.writeln('Cached map tiles: ${offlineManager.cachedTileCount}');

    await sink.flush();
    await sink.close();

    return fileName;
  }

  /// Show a debug overlay with offline status
  static Widget buildDebugOverlay(OfflineManagerService offlineManager) {
    return Positioned(
      bottom: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'OFFLINE DEBUG',
              style: TextStyle(
                color: Colors.red[300],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Mode: ${offlineManager.offlineModeEnabled ? "OFFLINE" : "ONLINE"}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            Text(
              'Cache: ${offlineManager.cacheSizeInMb} MB',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            if (offlineManager.isDownloading)
              Text(
                'Downloading: ${(offlineManager.downloadProgress * 100).toStringAsFixed(1)}%',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  /// Show a dialog with cache details
  static void showCacheDetailsDialog(
    BuildContext context,
    OfflineManagerService offlineManager,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text(
              'Offline Cache Details',
              style: TextStyle(fontSize: 16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow(
                  'Cache Size',
                  '${offlineManager.cacheSizeInMb} MB',
                ),
                _buildDetailRow(
                  'Cached Stations',
                  '${offlineManager.cachedStationCount}',
                ),
                _buildDetailRow(
                  'Cached Forecasts',
                  '${offlineManager.cachedForecastCount}',
                ),
                _buildDetailRow(
                  'Cached Map Tiles',
                  '${offlineManager.cachedTileCount}',
                ),
                _buildDetailRow(
                  'Offline Mode',
                  offlineManager.offlineModeEnabled ? "Enabled" : "Disabled",
                ),
                if (offlineManager.isDownloading)
                  _buildDetailRow(
                    'Download Progress',
                    '${(offlineManager.downloadProgress * 100).toStringAsFixed(1)}%',
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
              TextButton(
                onPressed: () async {
                  final fileName = await createDiagnosticFile(offlineManager);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Diagnostic file saved: $fileName'),
                      ),
                    );
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Save Diagnostic File'),
              ),
            ],
          ),
    );
  }

  /// Build a detail row for the dialog
  static Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  /// Toggle debugging mode for cache service
  static void toggleCacheDebugging(CacheService cacheService, bool enabled) {
    // This is a placeholder - you would need to implement a debug flag in your CacheService
    print('Cache debugging ${enabled ? 'enabled' : 'disabled'}');
  }
}
