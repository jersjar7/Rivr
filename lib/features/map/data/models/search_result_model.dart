// lib/features/map/data/models/search_result_model.dart

import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../domain/entities/search_result.dart';

class SearchResultModel extends SearchResult {
  SearchResultModel({required super.name, required super.point, super.address});

  factory SearchResultModel.fromJson(Map<String, dynamic> json) {
    final coordinates = json['center'] as List;
    return SearchResultModel(
      name: json['text'] as String,
      address: json['place_name'] as String?,
      point: Point(
        coordinates: Position(
          coordinates[0].toDouble(),
          coordinates[1].toDouble(),
        ),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'coordinates': [point.coordinates.lng, point.coordinates.lat],
    };
  }
}
