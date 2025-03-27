// lib/features/favorites/presentation/providers/favorites_provider.dart

import 'package:flutter/material.dart';

// Simple favorite river model class
class FavoriteRiver {
  final int stationId;
  final String name;
  final double? latitude;
  final double? longitude;
  final double? lastFlow;
  final DateTime? lastUpdated;
  final String? flowCategory;
  final int position;

  FavoriteRiver({
    required this.stationId,
    required this.name,
    this.latitude,
    this.longitude,
    this.lastFlow,
    this.lastUpdated,
    this.flowCategory,
    required this.position,
  });
}

class FavoritesProvider with ChangeNotifier {
  List<FavoriteRiver> _favorites = [];
  bool _isLoading = false;
  bool _isError = false;
  String? _errorMessage;

  // Getters
  List<FavoriteRiver> get favorites => _favorites;
  bool get isLoading => _isLoading;
  bool get isError => _isError;
  String? get errorMessage => _errorMessage;

  // Initialize with some dummy data for development
  FavoritesProvider() {
    _initializeDummyData();
  }

  // Load favorites from repository (simulation for now)
  Future<void> loadFavorites() async {
    _isLoading = true;
    _isError = false;
    _errorMessage = null;
    notifyListeners();

    try {
      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));

      // In a real implementation, this would load from a repository
      // For now we're using the dummy data initialized in constructor

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _isError = true;
      _errorMessage = 'Failed to load favorites: ${e.toString()}';
      notifyListeners();
    }
  }

  // Refresh favorites data
  Future<void> refreshFavorites() async {
    await loadFavorites();
  }

  // Add a river to favorites
  Future<bool> addToFavorites(
    int stationId,
    String name,
    double? latitude,
    double? longitude,
  ) async {
    try {
      // Check if already in favorites
      if (_favorites.any((fav) => fav.stationId == stationId)) {
        _errorMessage = 'This river is already in your favorites';
        notifyListeners();
        return false;
      }

      // Create new favorite
      final newFavorite = FavoriteRiver(
        stationId: stationId,
        name: name,
        latitude: latitude,
        longitude: longitude,
        position: _favorites.length,
      );

      // Add to list
      _favorites.add(newFavorite);
      notifyListeners();

      // In a real implementation, you would save to repository

      return true;
    } catch (e) {
      _errorMessage = 'Failed to add favorite: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // Remove a river from favorites
  Future<bool> removeFromFavorites(int stationId) async {
    try {
      _favorites.removeWhere((fav) => fav.stationId == stationId);

      // Update positions after removal
      for (int i = 0; i < _favorites.length; i++) {
        final fav = _favorites[i];
        if (fav.position != i) {
          final updatedFav = FavoriteRiver(
            stationId: fav.stationId,
            name: fav.name,
            latitude: fav.latitude,
            longitude: fav.longitude,
            lastFlow: fav.lastFlow,
            lastUpdated: fav.lastUpdated,
            flowCategory: fav.flowCategory,
            position: i,
          );
          _favorites[i] = updatedFav;
        }
      }

      notifyListeners();

      // In a real implementation, you would save to repository

      return true;
    } catch (e) {
      _errorMessage = 'Failed to remove favorite: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // Reorder favorites
  void reorderFavorites(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final item = _favorites.removeAt(oldIndex);
    _favorites.insert(newIndex, item);

    // Update positions after reordering
    for (int i = 0; i < _favorites.length; i++) {
      final fav = _favorites[i];
      if (fav.position != i) {
        final updatedFav = FavoriteRiver(
          stationId: fav.stationId,
          name: fav.name,
          latitude: fav.latitude,
          longitude: fav.longitude,
          lastFlow: fav.lastFlow,
          lastUpdated: fav.lastUpdated,
          flowCategory: fav.flowCategory,
          position: i,
        );
        _favorites[i] = updatedFav;
      }
    }

    notifyListeners();

    // In a real implementation, you would save to repository
  }

  // Check if a station is in favorites
  bool isInFavorites(int stationId) {
    return _favorites.any((fav) => fav.stationId == stationId);
  }

  // Initialize with dummy data for development
  void _initializeDummyData() {
    _favorites = [
      FavoriteRiver(
        stationId: 12345,
        name: 'Hudson River',
        latitude: 42.65,
        longitude: -73.75,
        lastFlow: 3200.5,
        lastUpdated: DateTime.now().subtract(const Duration(hours: 1)),
        flowCategory: 'Normal',
        position: 0,
      ),
      FavoriteRiver(
        stationId: 23456,
        name: 'Colorado River',
        latitude: 38.95,
        longitude: -110.35,
        lastFlow: 5600.2,
        lastUpdated: DateTime.now().subtract(const Duration(hours: 2)),
        flowCategory: 'High',
        position: 1,
      ),
      FavoriteRiver(
        stationId: 34567,
        name: 'Mississippi River',
        latitude: 37.15,
        longitude: -89.55,
        lastFlow: 12500.8,
        lastUpdated: DateTime.now().subtract(const Duration(hours: 3)),
        flowCategory: 'Moderate',
        position: 2,
      ),
    ];
  }
}
