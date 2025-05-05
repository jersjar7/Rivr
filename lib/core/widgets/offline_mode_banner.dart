// lib/core/widgets/offline_mode_banner.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/offline_manager_service.dart';

/// A reusable banner that shows when offline mode is active
/// Optimized to prevent unnecessary rebuilds
class OfflineModeBanner extends StatefulWidget {
  final bool showDismissButton;
  final Color backgroundColor;
  final Color textColor;

  const OfflineModeBanner({
    super.key,
    this.showDismissButton = true,
    this.backgroundColor = Colors.orange,
    this.textColor = Colors.white,
  });

  @override
  State<OfflineModeBanner> createState() => _OfflineModeBannerState();
}

class _OfflineModeBannerState extends State<OfflineModeBanner> {
  bool _wasEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineManagerService>(
      builder: (context, offlineManager, child) {
        final isEnabled = offlineManager.offlineModeEnabled;

        // Only rebuild if state actually changed
        if (isEnabled != _wasEnabled) {
          _wasEnabled = isEnabled;
        }

        // Don't show anything if not in offline mode
        if (!isEnabled) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          color: widget.backgroundColor,
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                Icon(Icons.offline_bolt, color: widget.textColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Offline Mode Active',
                    style: TextStyle(
                      color: widget.textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (widget.showDismissButton)
                  TextButton(
                    onPressed: () => offlineManager.setOfflineMode(false),
                    style: TextButton.styleFrom(
                      foregroundColor: widget.textColor,
                      backgroundColor: Colors.black26,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 0,
                      ),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    child: const Text('Disable'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
