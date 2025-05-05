// lib/core/services/mapbox_offline_service.dart

import 'dart:async';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter/foundation.dart';
import '../storage/secure_storage.dart';
import '../constants/map_constants.dart';

/// Service for managing Mapbox offline maps
class MapboxOfflineService {
  OfflineManager? _offlineManager;
  bool _initialized = false;

  /// Initialize the offline manager
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Get Mapbox access token
      final accessToken = MapConstants.accessToken;

      // Create offline manager - updated for current SDK
      _offlineManager = await OfflineManager.getInstance();

      _initialized = true;
    } catch (e) {
      print('Error initializing MapboxOfflineService: $e');
      rethrow;
    }
  }

  /// Download a region for offline use
  Future<void> downloadRegion({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
    required double minZoom,
    required double maxZoom,
    required String styleUrl,
    Function(double)? onProgress,
  }) async {
    if (!_initialized) await initialize();

    if (_offlineManager == null) {
      throw Exception('Offline manager not initialized');
    }

    try {
      // Create regional geometry (bounding box) - Updated for current SDK
      final coordinates = [
        [minLon, minLat], // Southwest
        [maxLon, minLat], // Southeast
        [maxLon, maxLat], // Northeast
        [minLon, maxLat], // Northwest
        [minLon, minLat], // Close the polygon
      ];

      // Create a geometry object from coordinates
      final geometry = {
        "type": "Polygon",
        "coordinates": [coordinates],
      };

      // Setup options for the tileset descriptors
      final descriptorsOptions = [
        TilesetDescriptorOptions(
          styleURI: styleUrl,
          zoomRange: TileZoomRange(min: minZoom.toInt(), max: maxZoom.toInt()),
        ),
      ];

      // Create region metadata
      final metadata = {
        'name': 'Region_${DateTime.now().millisecondsSinceEpoch}',
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Create download options using the updated API
      final options = TileRegionLoadOptions(
        geometry: geometry,
        descriptorsOptions: descriptorsOptions,
        metadata: metadata,
        acceptExpired: true,
        // Required parameter for current SDK
        networkRestriction: NetworkRestriction.NONE,
      );

      // Generate a unique ID for the region
      final regionId = 'region_${DateTime.now().millisecondsSinceEpoch}';

      // Start the download
      final completer = Completer<void>();

      // Create progress observer with the updated API
      final observer = TileRegionLoadProgressCallback(
        onEvent: (TileRegionLoadProgress progress) {
          if (progress.completedResourceCount > 0) {
            final progressValue =
                progress.completedResourceCount /
                (progress.completedResourceCount +
                    progress.requiredResourceCount);

            if (onProgress != null) {
              onProgress(progressValue);
            }

            if (progress.completedResourceCount >=
                progress.requiredResourceCount) {
              completer.complete();
            }
          }
        },
        onError: (Exception error) {
          completer.completeError(Exception('Download error: $error'));
        },
      );

      // Load the region with the updated API
      await _offlineManager!.loadTileRegion(regionId, options, observer);

      // Wait for download to complete
      await completer.future;
    } catch (e) {
      print('Error downloading region: $e');
      rethrow;
    }
  }

  /// Calculate the estimated size of a download
  Future<int> calculateRegionSize({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
    required double minZoom,
    required double maxZoom,
  }) async {
    if (!_initialized) await initialize();

    if (_offlineManager == null) {
      throw Exception('Offline manager not initialized');
    }

    // This is an approximation since the API doesn't provide exact size calculations
    // Formula: area * zoom_levels * tile_size_factor

    // Calculate area in square degrees
    final area = (maxLat - minLat) * (maxLon - minLon);

    // Number of zoom levels
    final zoomLevels = maxZoom - minLon + 1;

    // Approximate tile size (in bytes) factor
    const tileSizeFactor = 15000; // Average tile size

    // Calculate tiles per zoom level (approximation)
    int totalTiles = 0;
    for (double zoom = minZoom; zoom <= maxZoom; zoom++) {
      final tilesPerSide = pow(2, zoom).toInt();
      final degPerTile = 360.0 / tilesPerSide;

      final tilesX = ((maxLon - minLon) / degPerTile).ceil();
      final tilesY = ((maxLat - minLat) / degPerTile).ceil();

      totalTiles += tilesX * tilesY;
    }

    // Estimate size in bytes
    final sizeBytes = totalTiles * tileSizeFactor;

    return sizeBytes;
  }

  /// List all downloaded regions
  Future<List<Map<String, dynamic>>> getDownloadedRegions() async {
    if (!_initialized) await initialize();

    if (_offlineManager == null) {
      throw Exception('Offline manager not initialized');
    }

    // Updated to use the current API
    final regions = await _offlineManager!.getTileRegions();

    return regions.map((region) {
      return {
        'id': region.id,
        'metadata': region.metadata,
        'completedResourceSize': region.completedResourceSize,
        'completedResourceCount': region.completedResourceCount,
        'requiredResourceCount': region.requiredResourceCount,
      };
    }).toList();
  }

  /// Delete a downloaded region
  Future<void> deleteRegion(String regionId) async {
    if (!_initialized) await initialize();

    if (_offlineManager == null) {
      throw Exception('Offline manager not initialized');
    }

    await _offlineManager!.removeTileRegion(regionId);
  }

  /// Get numerical power function (since dart:math pow returns dynamic)
  int pow(num base, num exponent) {
    return base.pow(exponent).toInt();
  }
}
