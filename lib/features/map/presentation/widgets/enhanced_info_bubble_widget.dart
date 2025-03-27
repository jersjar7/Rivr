// lib/features/map/presentation/widgets/enhanced_info_bubble_widget.dart

import 'package:flutter/material.dart';
import 'package:rivr/common/providers/reach_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class EnhancedInfoBubble extends StatefulWidget {
  final int stationId;
  final String stationName;
  final double? latitude;
  final double? longitude;
  final double? currentFlow;
  final DateTime? lastUpdated;
  final void Function(int) onAddToFavorites;
  final void Function(int) onGetForecast;
  final void Function()? onDismiss;

  const EnhancedInfoBubble({
    super.key,
    required this.stationId,
    required this.stationName,
    this.latitude,
    this.longitude,
    this.currentFlow,
    this.lastUpdated,
    required this.onAddToFavorites,
    required this.onGetForecast,
    this.onDismiss,
  });

  @override
  State<EnhancedInfoBubble> createState() => _EnhancedInfoBubbleState();
}

class _EnhancedInfoBubbleState extends State<EnhancedInfoBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isLoading = true;
  double? _flowValue;
  String? _waterLevel;
  Map<String, dynamic>? _returnPeriods;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();

    _fetchStationData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchStationData() async {
    // In a real implementation, this would fetch actual return period data
    // and current flow from your API
    setState(() {
      _isLoading = true;
    });

    try {
      final reachProvider = Provider.of<ReachProvider>(context, listen: false);
      await reachProvider.fetchReach(widget.stationId.toString());

      // Simulate fetching return periods
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _flowValue = widget.currentFlow ?? 120.5;
        _waterLevel = _determineWaterLevel(_flowValue!);
        _returnPeriods = {
          'return_period_2': 50.0,
          'return_period_5': 100.0,
          'return_period_10': 150.0,
          'return_period_25': 200.0,
          'return_period_50': 250.0,
          'return_period_100': 300.0,
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _determineWaterLevel(double flow) {
    // This would normally be based on actual return periods
    if (_returnPeriods != null) {
      if (flow < _returnPeriods!['return_period_2']) {
        return 'Low';
      } else if (flow < _returnPeriods!['return_period_5']) {
        return 'Normal';
      } else if (flow < _returnPeriods!['return_period_10']) {
        return 'Moderate';
      } else if (flow < _returnPeriods!['return_period_25']) {
        return 'High';
      } else {
        return 'Flood';
      }
    }
    return 'Unknown';
  }

  Color _getWaterLevelColor(String level) {
    switch (level) {
      case 'Low':
        return Colors.lightBlue;
      case 'Normal':
        return Colors.green;
      case 'Moderate':
        return Colors.orange;
      case 'High':
        return Colors.deepOrange;
      case 'Flood':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: Card(
        color: Colors.blueGrey.withOpacity(.85),
        elevation: 20.0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.stationName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (widget.onDismiss != null)
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: widget.onDismiss,
                    ),
                ],
              ),
              Text(
                'Station ${widget.stationId}',
                style: TextStyle(color: Colors.grey.shade100),
              ),
              const SizedBox(height: 12.0),

              // Flow and status information
              _isLoading
                  ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                  : Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.waves, color: Colors.white70),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current Flow',
                                style: TextStyle(color: Colors.grey.shade300),
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _flowValue?.toStringAsFixed(1) ?? "N/A",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'ft³/s',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(width: 20),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Water Level',
                                style: TextStyle(color: Colors.grey.shade300),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: _getWaterLevelColor(
                                    _waterLevel ?? 'Unknown',
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                child: Text(
                                  _waterLevel ?? 'Unknown',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (widget.lastUpdated != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Last updated: ${DateFormat('MMM d, h:mm a').format(widget.lastUpdated!)}',
                          style: TextStyle(
                            color: Colors.grey.shade300,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),

              const SizedBox(height: 16.0),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.star_border),
                      label: const Text('Add to My Rivers'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                      ),
                      onPressed:
                          () => widget.onAddToFavorites(widget.stationId),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.analytics),
                      label: const Text('Get Forecast'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => widget.onGetForecast(widget.stationId),
                    ),
                  ),
                ],
              ),

              // Station coordinates
              if (widget.latitude != null && widget.longitude != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Lat: ${widget.latitude!.toStringAsFixed(5)}, Lon: ${widget.longitude!.toStringAsFixed(5)}',
                  style: TextStyle(color: Colors.grey.shade300, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
