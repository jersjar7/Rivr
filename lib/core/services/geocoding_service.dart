// lib/core/services/geocoding_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../cache/services/cache_service.dart';
import '../network/network_info.dart';
import '../models/location_info.dart';
import '../config/api_config.dart';

class GeocodingService {
  final http.Client _httpClient;
  final CacheService _cacheService;
  final NetworkInfo _networkInfo;

  // Constructor with required dependencies
  GeocodingService({
    required http.Client httpClient,
    required CacheService cacheService,
    required NetworkInfo networkInfo,
  }) : _httpClient = httpClient,
       _cacheService = cacheService,
       _networkInfo = networkInfo;

  /// Get location information (city, state) for a set of coordinates
  Future<LocationInfo?> getLocationInfo(double lat, double lon) async {
    // Generate a cache key based on coordinates (rounded to reduce cache fragmentation)
    final cacheKey =
        'location_${lat.toStringAsFixed(4)}_${lon.toStringAsFixed(4)}';

    // Try to get from cache first
    try {
      final cachedData = await _cacheService.get<Map<String, dynamic>>(
        cacheKey,
      );
      if (cachedData != null) {
        final locationInfo = LocationInfo.fromJson(cachedData);

        // Return cached data if not stale
        if (!locationInfo.isStale()) {
          if (kDebugMode) {
            print('GeocodingService: Returning cached location for $lat, $lon');
          }
          return locationInfo;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('GeocodingService: Error retrieving from cache: $e');
      }
      // Continue to fetch from API
    }

    // Check if we're online
    final isConnected = await _networkInfo.isConnected;
    if (!isConnected) {
      // If offline, try to use cached data even if stale
      try {
        final cachedData = await _cacheService.get<Map<String, dynamic>>(
          cacheKey,
        );
        if (cachedData != null) {
          if (kDebugMode) {
            print('GeocodingService: Offline - using stale cached data');
          }
          return LocationInfo.fromJson(cachedData);
        }
      } catch (e) {
        if (kDebugMode) {
          print(
            'GeocodingService: Error retrieving from cache while offline: $e',
          );
        }
      }
      return null;
    }

    // Fetch from Mapbox Geocoding API
    try {
      // Get the Mapbox token from the API config
      final mapboxToken = ApiConfig.mapboxAccessToken;

      if (mapboxToken.isEmpty) {
        if (kDebugMode) {
          print('GeocodingService: Missing Mapbox token');
        }
        return null;
      }

      final url =
          'https://api.mapbox.com/geocoding/v5/mapbox.places/$lon,$lat.json?access_token=$mapboxToken&types=place,region';

      if (kDebugMode) {
        print('GeocodingService: Fetching location for $lat, $lon');
      }

      final response = await _httpClient
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Extract location information from response
        if (data['features'] != null && (data['features'] as List).isNotEmpty) {
          final features = data['features'] as List;

          String? city;
          String? state;

          // Look for place (city) and region (state)
          for (var feature in features) {
            final placeType = feature['place_type'][0];
            if (placeType == 'place' && city == null) {
              city = feature['text'];
            } else if (placeType == 'region' && state == null) {
              state = feature['text'];
            }

            // Break once we have both
            if (city != null && state != null) break;
          }

          // If we found location info, create and cache it
          if (city != null || state != null) {
            final locationInfo = LocationInfo(
              city: city ?? 'Unknown',
              state: state ?? 'Unknown',
              lat: lat,
              lon: lon,
            );

            if (kDebugMode) {
              print(
                'GeocodingService: Found location: ${locationInfo.formattedLocation}',
              );
            }

            // Cache the data
            await _cacheService.set(
              cacheKey,
              locationInfo.toJson(),
              duration: const Duration(days: 90), // Cache for 90 days
            );

            return locationInfo;
          }
        }

        if (kDebugMode) {
          print('GeocodingService: No location data found in response');
        }
      } else {
        if (kDebugMode) {
          print(
            'GeocodingService: API error (${response.statusCode}): ${response.body}',
          );
        }
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('GeocodingService: Error fetching location data: $e');
      }
      return null;
    }
  }
}
