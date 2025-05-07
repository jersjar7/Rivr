// lib/features/map/presentation/widgets/stream_info_panel.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rivr/core/error/error_handler.dart';
import 'package:rivr/core/error/exceptions.dart';
import 'package:rivr/core/repositories/offline_storage_repository.dart';
import 'package:rivr/features/favorites/presentation/providers/favorites_provider.dart';
import 'package:rivr/core/services/stream_name_service.dart';
import 'package:rivr/core/di/service_locator.dart';
import '../../domain/entities/map_station.dart';
import '../../../../core/utils/location_utils.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../common/data/remote/reach_service.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';

class StreamInfoPanel extends StatefulWidget {
  final MapStation station;
  final VoidCallback onClose;
  final Future<void> Function(MapStation)? onAddToFavorites;
  final Function(String, String)? onViewForecast;
  final Function? onNavigateToFavorites;
  final String? displayName; // Optional parameter

  const StreamInfoPanel({
    super.key,
    required this.station,
    required this.onClose,
    this.onAddToFavorites,
    this.onViewForecast,
    this.onNavigateToFavorites,
    this.displayName, // Made optional
  });

  @override
  State<StreamInfoPanel> createState() => _StreamInfoPanelState();
}

class _StreamInfoPanelState extends State<StreamInfoPanel> {
  bool _isLoading = true;
  bool _hasError = false;
  bool _isNetworkError = false;
  String _errorMessage = '';
  String? _errorRecovery;
  Map<String, dynamic>? _reachData;

  // For name management
  late StreamNameService _streamNameService;
  bool _isLoadingName = true;
  String? _displayName;
  bool _isCustomName = false;

  // For note
  final TextEditingController _noteController = TextEditingController();
  String? _note;

  // For offline storage
  final OfflineStorageRepository _offlineStorage = OfflineStorageRepository();

