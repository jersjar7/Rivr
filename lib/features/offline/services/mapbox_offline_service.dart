// lib/features/offline/services/mapbox_offline_service.dart

import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:rivr/features/offline/data/repositories/offline_storage_repository.dart';

class MapboxOfflineService {
  static final MapboxOfflineService _instance =
      MapboxOfflineService._internal();
  final OfflineStorageRepository _storage = OfflineStorageRepository();

  // Optional: Mapbox token
  String? _mapboxToken;

  factory MapboxOfflineService() {
    return _instance;
  }

  MapboxOfflineService._internal();

  /// Set Mapbox token
  void setMapboxToken(String token) {
    _mapboxToken = token;
  }

  /// Initialize the service and register necessary components
  Future<void> initialize() async {
    await _storage.initialize();
  }

  /// Download map region for offline use
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
    // Generate coordinate bounds
    final bounds = CoordinateBounds(
      southwest: Point(coordinates: Position(minLon, minLat)),
      northeast: Point(coordinates: Position(maxLon, maxLat)),
      infiniteBounds: false,
    );

    try {
      // Calculate all tile coordinates
      final allTiles = _calculateTilesForBounds(
        bounds,
        minZoom.round(),
        maxZoom.round(),
      );

      final totalTiles = allTiles.length;
      if (kDebugMode) {
        print('Downloading $totalTiles tiles for offline use');
      }

      int downloadedTiles = 0;

      // Download each tile and cache it
      for (final tile in allTiles) {
        // Generate a unique key for this tile
        final tileKey = _generateTileKey(styleUrl, tile.x, tile.y, tile.z);

        // Attempt to download the tile data
        final tileData = await _downloadMapboxTile(
          styleUrl,
          tile.x,
          tile.y,
          tile.z,
        );

        // If we successfully got the tile data, cache it
        if (tileData != null) {
          await _storage.cacheMapTile(tileKey, tileData);
        }

        // Update progress
        downloadedTiles++;
        final progress = downloadedTiles / totalTiles;
        onProgress?.call(progress);

        // Print progress every 10%
        if (kDebugMode && downloadedTiles % (totalTiles ~/ 10) == 0) {
          print('Downloaded ${(progress * 100).toStringAsFixed(1)}% of tiles');
        }
      }

      if (kDebugMode) {
        print('Finished downloading region for offline use');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error downloading region: $e');
      }
      rethrow;
    }
  }

  /// Get a cached tile for offline use
  Future<List<int>?> getCachedTile(String styleUrl, int x, int y, int z) async {
    final tileKey = _generateTileKey(styleUrl, x, y, z);
    return await _storage.getCachedMapTile(tileKey);
  }

  /// Download tile data from Mapbox
  Future<List<int>?> _downloadMapboxTile(
    String styleUrl,
    int x,
    int y,
    int z,
  ) async {
    try {
      // Construct the tile URL
      final tileUrl = _constructMapboxTileUrl(styleUrl, x, y, z);

      // Fetch the tile
      final response = await http.get(Uri.parse(tileUrl));

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        if (kDebugMode) {
          print('Failed to download tile: HTTP ${response.statusCode}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error downloading tile: $e');
      }
      return null;
    }
  }

  /// Construct a Mapbox tile URL
  String _constructMapboxTileUrl(String styleUrl, int x, int y, int z) {
    // Example: https://api.mapbox.com/v4/mapbox.satellite/{z}/{x}/{y}.png?access_token=YOUR_MAPBOX_ACCESS_TOKEN

    // Extract the style ID from the style URL
    // Note: This is a simplification; in practice you'd need to handle different style URL formats
    final styleId = styleUrl.split('/').last;

    // Construct the tile URL
    final tileUrl = 'https://api.mapbox.com/v4/$styleId/$z/$x/$y.png';

    // Add access token if available
    if (_mapboxToken != null) {
      return '$tileUrl?access_token=$_mapboxToken';
    }

    return tileUrl;
  }

  /// Generate a unique key for a map tile
  String _generateTileKey(String styleUrl, int x, int y, int z) {
    final input = '$styleUrl-$x-$y-$z';
    return md5.convert(utf8.encode(input)).toString();
  }

  // Calculate all tiles in a bounding box across zoom levels
  List<TileCoordinate> _calculateTilesForBounds(
    CoordinateBounds bounds,
    int minZoom,
    int maxZoom,
  ) {
    final tiles = <TileCoordinate>[];

    for (int z = minZoom; z <= maxZoom; z++) {
      // Calculate tile X,Y coordinates for the bounding box at this zoom level
      // Explicitly convert num to double
      final int minX = _longitudeToTileX(
        bounds.southwest.coordinates.lng.toDouble(),
        z,
      );
      final int maxX = _longitudeToTileX(
        bounds.northeast.coordinates.lng.toDouble(),
        z,
      );
      final int minY = _latitudeToTileY(
        bounds.northeast.coordinates.lat.toDouble(),
        z,
      );
      final int maxY = _latitudeToTileY(
        bounds.southwest.coordinates.lat.toDouble(),
        z,
      );

      // Add all tiles in this range to the list
      for (int x = minX; x <= maxX; x++) {
        for (int y = minY; y <= maxY; y++) {
          tiles.add(TileCoordinate(x: x, y: y, z: z));
        }
      }
    }

    return tiles;
  }

  // Convert longitude to tile X coordinate
  int _longitudeToTileX(double lon, int z) {
    return ((lon + 180.0) / 360.0 * (1 << z)).floor();
  }

  // Convert latitude to tile Y coordinate
  int _latitudeToTileY(double lat, int z) {
    final latRad = lat * (math.pi / 180.0);
    return ((1.0 -
                math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) /
            2.0 *
            (1 << z))
        .floor();
  }

  /// Register a tile overlay to intercept and use cached tiles
  Future<void> registerTileOverlay(MapboxMap mapboxMap) async {
    // This is a simplified concept - actual implementation would depend on
    // Mapbox Flutter SDK capabilities for intercepting tile requests
    // You would need to implement a custom tile source that checks
    // the cache before making network requests
  }

  /// Calculate estimated storage size for a region
  Future<int> calculateRegionSize({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
    required double minZoom,
    required double maxZoom,
  }) {
    // Generate coordinate bounds
    final bounds = CoordinateBounds(
      southwest: Point(coordinates: Position(minLon, minLat)),
      northeast: Point(coordinates: Position(maxLon, maxLat)),
      infiniteBounds: false,
    );

    // Calculate all tiles
    final tiles = _calculateTilesForBounds(
      bounds,
      minZoom.round(),
      maxZoom.round(),
    );

    // Estimate size (average tile size is around 15KB)
    final estimatedSizeBytes = tiles.length * 15 * 1024;

    return Future.value(estimatedSizeBytes);
  }
}

/// Helper class for tile coordinates
class TileCoordinate {
  final int x;
  final int y;
  final int z;

  TileCoordinate({required this.x, required this.y, required this.z});

  @override
  String toString() => 'Tile($x, $y, $z)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TileCoordinate &&
        other.x == x &&
        other.y == y &&
        other.z == z;
  }

  @override
  int get hashCode => Object.hash(x, y, z);
}
