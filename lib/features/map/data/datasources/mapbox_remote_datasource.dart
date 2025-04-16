// lib/features/map/data/datasources/mapbox_remote_datasource.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../../core/constants/map_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../models/search_result_model.dart';

abstract class MapboxRemoteDataSource {
  Future<List<SearchResultModel>> searchLocation(String query);
  Future<String> getAccessToken();
}

class MapboxRemoteDataSourceImpl implements MapboxRemoteDataSource {
  final http.Client client;

  MapboxRemoteDataSourceImpl({required this.client});

  @override
  Future<List<SearchResultModel>> searchLocation(String query) async {
    if (query.isEmpty) return [];

    try {
      final accessToken = await getAccessToken();

      final url =
          '${MapConstants.mapboxSearchApiUrl}$query.json?'
          'access_token=$accessToken'
          '&limit=${MapConstants.searchResultLimit}';

      final response = await client.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List;

        return features.map<SearchResultModel>((feature) {
          return SearchResultModel.fromJson(feature);
        }).toList();
      } else {
        print('Error searching: ${response.statusCode}');
        throw ServerException(
          message: 'Failed to search locations: HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Exception during search: $e');
      if (e is ServerException) {
        rethrow;
      }
      throw ServerException(message: 'Error during location search: $e');
    }
  }

  @override
  Future<String> getAccessToken() async {
    try {
      final token = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
      if (token.isEmpty) {
        throw ServerException(
          message: 'Mapbox access token not found in environment variables',
        );
      }
      return token;
    } catch (e) {
      print('Error getting access token: $e');
      throw ServerException(message: 'Failed to get Mapbox access token: $e');
    }
  }
}
