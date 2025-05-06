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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'stationId': stationId,
      'name': name,
      'userId': userId,
      'position': position,
      'color': color,
      'description': description,
      'imgNumber': imgNumber,
      'lastUpdated': lastUpdated ?? DateTime.now().millisecondsSinceEpoch,
      'originalApiName': originalApiName, // Added field
    };
  }
}
