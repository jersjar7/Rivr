import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rivr/features/map/presentation/providers/map_provider.dart';
import '../../../../core/constants/map_constants.dart';

/// A hint widget that prompts the user to zoom in to see clusters.
/// Shows automatically when zoom < MapConstants.minZoomForMarkers (6.0) and `show` is true.
class ZoomHintWidget extends StatelessWidget {
  /// Whether the hint should be shown. Typically controlled by parent state.
  final bool show;

  /// Called when the user taps the close icon to dismiss the hint.
  final VoidCallback onClose;

  const ZoomHintWidget({super.key, required this.show, required this.onClose});

  @override
  Widget build(BuildContext context) {
    // Listen to zoom changes via MapProvider
    final zoom = context.watch<MapProvider>().currentZoom;

    // Do not render if not supposed to show or zoom high enough
    if (!show || zoom >= MapConstants.minZoomForMarkers) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: MediaQuery.of(context).padding.top + 48,
      left: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Zoom in to see river streams',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onClose,
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
