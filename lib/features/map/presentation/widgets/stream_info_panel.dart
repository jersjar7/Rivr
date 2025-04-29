// lib/features/map/presentation/widgets/stream_info_panel.dart

import 'package:flutter/material.dart';
import '../../domain/entities/map_station.dart';
import '../../../../core/utils/location_utils.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../common/data/remote/reach_service.dart';

class StreamInfoPanel extends StatefulWidget {
  final MapStation station;
  final VoidCallback onClose;
  final Future<void> Function(MapStation)? onAddToFavorites;
  final Function(String, String)? onViewForecast;

  const StreamInfoPanel({
    super.key,
    required this.station,
    required this.onClose,
    this.onAddToFavorites,
    this.onViewForecast,
  });

  @override
  State<StreamInfoPanel> createState() => _StreamInfoPanelState();
}

class _StreamInfoPanelState extends State<StreamInfoPanel> {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  Map<String, dynamic>? _reachData;

  @override
  void initState() {
    super.initState();
    print(
      "StreamInfoPanel: initializing for station ID: ${widget.station.stationId}",
    );
    _fetchReachData();
  }

  Future<void> _fetchReachData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      print("Fetching reach data for station ID: ${widget.station.stationId}");
      final reachService = ReachService();
      final reachId = widget.station.stationId.toString();

      print("Making API request to NOAA API for reach ID: $reachId");
      final data = await reachService.fetchReach(reachId);
      print("API response received for reach ID $reachId");

      if (!mounted) return;

      setState(() {
        _reachData = data;
        _isLoading = false;
      });

      print("StreamInfoPanel: Data loaded successfully");
    } catch (e) {
      print("Error fetching reach data for ${widget.station.stationId}: $e");

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Failed to load stream data: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print(
      "StreamInfoPanel: Building UI with isLoading=$_isLoading, hasError=$_hasError",
    );
    final theme = Theme.of(context);

    return Positioned(
      bottom: 100,
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
                  widget.station.name ?? 'Station ${widget.station.stationId}',
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
          const Icon(Icons.error_outline, color: Colors.red, size: 32),
          const SizedBox(height: 8),
          Text(_errorMessage, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton.icon(
              onPressed: _fetchReachData,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPanel(ThemeData theme) {
    final streamName =
        _reachData != null && _reachData!.containsKey('name')
            ? _reachData!['name'] as String
            : (widget.station.name ?? 'Station ${widget.station.stationId}');

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
              'API Coordinates: ${_reachData!['latitude']}, ${_reachData!['longitude']}',
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
                        : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Added to favorites')),
                          );
                        },
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
