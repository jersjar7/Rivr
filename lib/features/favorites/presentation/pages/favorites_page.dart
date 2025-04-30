// lib/features/favorites/presentation/pages/favorites_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/favorites_provider.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../widgets/favorite_card.dart';

class FavoritesPage extends StatefulWidget {
  final double lat;
  final double lon;

  const FavoritesPage({super.key, this.lat = 0.0, this.lon = 0.0});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage>
    with SingleTickerProviderStateMixin {
  bool _isRefreshing = false;
  late AnimationController _animationController;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Use post-frame callback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFavorites();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    if (!mounted) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final favoritesProvider = Provider.of<FavoritesProvider>(
        context,
        listen: false,
      );

      final user = authProvider.currentUser;
      if (user != null) {
        await favoritesProvider.loadFavorites(user.uid);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
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
          // When a station is added to favorites from map, reload the favorites list
          _loadFavorites();
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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'My Rivers',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: AppColors.primaryColor,
        actions: [
          IconButton(
            icon: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _animationController.value * 2.0 * 3.14,
                  child: child,
                );
              },
              child: const Icon(Icons.refresh),
            ),
            onPressed:
                _isRefreshing
                    ? null
                    : () {
                      _animationController.forward(from: 0.0);
                      _loadFavorites();
                    },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Consumer<FavoritesProvider>(
        builder: (context, favoritesProvider, child) {
          final status = favoritesProvider.status;
          final favorites = favoritesProvider.favorites;

          if (status == FavoritesStatus.loading && !_isRefreshing) {
            return Center(
              child: LoadingIndicator(
                message: 'Loading your favorite rivers...',
                color: AppColors.primaryColor,
              ),
            );
          }

          if (status == FavoritesStatus.error) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red[300], size: 60),
                  const SizedBox(height: 16),
                  Text(
                    'Something went wrong',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    favoritesProvider.errorMessage ??
                        'Could not load your favorites',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _loadFavorites,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          if (favorites.isEmpty) {
            return EmptyFavoritesView(onExploreMap: _navigateToMap);
          }

          return RefreshIndicator(
            key: _refreshIndicatorKey,
            color: AppColors.primaryColor,
            onRefresh: _loadFavorites,
            child: ReorderableListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: favorites.length,
              onReorder: favoritesProvider.reorderFavorites,
              itemBuilder: (context, index) {
                final favorite = favorites[index];

                return FavoriteCard(
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
                      // Show a snackbar with undo option
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${favorite.name} removed'),
                          action: SnackBarAction(
                            label: 'UNDO',
                            onPressed: () {
                              // Re-add the favorite
                              favoritesProvider.addNewFavorite(favorite);
                            },
                          ),
                          duration: const Duration(seconds: 3),
                        ),
                      );

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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToMap,
        backgroundColor: AppColors.secondaryColor,
        icon: const Icon(Icons.add),
        label: const Text(
          'Add River',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 4,
      ),
    );
  }
}
