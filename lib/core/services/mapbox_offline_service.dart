// lib/core/services/mapbox_offline_service.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Service for managing Mapbox offline maps
class MapboxOfflineService {
  late final TileStore _tileStore;
  bool _initialized = false;

  /// Initialize the tile store
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _tileStore = await TileStore.createDefault();
      _initialized = true;
    } catch (e) {
      print('Error initializing TileStore: $e');
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

    try {
      final regionId = 'region_${DateTime.now().millisecondsSinceEpoch}';

      final geometry = {
        "type": "Polygon",
        "coordinates": [
          [
            [minLon, minLat],
            [maxLon, minLat],
            [maxLon, maxLat],
            [minLon, maxLat],
            [minLon, minLat],
          ],
        ],
      };

      final descriptors = [
        TilesetDescriptorOptions(
          styleURI: styleUrl,
          minZoom: minZoom.toInt(),
          maxZoom: maxZoom.toInt(),
        ),
      ];

      final options = TileRegionLoadOptions(
        geometry: geometry,
        descriptorsOptions: descriptors,
        metadata: {
          'name': regionId,
          'timestamp': DateTime.now().toIso8601String(),
        },
        acceptExpired: true,
        networkRestriction: NetworkRestriction.NONE,
      );

      await _tileStore.loadTileRegion(regionId, options, (progress) {
        if (onProgress != null && progress.requiredResourceCount > 0) {
          final value =
              progress.completedResourceCount / progress.requiredResourceCount;
          onProgress(value);
        }
      });
    } catch (e) {
      print('Error downloading region: $e');
      rethrow;
    }
  }

  /// Estimate region size
  Future<int> calculateRegionSize({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
    required double minZoom,
    required double maxZoom,
  }) async {
    if (!_initialized) await initialize();

    const tileSizeFactor = 15000;
    int totalTiles = 0;
    for (double zoom = minZoom; zoom <= maxZoom; zoom++) {
      final tilesPerSide = math.pow(2, zoom).toInt();
      final degPerTile = 360.0 / tilesPerSide;
      final tilesX = ((maxLon - minLon) / degPerTile).ceil();
      final tilesY = ((maxLat - minLat) / degPerTile).ceil();
      totalTiles += tilesX * tilesY;
    }

    return totalTiles * tileSizeFactor;
  }

  /// List downloaded regions
  Future<List<Map<String, dynamic>>> getDownloadedRegions() async {
    if (!_initialized) await initialize();

    final regions = await _tileStore.allTileRegions();

    return Future.wait(
      regions.map((region) async {
        final metadata = await _tileStore.tileRegionMetadata(region.id);
        return {
          'id': region.id,
          'metadata': metadata,
          'completedResourceSize': region.completedResourceSize,
          'completedResourceCount': region.completedResourceCount,
          'requiredResourceCount': region.requiredResourceCount,
        };
      }).toList(),
    );
  }

  /// Delete a region
  Future<void> deleteRegion(String regionId) async {
    if (!_initialized) await initialize();

    await _tileStore.removeRegion(regionId);
  }
}
