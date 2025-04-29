// lib/features/favorites/presentation/providers/favorites_provider.dart

import 'package:flutter/material.dart';
import '../../domain/entities/favorite.dart';
import '../../domain/usecases/add_favorite.dart';
import '../../domain/usecases/get_favorites.dart';
import '../../domain/usecases/is_favorite.dart';
import '../../domain/usecases/remove_favorite.dart';
import '../../domain/usecases/update_favorite_position.dart';

enum FavoritesStatus { initial, loading, loaded, error }

class FavoritesProvider with ChangeNotifier {
  // Use cases
  final GetFavorites getFavorites;
  final AddFavorite addFavorite;
  final RemoveFavorite removeFavorite;
  final UpdateFavoritePosition updateFavoritePosition;
  final IsFavorite isFavorite;

  // State
  FavoritesStatus _status = FavoritesStatus.initial;
  List<Favorite> _favorites = [];
  String? _errorMessage;

  // Getters
  FavoritesStatus get status => _status;
  List<Favorite> get favorites => _favorites;
  String? get errorMessage => _errorMessage;

  FavoritesProvider({
    required this.getFavorites,
    required this.addFavorite,
    required this.removeFavorite,
    required this.updateFavoritePosition,
    required this.isFavorite,
  });

  // Load favorites for user
  Future<void> loadFavorites(String userId) async {
    _status = FavoritesStatus.loading;
    notifyListeners();

    final result = await getFavorites(userId);

    result.fold(
      (failure) {
        _status = FavoritesStatus.error;
        _errorMessage = failure.message;
        notifyListeners();
      },
      (loadedFavorites) {
        _favorites = loadedFavorites;
        _status = FavoritesStatus.loaded;
        _errorMessage = null;
        notifyListeners();
      },
    );
  }

  // Add a new favorite
  Future<void> addNewFavorite(Favorite favorite) async {
    final result = await addFavorite(favorite);

    result.fold(
      (failure) {
        _errorMessage = failure.message;
        notifyListeners();
      },
      (_) {
        _favorites.add(favorite);
        notifyListeners();
      },
    );
  }

  // Remove a favorite
  Future<void> deleteFavorite(String userId, String stationId) async {
    final result = await removeFavorite(userId, stationId);

    result.fold(
      (failure) {
        _errorMessage = failure.message;
        notifyListeners();
      },
      (_) {
        _favorites.removeWhere(
          (favorite) =>
              favorite.stationId == stationId && favorite.userId == userId,
        );
        notifyListeners();
      },
    );
  }

  // Reorder favorites
  Future<void> reorderFavorites(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final favorite = _favorites.removeAt(oldIndex);
    _favorites.insert(newIndex, favorite);

    // Update positions in database
    for (int i = 0; i < _favorites.length; i++) {
      final fav = _favorites[i];
      await updateFavoritePosition(fav.userId, fav.stationId, i);
    }

    notifyListeners();
  }

  // Check if a station is favorited
  Future<bool> checkIsFavorite(String userId, String stationId) async {
    final result = await isFavorite(userId, stationId);

    return result.fold((failure) => false, (isFav) => isFav);
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
