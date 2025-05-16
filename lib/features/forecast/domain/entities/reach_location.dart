// lib/features/forecast/domain/entities/reach_location.dart

/// Model class for representing a reach/river location
class ReachLocation {
  final double lat;
  final double lon;
  final double? elevation;
  final String? city;
  final String? state;

  const ReachLocation({
    required this.lat,
    required this.lon,
    this.elevation,
    this.city,
    this.state,
  });

  factory ReachLocation.fromJson(Map<String, dynamic> json) {
    return ReachLocation(
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      elevation:
          json['elevation'] != null
              ? (json['elevation'] as num).toDouble()
              : null,
      city: json['city'] as String?,
      state: json['state'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lat': lat,
      'lon': lon,
      if (elevation != null) 'elevation': elevation,
      if (city != null) 'city': city,
      if (state != null) 'state': state,
    };
  }

  @override
  String toString() =>
      'ReachLocation(lat: $lat, lon: $lon, elevation: $elevation, city: $city, state: $state)';
}
