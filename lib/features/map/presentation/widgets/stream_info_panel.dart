// lib/features/map/presentation/widgets/stream_info_panel.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rivr/core/di/service_locator.dart';
import 'package:rivr/core/error/exceptions.dart';
import 'package:rivr/core/services/stream_name_service.dart';
import 'package:rivr/core/widgets/loading_indicator.dart';

import '../../domain/entities/map_station.dart';
import '../helpers/stream_info_helper.dart';
import '../widgets/stream_info_content.dart';
import '../widgets/dialogs/stream_name_dialog.dart';

/// Main panel for displaying information about a stream/station
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

  // Name management
  late StreamNameService _streamNameService;
  late StreamInfoHelper _infoHelper;
  bool _isLoadingName = true;
  String? _displayName;
  bool _isCustomName = false;

  // For note (for future use)
  final TextEditingController _noteController = TextEditingController();
  String? _note;

  @override
  void initState() {
    super.initState();
    _streamNameService = sl<StreamNameService>();
    _infoHelper = StreamInfoHelper(streamNameService: _streamNameService);

    print(
      "StreamInfoPanel: initializing for station ID: ${widget.station.stationId}",
    );
    _fetchData();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  /// Fetch all necessary data
  Future<void> _fetchData() async {
    if (!mounted) return;

    // Start loading name and reach data in parallel
    final nameFuture = _loadStationName();
    final dataFuture = _fetchReachData();

    // Wait for both to complete
    await Future.wait([nameFuture, dataFuture]);
  }

  /// Load the station name
  Future<void> _loadStationName() async {
    if (!mounted) return;

    setState(() => _isLoadingName = true);

    try {
      // Get the display name using the helper
      final displayName = await _infoHelper.getDisplayName(
        widget.station,
        widget.displayName,
      );

      // Check if it's a custom name
      final isCustom = await _infoHelper.isCustomName(
        widget.station.stationId.toString(),
        displayName,
      );

      // Update state if still mounted
      if (mounted) {
        setState(() {
          _displayName = displayName;
          _isCustomName = isCustom;
          _isLoadingName = false;
        });
      }
    } catch (e) {
      print("Error loading station name: $e");
      if (mounted) {
        setState(() => _isLoadingName = false);
      }
    }
  }

  /// Fetch reach data
  Future<void> _fetchReachData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _isNetworkError = false;
      _errorMessage = '';
      _errorRecovery = null;
    });

    try {
      // Use the helper to fetch data
      final data = await _infoHelper.fetchReachData(widget.station);

      if (!mounted) return;

      setState(() {
        _reachData = data;
        _isLoading = false;
      });

      // Once we have data, reload the name in case it was updated by the API
      _loadStationName();
    } catch (e) {
      print("Error fetching reach data: $e");

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _hasError = true;
        _isNetworkError = e is NetworkException;
        _errorMessage = e.toString();
        // Error recovery suggestion could be provided here
      });
    }
  }

  /// Get the current display name
  String _getDisplayName() {
    // First priority: Use name from state if available
    if (!_isLoadingName && _displayName != null && _displayName!.isNotEmpty) {
      return _displayName!;
    }

    // Second priority: Use the provided display name from widget
    if (widget.displayName != null && widget.displayName!.isNotEmpty) {
      return widget.displayName!;
    }

    // Third priority: Use station name from widget
    if (widget.station.name != null && widget.station.name!.isNotEmpty) {
      return widget.station.name!;
    }

    // Ultimate fallback: Use ID-based name
    return 'Stream ${widget.station.stationId}';
  }

  /// Handle adding to favorites
  Future<void> _addToFavorites() async {
    // Use the helper to add to favorites
    final success = await _infoHelper.addToFavorites(
      context,
      widget.station,
      customDisplayName: _displayName,
      description: _note,
    );

    if (success) {
      // Close the info panel
      widget.onClose();

      // Navigate to favorites if callback provided
      if (widget.onNavigateToFavorites != null) {
        // Small delay to let the UI update
        await Future.delayed(const Duration(milliseconds: 300));
        widget.onNavigateToFavorites!();
      }
    }
  }

  /// Handle editing the name
  Future<void> _editName() async {
    // Use the helper to update display name
    final success = await _infoHelper.updateDisplayName(
      context,
      widget.station.stationId.toString(),
      widget.station,
    );

    if (success && mounted) {
      // Reload name info
      _loadStationName();
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  : _buildInfoContent(),
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
    return StreamInfoErrorContent(
      displayName: _getDisplayName(),
      isLoadingName: _isLoadingName,
      errorMessage: _errorMessage,
      errorRecovery: _errorRecovery,
      isNetworkError: _isNetworkError,
      stationId: widget.station.stationId.toString(),
      lat: widget.station.lat,
      lon: widget.station.lon,
      elevation: widget.station.elevation,
      onRefresh: _fetchReachData,
      onAddToFavorites: _addToFavorites,
      onViewForecast: (reachId, name) {
        if (widget.onViewForecast != null) {
          widget.onViewForecast!(reachId, name);
        } else {
          Navigator.pushNamed(
            context,
            '/forecast',
            arguments: {'reachId': reachId, 'stationName': name},
          );
        }
      },
    );
  }

  Widget _buildInfoContent() {
    return StreamInfoContent(
      streamName: _getDisplayName(),
      isCustomName: _isCustomName,
      reachData: _reachData,
      stationId: widget.station.stationId.toString(),
      lat: widget.station.lat,
      lon: widget.station.lon,
      elevation: widget.station.elevation,
      onAddToFavorites: () {
        if (widget.onAddToFavorites != null) {
          widget.onAddToFavorites!(widget.station);
        } else {
          _addToFavorites();
        }
      },
      onEditName: _editName,
      onViewForecast: (reachId, name) {
        if (widget.onViewForecast != null) {
          widget.onViewForecast!(reachId, name);
        } else {
          Navigator.pushNamed(
            context,
            '/forecast',
            arguments: {'reachId': reachId, 'stationName': name},
          );
        }
      },
    );
  }
}
