// lib/features/favorites/presentation/pages/favorites_page.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:rivr/common/data/local/database_helper.dart';
import 'package:rivr/core/di/service_locator.dart';
import 'package:rivr/core/services/stream_name_service.dart';
import 'package:rivr/features/favorites/data/models/favorite_model.dart';
import 'package:rivr/features/favorites/presentation/widgets/favorites_drawer.dart';

import '../providers/favorites_provider.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../widgets/favorite_card.dart';
import '../../domain/entities/favorite.dart';
import '../widgets/edit_favorite_name_dialog.dart';

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

  // Add StreamNameService
  late StreamNameService _streamNameService;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Get StreamNameService instance
    _streamNameService = sl<StreamNameService>();

    // Initialize database - ensure columns exist
    _initializeDatabase();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFavorites();
    });
  }

  Future<void> _initializeDatabase() async {
    try {
      final databaseHelper = DatabaseHelper();
      await databaseHelper.ensureCustomImagePathColumn();
    } catch (e) {
      print('Error initializing database: $e');
    }
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
        print('Loading favorites for user: ${user.uid}');
        await favoritesProvider.loadFavorites(user.uid);

        // Log loaded favorites for debugging
        print('Loaded ${favoritesProvider.favorites.length} favorites');
        for (var fav in favoritesProvider.favorites) {
          print(
            '  - Favorite: ${fav.stationId}, imgNumber: ${fav.imgNumber}, lastUpdated: ${fav.lastUpdated}',
          );
        }
      }
    } catch (e) {
      print('Error loading favorites: $e');
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

  void _showEditOptions(Favorite favorite) {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Edit Name'),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditNameDialog(context, favorite);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Choose River Image'),
                  onTap: () {
                    Navigator.pop(context);
                    _showChangeImageDialog(favorite);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.add_photo_alternate),
                  title: const Text('Upload Custom Image'),
                  subtitle: const Text('Coming soon'),
                  enabled: false, // Disable until fully implemented
                  onTap: null,
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _updateFavoriteImage(Favorite favorite, int imgNumber) async {
    if (favorite.imgNumber == imgNumber) {
      return; // No change needed
    }

    setState(() {
      _isRefreshing = true;
    });

    try {
      // Access database directly to update image number
      final databaseHelper = DatabaseHelper();
      final db = await databaseHelper.database;

      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Update the database
      await db.update(
        DatabaseHelper.tableFavorites,
        {'imgNumber': imgNumber, 'lastUpdated': timestamp},
        where: 'userId = ? AND stationId = ?',
        whereArgs: [favorite.userId, favorite.stationId],
      );

      print(
        'DEBUG: Image updated in database - stationId: ${favorite.stationId}, imgNumber: $imgNumber, timestamp: $timestamp',
      );

      // Instead of reloading from database, directly update the favorites provider
      final favoritesProvider = Provider.of<FavoritesProvider>(
        context,
        listen: false,
      );

      // Find and update the favorite in the provider's list
      final index = favoritesProvider.favorites.indexWhere(
        (f) => f.stationId == favorite.stationId && f.userId == favorite.userId,
      );

      if (index >= 0) {
        final updatedFavorite = FavoriteModel(
          stationId: favorite.stationId,
          name: favorite.name,
          userId: favorite.userId,
          position: favorite.position,
          color: favorite.color,
          description: favorite.description,
          imgNumber: imgNumber, // Update image number
          lastUpdated: timestamp, // Update timestamp
          originalApiName: favorite.originalApiName,
          customImagePath: favorite.customImagePath,
          lat: favorite.lat,
          lon: favorite.lon,
          elevation: favorite.elevation,
          city: favorite.city,
          state: favorite.state,
        );

        // Update the provider's list directly
        favoritesProvider.updateFavoriteDirectly(index, updatedFavorite);

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('River image updated'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error updating favorite image: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update image: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  void _showChangeImageDialog(Favorite favorite) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    showDialog<int>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Select River Image',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),
              ),
              Divider(color: theme.dividerColor, height: 1),

              // Image grid
              Expanded(
                child: GridView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(12.0),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: 96,
                  itemBuilder: (ctx, idx) {
                    final imgNumber = idx + 1;
                    final isSelected = favorite.imgNumber == imgNumber;

                    return InkWell(
                      onTap: () => Navigator.pop(context, imgNumber),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color:
                                isSelected
                                    ? colors.primary
                                    : colors.onSurface.withValues(alpha: 0.12),
                            width: isSelected ? 3 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: Image.asset(
                            'assets/img/river_images/$imgNumber.webp',
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, st) {
                              return Container(
                                color: colors.surfaceContainerHighest,
                                child: Icon(
                                  Icons.broken_image,
                                  color: colors.onSurfaceVariant,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Actions
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.primary,
                      ),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        final random = math.Random();
                        final randomImg = random.nextInt(96) + 1;
                        Navigator.pop(context, randomImg);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.secondary,
                        foregroundColor: colors.onSecondary,
                      ),
                      child: const Text('Random'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ).then((selectedImgNumber) {
      if (selectedImgNumber != null) {
        _updateFavoriteImage(favorite, selectedImgNumber);
      }
    });
  }

  void _confirmDelete(Favorite favorite) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Remove Favorite'),
            content: Text(
              favorite.name.isEmpty
                  ? 'Remove this river from your favorites?'
                  : 'Remove ${favorite.name} from your favorites?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  final userId =
                      Provider.of<AuthProvider>(
                        context,
                        listen: false,
                      ).currentUser!.uid;
                  Provider.of<FavoritesProvider>(
                    context,
                    listen: false,
                  ).deleteFavorite(userId, favorite.stationId);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                child: const Text('Remove'),
              ),
            ],
          ),
    );
  }

  // Updated method to use our new dialog function and integrate with StreamNameService
  Future<void> _showEditNameDialog(BuildContext ctx, Favorite favorite) async {
    // Store a local reference to the context to avoid using a potentially stale context
    final currentContext = ctx;

    final favoritesProvider = Provider.of<FavoritesProvider>(
      currentContext,
      listen: false,
    );

    // Get the name information from StreamNameService
    String? originalApiName;
    try {
      final nameInfo = await _streamNameService.getNameInfo(favorite.stationId);
      originalApiName = nameInfo.originalApiName;
    } catch (e) {
      print("Error getting original API name from service: $e");
      // Fallback to the favorite's originalApiName
      originalApiName = favorite.originalApiName;
    }

    // Use our new dialog function
    final result = await showEditFavoriteNameDialog(
      currentContext,
      currentName: favorite.name,
      stationId: favorite.stationId,
      originalApiName: originalApiName,
    );

    // Check if the context is still valid before using it
    if (result != null && result != favorite.name) {
      try {
        // Update the name using the favorites provider
        final success = await favoritesProvider.updateFavoriteName(
          favorite.userId,
          favorite.stationId,
          result,
        );

        // Before showing snackbar, check if the context is still active
        if (currentContext.mounted) {
          ScaffoldMessenger.of(currentContext).showSnackBar(
            SnackBar(
              content: Text(
                success
                    ? 'River name updated successfully'
                    : 'Failed to update river name',
              ),
            ),
          );
        }

        // Force reload favorites to ensure UI updates correctly
        if (success) {
          await favoritesProvider.loadFavorites(favorite.userId);
        }
      } catch (e) {
        print('Error updating favorite name: $e');
        if (currentContext.mounted) {
          ScaffoldMessenger.of(currentContext).showSnackBar(
            SnackBar(content: Text('Error updating river name: $e')),
          );
        }
      }
    }
  }

  // Function to handle logout
  void _handleLogout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      await authProvider.logout();

      // Add this navigation after successful logout
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/auth',
          (route) => false, // Clear navigation stack
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error signing out: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: colors.surface,
      // Add drawer to Scaffold
      drawer: FavoritesDrawer(onLogout: _handleLogout),
      appBar: AppBar(
        title: Text(
          'My Rivers',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colors.onPrimary,
          ),
        ),
        elevation: 0,
        backgroundColor: colors.primary,
        actions: [
          IconButton(
            icon: AnimatedBuilder(
              animation: _animationController,
              builder:
                  (ctx, child) => Transform.rotate(
                    angle: _animationController.value * 2 * math.pi,
                    child: child,
                  ),
              child: Icon(Icons.refresh, color: colors.onPrimary),
            ),
            onPressed:
                _isRefreshing
                    ? null
                    : () {
                      _animationController.forward(from: 0);
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
                color: colors.primary,
              ),
            );
          }

          if (status == FavoritesStatus.error) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: colors.error, size: 60),
                  const SizedBox(height: 16),
                  Text(
                    'Something went wrong',
                    style: textTheme.titleMedium?.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    favoritesProvider.errorMessage ??
                        'Could not load your favorites',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _loadFavorites,
                    icon: Icon(Icons.refresh, color: colors.onPrimary),
                    label: Text(
                      'Try Again',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.onPrimary,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
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
            color: colors.primary,
            onRefresh: _loadFavorites,
            child: ReorderableListView.builder(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 105, // ← add whatever height you like here
              ),
              itemCount: favorites.length,
              onReorder: favoritesProvider.reorderFavorites,
              itemBuilder: (context, index) {
                final favorite = favorites[index];
                return Slidable(
                  key: Key('favorite_${favorite.stationId}'),
                  startActionPane: ActionPane(
                    motion: const DrawerMotion(),
                    extentRatio: 0.5,
                    children: [
                      SlidableAction(
                        onPressed: (_) => _showEditOptions(favorite),
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                        icon: Icons.more_horiz,
                        label: 'Options',
                      ),
                    ],
                  ),
                  endActionPane: ActionPane(
                    motion: const DrawerMotion(),
                    extentRatio: 0.25,
                    children: [
                      SlidableAction(
                        onPressed: (_) => _confirmDelete(favorite),
                        backgroundColor: colors.error,
                        foregroundColor: colors.onError,
                        icon: Icons.delete,
                        label: 'Delete',
                      ),
                    ],
                  ),
                  child: FavoriteCard(
                    // Add a key with the lastUpdated timestamp to force rebuild when it changes
                    key: Key(
                      'favorite_card_${favorite.stationId}_${favorite.lastUpdated}',
                    ),
                    favorite: favorite,
                    onTap:
                        () => _navigateToForecast(
                          favorite.stationId,
                          favorite.name,
                        ),
                    onDelete: () => _confirmDelete(favorite),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToMap,
        backgroundColor: colors.secondary,
        icon: Icon(Icons.add, color: colors.onSecondary),
        label: Text(
          'Add River',
          style: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colors.onSecondary,
          ),
        ),
      ),
    );
  }
}
