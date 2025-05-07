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
  });
}
