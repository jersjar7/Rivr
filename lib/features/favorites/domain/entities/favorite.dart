// lib/features/favorites/domain/entities/favorite.dart

class Favorite {
  final String stationId;
  final String name;
  final String userId;
  final int position;
  final String? color;
  final String? description;
  final int? imgNumber;
  final int? lastUpdated;
  final String? originalApiName;
  final String? customImagePath;
  // Location properties
  final double? lat;
  final double? lon;
  final double? elevation;
  // Add city and state to the model
  final String? city;
  final String? state;

  const Favorite({
    required this.stationId,
    required this.name,
    required this.userId,
    required this.position,
    this.color,
    this.description,
    this.imgNumber,
    this.lastUpdated,
    this.originalApiName,
    this.customImagePath,
    // Location properties
    this.lat,
    this.lon,
    this.elevation,
    // New location text properties
    this.city,
    this.state,
  });
}
