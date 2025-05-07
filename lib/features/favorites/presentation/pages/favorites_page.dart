// lib/features/favorites/presentation/pages/favorites_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:rivr/features/favorites/services/favorite_image_service.dart';

import '../providers/favorites_provider.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/theme/app_theme.dart';
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
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
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
                  title: const Text('Choose From Library'),
                  onTap: () {
                    Navigator.pop(context);
                    _showChangeImageDialog(favorite);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.add_photo_alternate),
                  title: const Text('Upload Custom Image'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndUploadImage(favorite);
                  },
                ),
              ],
            ),
          ),
    );
  }

  // Let's implement the image upload functionality
  Future<void> _pickAndUploadImage(Favorite favorite) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        return; // User canceled selection
      }

      // Show loading indicator
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Processing image...'),
          duration: Duration(seconds: 1),
        ),
      );

      // Read the file
      final bytes = await pickedFile.readAsBytes();

      // Save the image using our service
      final fileName = await FavoriteImageService.saveImage(
        userId: favorite.userId,
        stationId: favorite.stationId,
        bytes: bytes,
      );

      // Update the favorite with the custom image path
      final favoritesProvider = Provider.of<FavoritesProvider>(
        context,
        listen: false,
      );

      // We need to add a method to update the custom image path in FavoritesProvider
      final success = await favoritesProvider.updateFavoriteCustomImage(
        favorite.userId,
        favorite.stationId,
        fileName,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Custom image saved successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save custom image'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Handle errors
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateFavoriteImage(Favorite favorite, int imgNumber) async {
    if (favorite.imgNumber == imgNumber) {
      // No change needed
      return;
    }

    final favoritesProvider = Provider.of<FavoritesProvider>(
      context,
      listen: false,
    );

    final success = await favoritesProvider.updateFavoriteImage(
      favorite.userId,
      favorite.stationId,
      imgNumber,
    );

    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('River image updated')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update river image')),
      );
    }
  }

  void _showChangeImageDialog(Favorite favorite) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Select an Image',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: 30,
                  itemBuilder: (context, idx) {
                    final imgNumber = idx + 1;
                    // Highlight the currently selected image
                    final isSelected = favorite.imgNumber == imgNumber;

                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _updateFavoriteImage(favorite, imgNumber);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border:
                              isSelected
                                  ? Border.all(
                                    color: AppColors.primaryColor,
                                    width: 3,
                                  )
                                  : null,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.asset(
                            'assets/img/river_images/$imgNumber.jpeg',
                            fit: BoxFit.cover,
                            errorBuilder:
                                (_, __, ___) => const Icon(Icons.broken_image),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
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

  Future<void> _showEditNameDialog(BuildContext ctx, Favorite favorite) async {
    final result = await showDialog<String>(
      context: ctx,
      builder:
          (_) => EditFavoriteNameDialog(
            currentName: favorite.name,
            stationId: favorite.stationId,
            originalApiName: favorite.originalApiName,
          ),
    );
    if (result != null && result != favorite.name) {
      final success = await Provider.of<FavoritesProvider>(
        ctx,
        listen: false,
      ).updateFavoriteName(favorite.userId, favorite.stationId, result);
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'River name updated' : 'Failed to update name',
          ),
        ),
      );
    }
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
                return Slidable(
                  key: Key('favorite_${favorite.stationId}'),
                  startActionPane: ActionPane(
                    motion: const DrawerMotion(),
                    extentRatio: 0.5,
                    children: [
                      SlidableAction(
                        onPressed: (_) => _showEditOptions(favorite),
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: Colors.white,
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
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        icon: Icons.delete,
                        label: 'Delete',
                      ),
                    ],
                  ),
                  child: FavoriteCard(
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
