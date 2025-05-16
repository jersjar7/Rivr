// lib/features/favorites/data/models/favorite_model.dart

import '../../domain/entities/favorite.dart';

class FavoriteModel extends Favorite {
  const FavoriteModel({
    required super.stationId,
    required super.name,
    required super.userId,
    required super.position,
    super.color,
    super.description,
    super.imgNumber,
    super.lastUpdated,
    super.originalApiName,
    super.customImagePath,
    // Location properties
    super.lat,
    super.lon,
    super.elevation,
    // Location text properties
    super.city,
    super.state,
  });

  factory FavoriteModel.fromMap(Map<String, dynamic> map) {
    return FavoriteModel(
      stationId: map['stationId'].toString(),
      name: map['name'],
      userId: map['userId'],
      position: map['position'],
      color: map['color'],
      description: map['description'],
      imgNumber: map['imgNumber'],
      lastUpdated: map['lastUpdated'],
      originalApiName: map['originalApiName'],
      customImagePath: map['customImagePath'],
      // Location properties
      lat: map['lat'] != null ? (map['lat'] as num).toDouble() : null,
      lon: map['lon'] != null ? (map['lon'] as num).toDouble() : null,
      elevation:
          map['elevation'] != null
              ? (map['elevation'] as num).toDouble()
              : null,
      // Location text properties
      city: map['city'],
      state: map['state'],
    );
  }

  Map<String, dynamic> toMap() {
    final map = {
      'stationId': stationId,
      'name': name,
      'userId': userId,
      'position': position,
      'color': color,
      'description': description,
      'imgNumber': imgNumber,
      'lastUpdated': lastUpdated ?? DateTime.now().millisecondsSinceEpoch,
      'originalApiName': originalApiName,
      'customImagePath': customImagePath,
      // Location properties
      'lat': lat,
      'lon': lon,
      'elevation': elevation,
      // Location text properties
      'city': city,
      'state': state,
    };

    print(
      'DEBUG: FavoriteModel.toMap(): city=${map['city']}, state=${map['state']}',
    );
    return map;
  }
}
