// lib/features/offline/services/mapbox_tile_interceptor.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:crypto/crypto.dart';
import 'package:rivr/features/offline/data/repositories/offline_storage_repository.dart';
import 'dart:convert';

/// A service that intercepts Mapbox tile requests to serve cached tiles when offline.
///
/// This is based on a network observer pattern that lets us intercept network requests
/// and serve local cached data instead when operating in offline mode.
class MapboxTileInterceptor {
  static final MapboxTileInterceptor _instance =
      MapboxTileInterceptor._internal();
  final OfflineStorageRepository _storage = OfflineStorageRepository();

  bool _interceptorActive = false;
  String? _currentStyleUrl;

  // Controller for network requests
  StreamController<MapTileRequest>? _requestController;
  StreamSubscription<MapTileRequest>? _requestSubscription;

  factory MapboxTileInterceptor() {
    return _instance;
  }

  MapboxTileInterceptor._internal();

  /// Initialize the interceptor
  Future<void> initialize() async {
    await _storage.initialize();
  }

  /// Register the interceptor with a Mapbox map instance
  ///
  /// Note: This approach is conceptual - the actual implementation would depend on
  /// the Mapbox SDK's capabilities for intercepting network requests.
  Future<void> registerWith(MapboxMap mapboxMap, String styleUrl) async {
    if (_interceptorActive) {
      // Already active, update style URL if needed
      _currentStyleUrl = styleUrl;
      return;
    }

    try {
      _currentStyleUrl = styleUrl;

      // This part is conceptual - in a real implementation, we would:
      //
      // 1. Set up a listener for tile requests before they are sent to the network
      // 2. Check if we have the tile in our cache
      // 3. Either return the cached tile or let the request proceed to the network

      // For demonstration purposes, we'll imagine a stream of tile requests
      _requestController = StreamController<MapTileRequest>.broadcast();

      _requestSubscription = _requestController!.stream.listen((request) async {
        if (kDebugMode) {
          print(
            'Intercepted tile request: ${request.x}, ${request.y}, ${request.z}',
          );
        }

        // Check if we have this tile in the cache
        final tileKey = _generateTileKey(
          _currentStyleUrl!,
          request.x,
          request.y,
          request.z,
        );
        final cachedTileData = await _storage.getCachedMapTile(tileKey);

        if (cachedTileData != null) {
          // We have the tile, serve it from cache
          if (kDebugMode) {
            print('Serving tile from cache: $tileKey');
          }

          // In a real implementation, we would pass the cached data back to the map
          request.respondWithData(cachedTileData);
        } else {
          // Let the request proceed to the network
          if (kDebugMode) {
            print('No cached tile found, allowing network request');
          }
          request.proceedWithNetworkRequest();
        }
      });

      _interceptorActive = true;

      if (kDebugMode) {
        print('Mapbox tile interceptor registered');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error registering tile interceptor: $e');
      }
    }
  }

  /// Unregister the interceptor
  void unregister() {
    if (!_interceptorActive) return;

    _requestSubscription?.cancel();
    _requestController?.close();

    _requestController = null;
    _requestSubscription = null;
    _interceptorActive = false;

    if (kDebugMode) {
      print('Mapbox tile interceptor unregistered');
    }
  }

  /// Generate a unique key for a map tile
  String _generateTileKey(String styleUrl, int x, int y, int z) {
    final input = '$styleUrl-$x-$y-$z';
    return md5.convert(utf8.encode(input)).toString();
  }

  /// Clean up resources
  void dispose() {
    unregister();
  }
}

/// Represents a tile request that can be intercepted
class MapTileRequest {
  final int x;
  final int y;
  final int z;
  final String styleUrl;

  MapTileRequest({
    required this.x,
    required this.y,
    required this.z,
    required this.styleUrl,
  });

  /// Respond with cached data (conceptual - implementation depends on SDK)
  void respondWithData(List<int> data) {
    // In a real implementation, this would deliver the tile data to the map
    if (kDebugMode) {
      print('Responding with cached data for tile: $x/$y/$z');
    }
  }

  /// Let the request proceed to the network (conceptual)
  void proceedWithNetworkRequest() {
    // In a real implementation, this would allow the normal network request
    if (kDebugMode) {
      print('Proceeding with network request for tile: $x/$y/$z');
    }
  }
}
