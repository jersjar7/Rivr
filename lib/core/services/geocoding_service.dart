// lib/core/services/geocoding_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
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
    print("GeocodingService: Starting location lookup for $lat, $lon");

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
          print(
            'GeocodingService: Returning cached location for $lat, $lon: ${locationInfo.formattedLocation}',
          );
          return locationInfo;
        } else {
          print(
            'GeocodingService: Found cached data but it\'s stale - fetching fresh data',
          );
        }
      } else {
        print('GeocodingService: No cached data found for these coordinates');
      }
    } catch (e) {
      print('GeocodingService: Error retrieving from cache: $e');
      // Continue to fetch from API
    }

    // Check if we're online
    final isConnected = await _networkInfo.isConnected;
    if (!isConnected) {
      print('GeocodingService: Device is offline');
      // If offline, try to use cached data even if stale
      try {
        final cachedData = await _cacheService.get<Map<String, dynamic>>(
          cacheKey,
        );
        if (cachedData != null) {
          print('GeocodingService: Offline - using stale cached data');
          return LocationInfo.fromJson(cachedData);
        } else {
          print('GeocodingService: Offline - no cached data available');
        }
      } catch (e) {
        print(
          'GeocodingService: Error retrieving from cache while offline: $e',
        );
      }
      return null;
    }

    // Fetch from Mapbox Geocoding API
    try {
      // Get the Mapbox token from the API config
      final mapboxToken = ApiConfig.mapboxAccessToken;

      if (mapboxToken.isEmpty) {
        print('GeocodingService: Missing Mapbox token - check ApiConfig');
        return null;
      }

      print(
        'GeocodingService: Mapbox token length: ${mapboxToken.length} chars',
      );

      final url =
          'https://api.mapbox.com/geocoding/v5/mapbox.places/$lon,$lat.json?access_token=$mapboxToken&types=place,region';

      print(
        'GeocodingService: Sending request to Mapbox API: ${url.substring(0, url.indexOf('access_token=') + 13)}...',
      );

      final response = await _httpClient
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      print(
        'GeocodingService: Received response with status code: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Debug the response structure
        print(
          'GeocodingService: Response has features: ${data.containsKey('features')}',
        );
        if (data.containsKey('features') && data['features'] is List) {
          print(
            'GeocodingService: Found ${(data['features'] as List).length} features in response',
          );
        }

        // Extract location information from response
        if (data['features'] != null && (data['features'] as List).isNotEmpty) {
          final features = data['features'] as List;

          String? city;
          String? state;

          // Look for place (city) and region (state)
          for (var feature in features) {
            try {
              final placeType = feature['place_type'][0];
              print(
                'GeocodingService: Found feature of type: $placeType, text: ${feature['text']}',
              );

              if (placeType == 'place' && city == null) {
                city = feature['text'];
                print('GeocodingService: Found city: $city');
              } else if (placeType == 'region' && state == null) {
                state = feature['text'];
                print('GeocodingService: Found state: $state');
              }

              // Break once we have both
              if (city != null && state != null) break;
            } catch (e) {
              print('GeocodingService: Error processing feature: $e');
            }
          }

          // If we found location info, create and cache it
          if (city != null || state != null) {
            final locationInfo = LocationInfo(
              city: city ?? 'Unknown',
              state: state ?? 'Unknown',
              lat: lat,
              lon: lon,
            );

            print(
              'GeocodingService: Found location: ${locationInfo.formattedLocation}',
            );

            // Cache the data
            try {
              await _cacheService.set(
                cacheKey,
                locationInfo.toJson(),
                duration: const Duration(days: 90), // Cache for 90 days
              );
              print('GeocodingService: Successfully cached location data');
            } catch (e) {
              print('GeocodingService: Failed to cache location data: $e');
              // Continue anyway since we have the data
            }

            return locationInfo;
          } else {
            print(
              'GeocodingService: No city or state found in the response features',
            );
          }
        } else {
          print('GeocodingService: No features found in the response');
          if (data.containsKey('message')) {
            print('GeocodingService: API message: ${data['message']}');
          }
        }
      } else {
        print(
          'GeocodingService: API error (${response.statusCode}): ${response.body}',
        );
      }

      return null;
    } catch (e, stackTrace) {
      print('GeocodingService: Error fetching location data: $e');
      print('GeocodingService: Stack trace: $stackTrace');
      return null;
    }
  }
}
