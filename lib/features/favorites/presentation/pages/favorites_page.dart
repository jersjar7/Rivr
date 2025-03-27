// lib/features/favorites/presentation/pages/favorites_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rivr/core/widgets/empty_state.dart';
import 'package:rivr/core/widgets/loading_indicator.dart';
import 'package:rivr/features/favorites/presentation/providers/favorites_provider.dart';
import 'package:rivr/features/favorites/presentation/widgets/favorite_list_item.dart';

class FavoritesPage extends StatefulWidget {
  final double lat;
  final double lon;

  const FavoritesPage({super.key, this.lat = 0.0, this.lon = 0.0});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final favoritesProvider = Provider.of<FavoritesProvider>(
      context,
      listen: false,
    );

    setState(() {
      _isLoading = true;
    });

    await favoritesProvider.loadFavorites();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshFavorites() async {
    final favoritesProvider = Provider.of<FavoritesProvider>(
      context,
      listen: false,
    );

    await favoritesProvider.refreshFavorites();
  }

  void _navigateToMap() {
    Navigator.of(
      context,
    ).pushNamed('/map', arguments: {'lat': widget.lat, 'lon': widget.lon});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Rivers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map),
            onPressed: _navigateToMap,
            tooltip: 'Explore Map',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshFavorites,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const LoadingIndicator(
              message: 'Loading your favorite rivers...',
              withBackground: true,
            ),
            const SizedBox(height: 40),
            // Add skeleton loading for favorite items
            ...List.generate(3, (index) => _buildSkeletonFavoriteItem()),
          ],
        ),
      );
    }

    return Consumer<FavoritesProvider>(
      builder: (context, provider, child) {
        final favorites = provider.favorites;

        if (provider.isError) {
          return ErrorStateView(
            title: 'Could not load favorites',
            message:
                provider.errorMessage ??
                'An error occurred while loading your favorites',
            onRetry: _refreshFavorites,
          );
        }

        if (favorites.isEmpty) {
          return EmptyFavoritesView(onExploreMap: _navigateToMap);
        }

        return RefreshIndicator(
          onRefresh: _refreshFavorites,
          child: ListView.builder(
            itemCount: favorites.length,
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            itemBuilder: (context, index) {
              return FavoriteListItem(
                favorite: favorites[index],
                onTap: () {
                  // Navigate to forecast page
                  Navigator.of(context).pushNamed(
                    '/forecast',
                    arguments: {
                      'reachId': favorites[index].stationId.toString(),
                      'stationName': favorites[index].name,
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSkeletonFavoriteItem() {
    return ShimmerLoading(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(16.0),
          height: 100,
          child: Row(
            children: [
              const SkeletonLoadingBox(
                width: 60,
                height: 60,
                borderRadius: BorderRadius.all(Radius.circular(30)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SkeletonLoadingBox(width: 120, height: 20),
                    const SizedBox(height: 8),
                    const SkeletonLoadingBox(width: 80, height: 16),
                    const SizedBox(height: 8),
                    const SkeletonLoadingBox(width: 100, height: 16),
                  ],
                ),
              ),
              const SkeletonLoadingBox(width: 60, height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
