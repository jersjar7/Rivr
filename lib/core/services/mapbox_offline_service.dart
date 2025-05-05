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

      // Create offline manager
      _offlineManager = await OfflineManager.create();

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
      // Create regional geometry (bounding box)
      final coordinates = [
        [minLon, minLat], // Southwest
        [maxLon, minLat], // Southeast
        [maxLon, maxLat], // Northeast
        [minLon, maxLat], // Northwest
        [minLon, minLat], // Close the polygon
      ];

      final geometry = Feature(
        id: 1,
        geometry: Geometry(
          type: GeometryType.POLYGON,
          coordinates: coordinates,
        ),
      );

      // Setup options for the tileset
      final tilesetDescriptors = [
        TilesetDescriptor(
          styleURI: styleUrl,
          zoomRange: TileZoomRange(
            minZoom: minZoom.toInt(),
            maxZoom: maxZoom.toInt(),
          ),
        ),
      ];

      // Create tileset options
      final tilesetOptions = TilesetOptions(
        tilesetDescriptors: tilesetDescriptors,
      );

      // Create region metadata
      final metadata = {
        'name': 'Region_${DateTime.now().millisecondsSinceEpoch}',
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Create download options
      final options = TileRegionLoadOptions(
        geometry: geometry,
        descriptors: tilesetDescriptors,
        metadata: metadata,
        acceptExpired: true,
      );

      // Generate a unique ID for the region
      final regionId = 'region_${DateTime.now().millisecondsSinceEpoch}';

      // Start the download
      final completer = Completer<void>();

      // Create progress observer
      final observer = OfflineRegionObserver(
        onStatusChanged: (status) {
          if (status.downloadState == OfflineRegionDownloadState.ACTIVE) {
            final progress =
                status.completedResourceCount /
                (status.completedResourceCount + status.requiredResourceCount);

            if (onProgress != null) {
              onProgress(progress);
            }
          } else if (status.downloadState ==
              OfflineRegionDownloadState.FINISHED) {
            completer.complete();
          } else if (status.downloadState == OfflineRegionDownloadState.ERROR) {
            completer.completeError(
              Exception('Download failed: ${status.error}'),
            );
          }
        },
        onErrorEvent: (error) {
          completer.completeError(Exception('Download error: $error'));
        },
      );

      // Load the region
      await _offlineManager!.createTileRegion(regionId, options, observer);

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
    final zoomLevels = maxZoom - minZoom + 1;

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

    final regions = await _offlineManager!.getAllTileRegions();

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
