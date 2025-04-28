// lib/features/map/presentation/widgets/map_components/map_loading_indicator.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/station_provider.dart';
import '../../providers/enhanced_clustered_map_provider.dart';

/// A widget that shows a loading indicator when stations or clusters are loading
class MapLoadingIndicator extends StatelessWidget {
  const MapLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<StationProvider, EnhancedClusteredMapProvider>(
      builder: (context, stationProvider, clusteredMapProvider, child) {
        final bool isLoading =
            stationProvider.status == StationLoadingStatus.loading ||
            clusteredMapProvider.status == ClusteringStatus.initializing ||
            clusteredMapProvider.status == ClusteringStatus.updating;

        if (!isLoading) {
          return const SizedBox.shrink();
        }

        return Positioned(
          bottom: 100,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(26),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Loading stations...'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
