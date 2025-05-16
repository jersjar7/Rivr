// lib/core/models/location_info.dart

class LocationInfo {
  final String city;
  final String state;
  final double lat;
  final double lon;
  final DateTime lastUpdated;

  LocationInfo({
    required this.city,
    required this.state,
    required this.lat,
    required this.lon,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  factory LocationInfo.fromJson(Map<String, dynamic> json) {
    return LocationInfo(
      city: json['city'] as String,
      state: json['state'] as String,
      lat: json['lat'] as double,
      lon: json['lon'] as double,
      lastUpdated:
          json['lastUpdated'] != null
              ? DateTime.fromMillisecondsSinceEpoch(json['lastUpdated'] as int)
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'city': city,
      'state': state,
      'lat': lat,
      'lon': lon,
      'lastUpdated': lastUpdated.millisecondsSinceEpoch,
    };
  }

  bool isStale() {
    // Location data is valid for 90 days
    final now = DateTime.now();
    return now.difference(lastUpdated).inDays > 90;
  }

  String get formattedLocation => '$city, $state';
}
