// lib/features/map/domain/entities/search_result.dart

import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class SearchResult {
  final String name;
  final Point point;
  final String? address;

  SearchResult({required this.name, required this.point, this.address});
}
