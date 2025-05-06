// lib/core/widgets/offline_aware_station_info_panel.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/map/domain/entities/map_station.dart';
import '../utils/location_utils.dart';
import '../widgets/loading_indicator.dart';
import '../../common/data/remote/reach_service.dart';
import '../error/app_exception.dart';
import '../error/error_handler.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/favorites/presentation/providers/favorites_provider.dart';
import '../../features/favorites/domain/entities/favorite.dart';
import '../services/offline_manager_service.dart';

class OfflineAwareStationInfoPanel extends StatefulWidget {
  final MapStation station;
  final VoidCallback onClose;
  final Future<void> Function(MapStation)? onAddToFavorites;
  final Function(String, String)? onViewForecast;
  final Function? onNavigateToFavorites;

  const OfflineAwareStationInfoPanel({
    super.key,
    required this.station,
    required this.onClose,
    this.onAddToFavorites,
    this.onViewForecast,
    this.onNavigateToFavorites,
  });

  @override
  State<OfflineAwareStationInfoPanel> createState() =>
      _OfflineAwareStationInfoPanelState();
}

class _OfflineAwareStationInfoPanelState
    extends State<OfflineAwareStationInfoPanel> {
  bool _isLoading = true;
  bool _hasError = false;
  bool _isNetworkError = false;
  String _errorMessage = '';
  String? _errorRecovery;
  Map<String, dynamic>? _reachData;
  bool _usedOfflineData = false;

  // For note
  final TextEditingController _noteController = TextEditingController();
  String? _note;

  @override
  void initState() {
    super.initState();
    print(
      "OfflineAwareStationInfoPanel: initializing for station ID: ${widget.station.stationId}",
    );
    _fetchReachData();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _fetchReachData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _isNetworkError = false;
      _errorMessage = '';
      _errorRecovery = null;
      _usedOfflineData = false;
    });

    // Get the offline manager
    final offlineManager = Provider.of<OfflineManagerService>(
      context,
      listen: false,
    );

    // Check for cached data first
    final cachedData = await offlineManager.getCachedStation(
      widget.station.stationId,
    );

    if (cachedData != null && cachedData['apiData'] != null) {
      // We have cached data, use it
      if (!mounted) return;

      setState(() {
        _reachData = cachedData['apiData'];
        _isLoading = false;
        _usedOfflineData = true;
      });

      print("StationInfoPanel: Using cached data");
      return;
    }

    // No cached data, try to fetch from API
    try {
      print("Fetching reach data for station ID: ${widget.station.stationId}");
      final reachService = ReachService();
      final reachId = widget.station.stationId.toString();

      print("Making API request for reach ID: $reachId");
      final data = await reachService.fetchReach(reachId);
      print("API response received for reach ID $reachId");

      if (!mounted) return;

      // Cache the data for offline use
      offlineManager.cacheStation(widget.station, data);

      setState(() {
        _reachData = data;
        _isLoading = false;
      });

      print("StationInfoPanel: Data loaded successfully");
    } catch (e) {
      print("Error fetching reach data for ${widget.station.stationId}: $e");

      if (!mounted) return;

      // Use global error handler
      final exception = ErrorHandler.handleError(e);

      setState(() {
        _isLoading = false;
        _hasError = true;
        _isNetworkError = exception is NetworkException;
        _errorMessage = ErrorHandler.getUserFriendlyMessage(exception);
        _errorRecovery = ErrorHandler.getRecoverySuggestion(exception);
      });
    }
  }

  Future<void> _addToFavorites(MapStation station) async {
    // Show dialog to add a note first
    await _showAddNoteDialog();

    // After dialog is closed, proceed with adding to favorites
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final favoritesProvider = Provider.of<FavoritesProvider>(
      context,
      listen: false,
    );

    final user = authProvider.currentUser;
    if (user != null) {
      final favorite = Favorite(
        stationId: station.stationId.toString(),
        name: station.name ?? 'Station ${station.stationId}',
        userId: user.uid,
        position: 0, // This will be updated by the provider
        color: station.color,
        description:
            _note ??
            (_reachData != null && _reachData!.containsKey('description')
                ? _reachData!['description'] as String?
                : null),
        imgNumber:
            1, // Default image number, you can assign a random one if desired
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
      );

      await favoritesProvider.addNewFavorite(favorite);

      // Show confirmation snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${station.name ?? "Station"} to favorites'),
            duration: const Duration(
              seconds: 1,
            ), // Short duration since we're navigating away
          ),
        );

        // Close the info panel
        widget.onClose();

        // Navigate to favorites if callback provided
        if (widget.onNavigateToFavorites != null) {
          // Small delay to let the UI update
          await Future.delayed(const Duration(milliseconds: 300));
          widget.onNavigateToFavorites!();
        }
      }
    } else {
      // Handle case where user is not logged in
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to add favorites')),
        );
      }
    }
  }

  // Show dialog to add a note before adding to favorites
  Future<void> _showAddNoteDialog() {
    return showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add a Note (Optional)'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Add a personal note about this river:',
                  style: TextStyle(color: Colors.grey[700], fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    hintText: 'e.g., Great fishing spot, Class III rapids...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  maxLength: 200,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  // Cancel without setting note
                  Navigator.of(context).pop();
                },
                child: const Text('Skip'),
              ),
              ElevatedButton(
                onPressed: () {
                  // Set note and close dialog
                  setState(() {
                    _note =
                        _noteController.text.isNotEmpty
                            ? _noteController.text
                            : null;
                  });
                  Navigator.of(context).pop();
                },
                child: const Text('Save Note'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print(
      "StationInfoPanel: Building UI with isLoading=$_isLoading, hasError=$_hasError, usedOfflineData=$_usedOfflineData",
    );
    final theme = Theme.of(context);

    return Positioned(
      bottom: 80,
      left: 16,
      right: 16,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        child: Card(
          elevation: 0, // No additional elevation needed
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child:
              _isLoading
                  ? _buildLoadingState()
                  : _hasError
                  ? _buildErrorState()
                  : _buildInfoPanel(theme),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: const Center(
        child: LoadingIndicator(message: 'Loading stream data...'),
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.station.name ?? '',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: widget.onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Icon(
            _isNetworkError ? Icons.cloud_off : Icons.error_outline,
            color: _isNetworkError ? Colors.orange : Colors.red,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            style: TextStyle(
              color: _isNetworkError ? Colors.orange[800] : Colors.red,
            ),
          ),
          if (_errorRecovery != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorRecovery!,
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
          ],
          if (_isNetworkError) ...[
            const SizedBox(height: 8),
            Text(
              'Basic station information is still available below.',
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          // Still show basic station information even when API call fails
          _buildDetailRow(
            Icons.pin_drop,
            'Station ID: ${widget.station.stationId}',
          ),
          const SizedBox(height: 4),
          _buildDetailRow(
            Icons.location_on,
            LocationUtils.formatCoordinates(
              widget.station.lat,
              widget.station.lon,
            ),
          ),

          if (widget.station.elevation != null) ...[
            const SizedBox(height: 4),
            _buildDetailRow(
              Icons.height,
              'Elevation: ${widget.station.elevation!.toStringAsFixed(2)} m',
            ),
          ],

          const SizedBox(height: 16),
          Center(
            child: Consumer<OfflineManagerService>(
              builder: (context, offlineManager, _) {
                final bool offlineModeEnabled =
                    offlineManager.offlineModeEnabled;

                return OutlinedButton.icon(
                  onPressed: _fetchReachData,
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    offlineModeEnabled ? 'Try Offline Data' : 'Try Again',
                  ),
                );
              },
            ),
          ),

          // Action buttons - still available without reach data
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed:
                    widget.onAddToFavorites != null
                        ? () => widget.onAddToFavorites!(widget.station)
                        : () => _addToFavorites(widget.station),
                icon: const Icon(Icons.favorite_border),
                label: const Text('Add to Favorites'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed:
                    widget.onViewForecast != null
                        ? () => widget.onViewForecast!(
                          widget.station.stationId.toString(),
                          widget.station.name ??
                              'Station ${widget.station.stationId}',
                        )
                        : () {
                          Navigator.pushNamed(
                            context,
                            '/forecast',
                            arguments: {
                              'reachId': widget.station.stationId.toString(),
                              'stationName':
                                  widget.station.name ??
                                  'Station ${widget.station.stationId}',
                            },
                          );
                        },
                icon: const Icon(Icons.analytics),
                label: const Text('View Forecast'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPanel(ThemeData theme) {
    final streamName =
        _reachData != null && _reachData!.containsKey('name')
            ? _reachData!['name'] as String? ?? ''
            : (widget.station.name ?? '');

    String? riverClass;
    String? difficulty;

    if (_reachData != null) {
      if (_reachData!.containsKey('class')) {
        riverClass = _reachData!['class']?.toString();
      }

      if (_reachData!.containsKey('difficulty')) {
        difficulty = _reachData!['difficulty']?.toString();
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  streamName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // If using offline data, show an indicator
              if (_usedOfflineData)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Tooltip(
                    message: 'Using offline data',
                    child: Icon(
                      Icons.offline_pin,
                      color: theme.primaryColor,
                      size: 18,
                    ),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: widget.onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // River classification if available
          if (riverClass != null || difficulty != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.water, size: 16, color: theme.primaryColor),
                  const SizedBox(width: 4),
                  Text(
                    riverClass != null && difficulty != null
                        ? 'Class $riverClass - $difficulty'
                        : riverClass != null
                        ? 'Class $riverClass'
                        : difficulty != null
                        ? 'Difficulty: $difficulty'
                        : '',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          // Station details
          _buildDetailRow(
            Icons.pin_drop,
            'Station ID: ${widget.station.stationId}',
          ),
          const SizedBox(height: 4),
          _buildDetailRow(
            Icons.location_on,
            LocationUtils.formatCoordinates(
              widget.station.lat,
              widget.station.lon,
            ),
          ),

          if (widget.station.elevation != null) ...[
            const SizedBox(height: 4),
            _buildDetailRow(
              Icons.height,
              'Elevation: ${widget.station.elevation!.toStringAsFixed(2)} m',
            ),
          ],

          // Additional stream info from API
          if (_reachData != null &&
              _reachData!.containsKey('description') &&
              _reachData!['description'] != null) ...[
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.info_outline,
              _reachData!['description'] as String,
              isMultiLine: true,
            ),
          ],

          // Show latitude and longitude from API if available
          if (_reachData != null &&
              _reachData!.containsKey('latitude') &&
              _reachData!.containsKey('longitude')) ...[
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.place,
              'Coordinates: ${_reachData!['latitude']}, ${_reachData!['longitude']}',
            ),
          ],

          const SizedBox(height: 16),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed:
                    widget.onAddToFavorites != null
                        ? () => widget.onAddToFavorites!(widget.station)
                        : () => _addToFavorites(widget.station),
                icon: const Icon(Icons.favorite_border),
                label: const Text('Add to Favorites'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed:
                    widget.onViewForecast != null
                        ? () => widget.onViewForecast!(
                          widget.station.stationId.toString(),
                          streamName,
                        )
                        : () {
                          Navigator.pushNamed(
                            context,
                            '/forecast',
                            arguments: {
                              'reachId': widget.station.stationId.toString(),
                              'stationName': streamName,
                            },
                          );
                        },
                icon: const Icon(Icons.analytics),
                label: const Text('View Forecast'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String text, {
    bool isMultiLine = false,
  }) {
    return Row(
      crossAxisAlignment:
          isMultiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey[800]),
            maxLines: isMultiLine ? 3 : 1,
            overflow: isMultiLine ? TextOverflow.ellipsis : TextOverflow.clip,
          ),
        ),
      ],
    );
  }
}
