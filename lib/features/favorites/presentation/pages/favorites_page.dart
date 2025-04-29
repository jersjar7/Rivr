// lib/features/favorites/presentation/pages/favorites_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/favorites_provider.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../core/widgets/empty_state.dart';
import '../widgets/favorite_item.dart';

class FavoritesPage extends StatefulWidget {
  final double lat;
  final double lon;

  const FavoritesPage({super.key, this.lat = 0.0, this.lon = 0.0});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final favoritesProvider = Provider.of<FavoritesProvider>(
      context,
      listen: false,
    );

    final user = authProvider.currentUser;
    if (user != null) {
      await favoritesProvider.loadFavorites(user.uid);
    }
  }

  void _navigateToMap() {
    Navigator.pushNamed(
      context,
      '/map',
      arguments: {
        'lat': widget.lat,
        'lon': widget.lon,
        'onStationAddedToFavorites': () {
          // When a station is added to favorites from map, this callback will run
          _loadFavorites(); // Reload the favorites list
        },
      },
    );
  }

  void _navigateToForecast(String reachId, String stationName) {
    Navigator.pushNamed(
      context,
      '/forecast',
      arguments: {'reachId': reachId, 'stationName': stationName},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Rivers'),
        actions: [
          // Optional: Add logout or settings action
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Handle settings navigation
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Consumer<FavoritesProvider>(
        builder: (context, favoritesProvider, child) {
          final status = favoritesProvider.status;
          final favorites = favoritesProvider.favorites;

          if (status == FavoritesStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (status == FavoritesStatus.error) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Error: ${favoritesProvider.errorMessage}',
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadFavorites,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (favorites.isEmpty) {
            return EmptyFavoritesView(onExploreMap: _navigateToMap);
          }

          return RefreshIndicator(
            onRefresh: _loadFavorites,
            child: ReorderableListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: favorites.length,
              onReorder: favoritesProvider.reorderFavorites,
              itemBuilder: (context, index) {
                final favorite = favorites[index];

                return FavoriteItem(
                  key: Key('favorite_${favorite.stationId}'),
                  favorite: favorite,
                  onTap:
                      () => _navigateToForecast(
                        favorite.stationId,
                        favorite.name,
                      ),
                  onDelete: () {
                    final authProvider = Provider.of<AuthProvider>(
                      context,
                      listen: false,
                    );
                    final user = authProvider.currentUser;
                    if (user != null) {
                      favoritesProvider.deleteFavorite(
                        user.uid,
                        favorite.stationId,
                      );
                    }
                  },
                );
              },
            ),
          );
        },
      ),
      // Add Floating Action Button to navigate to map
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToMap,
        tooltip: 'Add River',
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add),
      ),
    );
  }
}