  @override
  void initState() {
    super.initState();
    _streamNameService = sl<StreamNameService>();
    print(
      "StreamInfoPanel: initializing for station ID: ${widget.station.stationId}",
    );
    _fetchReachData();
    _loadStationName();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  // Load the station name from StreamNameService
  Future<void> _loadStationName() async {
    if (!mounted) return;

    setState(() => _isLoadingName = true);

    try {
      // Try to get name info from the service
      final nameInfo = await _streamNameService.getNameInfo(
        widget.station.stationId.toString(),
      );

      // Check if this is a custom name
      bool isCustom = false;
      if (nameInfo.originalApiName != null &&
          nameInfo.originalApiName!.isNotEmpty &&
          nameInfo.displayName != nameInfo.originalApiName) {
        isCustom = true;
      }

      // Update state if still mounted
      if (mounted) {
        setState(() {
          _displayName = nameInfo.displayName;
          _isCustomName = isCustom;
          _isLoadingName = false;
        });
      }
    } catch (e) {
      print("Error loading name from StreamNameService: $e");

      // We'll fall back to using the name from API data
      // in _getDisplayName method
      if (mounted) {
        setState(() => _isLoadingName = false);
      }
    }
  }

  Future<void> _fetchReachData() async {
    if (!mounted) return;

    print(
      "DEBUG START: _fetchReachData for station ID: ${widget.station.stationId}",
    );
    print("DEBUG: Initial station name from widget: ${widget.station.name}");
    print("DEBUG: Display name from widget: ${widget.displayName}");

    setState(() {
      _isLoading = true;
      _hasError = false;
      _isNetworkError = false;
      _errorMessage = '';
      _errorRecovery = null;
    });

    // First check if we have cached data for this station
    try {
      print("DEBUG: Checking for cached data");
      final cachedData = await _offlineStorage.getCachedStation(
        widget.station.stationId,
      );

      if (cachedData != null && cachedData['apiData'] != null) {
        print("DEBUG: Found cached data: ${cachedData['apiData']}");
        if (cachedData['apiData'] is Map &&
            cachedData['apiData']['name'] != null) {
          print("DEBUG: Cached name: ${cachedData['apiData']['name']}");

          // Update the StreamNameService with this name as the original API name
          try {
            await _streamNameService.setOriginalApiName(
              widget.station.stationId.toString(),
              cachedData['apiData']['name'].toString(),
            );
          } catch (e) {
            print("Warning: Failed to update original API name: $e");
          }
        } else {
          print("DEBUG: No name found in cached data");
        }

        if (!mounted) return;

        setState(() {
          _reachData = cachedData['apiData'];
          _isLoading = false;
        });

        print("DEBUG: Using cached data");
        return;
      } else {
        print("DEBUG: No cached data found or data is invalid");
      }
    } catch (e) {
      print("DEBUG ERROR: Error checking cached data: $e");
      // Continue to fetch from API if cache check fails
    }

    try {
      print(
        "DEBUG: Fetching fresh data from API for station ID: ${widget.station.stationId}",
      );
      final reachService = ReachService();
      final reachId = widget.station.stationId.toString();

      final data = await reachService.fetchReach(reachId);
      print("DEBUG: API response received: $data");
      if (data != null && data is Map) {
        print("DEBUG: API returned name: ${data['name']}");

        // Update the StreamNameService with this name as the original API name
        if (data['name'] != null && data['name'].toString().isNotEmpty) {
          try {
            await _streamNameService.setOriginalApiName(
              reachId,
              data['name'].toString(),
            );
          } catch (e) {
            print("Warning: Failed to update original API name: $e");
          }
        }
      }

      if (!mounted) return;

      // Cache the data for offline use
      await _offlineStorage.cacheStation(widget.station, data);
      print("DEBUG: Cached data for station ${widget.station.stationId}");

      setState(() {
        _reachData = data;
        _isLoading = false;
      });

      print("DEBUG: Data loaded successfully");
    } catch (e) {
      print("DEBUG ERROR: Error fetching reach data: $e");

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

    print("DEBUG END: _fetchReachData");
  }

  // Get a reliable display name - now uses StreamNameService as primary source
  String _getDisplayName() {
    // First priority: Use name from StreamNameService if available
    if (!_isLoadingName && _displayName != null && _displayName!.isNotEmpty) {
      return _displayName!;
    }

    // Second priority: Use the provided display name from widget
    if (widget.displayName != null && widget.displayName!.isNotEmpty) {
      return widget.displayName!;
    }

    // Third priority: Use API data name if available
    if (_reachData != null &&
        _reachData!.containsKey('name') &&
        _reachData!['name'] != null &&
        _reachData!['name'].toString().trim().isNotEmpty) {
      return _reachData!['name'].toString();
    }

    // Last resort: Use station name from widget or default to ID-based name
    if (widget.station.name != null && widget.station.name!.isNotEmpty) {
      return widget.station.name!;
    }

    // Ultimate fallback: Use ID-based name
    return 'Stream ${widget.station.stationId}';
  }

  Future<void> _addToFavorites(MapStation station) async {
    // Get the current display name
    String displayName = _getDisplayName();
    String stationId = station.stationId.toString();

    // Check if we need to prompt for a name
    bool isDefaultName = displayName == 'Stream $stationId';
    String? originalApiName;

    // Try to get original API name from StreamNameService first
    try {
      final nameInfo = await _streamNameService.getNameInfo(stationId);
      originalApiName = nameInfo.originalApiName;
    } catch (e) {
      print("Error getting original API name: $e");
      // Try to get it from API data as fallback
      if (_reachData != null &&
          _reachData!.containsKey('name') &&
          _reachData!['name'] != null) {
        originalApiName = _reachData!['name'].toString();
      }
    }

    // If using the default name pattern, show name input dialog first
    if (isDefaultName) {
      final customName = await _showNameInputDialog();

      // If user canceled the name dialog, abort the process
      if (customName == null) return;

      // Use the provided name
      displayName = customName;

      // Update the StreamNameService with the new name
      try {
        await _streamNameService.updateDisplayName(stationId, customName);

        // If we have an original API name, ensure it's set
        if (originalApiName != null && originalApiName.isNotEmpty) {
          await _streamNameService.setOriginalApiName(
            stationId,
            originalApiName,
          );
        }

        // Update local state
        setState(() {
          _displayName = customName;
          _isCustomName =
              originalApiName != null &&
              originalApiName != customName &&
              originalApiName.isNotEmpty;
        });
      } catch (e) {
        print("Warning: Failed to update StreamNameService with new name: $e");
      }

      // Also update the cached data for backward compatibility
      if (_reachData != null) {
        final Map<String, dynamic> updatedData = Map.from(_reachData!);
        updatedData['name'] = customName;
        await _offlineStorage.cacheStation(station, updatedData);
      } else {
        // If no _reachData exists yet, create a basic one with the name
        final Map<String, dynamic> newData = {'name': customName};
        await _offlineStorage.cacheStation(station, newData);
      }
    }

    // After dialog is closed, proceed with adding to favorites
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final favoritesProvider = Provider.of<FavoritesProvider>(
      context,
      listen: false,
    );

    final user = authProvider.currentUser;
    if (user != null) {
      try {
        // Add station to favorites with the display name and original API name
        final success = await favoritesProvider.addFavoriteFromStation(
          user.uid,
          stationId,
          displayName: displayName,
          description: _note,
          originalApiName: originalApiName,
        );

        if (success) {
          // Show confirmation snackbar
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Added $displayName to favorites'),
                duration: const Duration(seconds: 1),
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
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to add to favorites. Please try again.'),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
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

  Future<String?> _showNameInputDialog() {
    final TextEditingController nameController = TextEditingController();

    return showDialog<String>(
      context: context,
      barrierDismissible: false, // User must take an action
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Name This Stream'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'This stream does not have a name. Please assign it a name for your device\'s use:',
                style: TextStyle(color: Colors.grey[700], fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  hintText: 'Enter a name for this stream',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
                maxLength: 100,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cancel
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Validate input - don't allow empty names
                if (nameController.text.trim().isNotEmpty) {
                  Navigator.of(context).pop(nameController.text.trim());
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a name')),
                  );
                }
              },
              child: const Text('Save Name'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
                child: Row(
                  children: [
                    if (_isLoadingName)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.black54,
                          ),
                        ),
                      ),
                    if (_isLoadingName) const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getDisplayName(), // Use our enhanced display name method
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
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
          // Rest of error state implementation...
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
            child: OutlinedButton.icon(
              onPressed: _fetchReachData,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
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
                          _getDisplayName(), // Use our enhanced display name method
                        )
                        : () {
                          Navigator.pushNamed(
                            context,
                            '/forecast',
                            arguments: {
                              'reachId': widget.station.stationId.toString(),
                              'stationName': _getDisplayName(),
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
    // Get the station name - now uses our enhanced method
    final streamName = _getDisplayName();

    // Show custom name indicator if applicable
    final isCustomName =
        _isCustomName ||
        (
        // Legacy check for backward compatibility
        _reachData != null &&
            _reachData!.containsKey('name') &&
            _reachData!['name'] != null &&
            streamName != _reachData!['name'].toString() &&
            _reachData!['name'].toString().isNotEmpty);

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
                child: Row(
                  children: [
                    if (_isLoadingName)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.black54,
                          ),
                        ),
                      ),
                    if (_isLoadingName) const SizedBox(width: 8),
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
                    // Optional edit button for renaming
                    IconButton(
                      icon: const Icon(Icons.edit, size: 16),
                      onPressed: () async {
                        final newName = await _showNameInputDialog();
                        if (newName != null) {
                          // Update the name in StreamNameService
                          try {
                            await _streamNameService.updateDisplayName(
                              widget.station.stationId.toString(),
                              newName,
                            );

                            // Update local state
                            if (mounted) {
                              setState(() {
                                _displayName = newName;
                                _isCustomName = true;
                              });
                            }
                          } catch (e) {
                            print("Error updating name: $e");
                          }
                        }
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Edit Name',
                    ),
                  ],
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

          // Show custom name indicator if applicable
          if (isCustomName)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Custom Name',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
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
