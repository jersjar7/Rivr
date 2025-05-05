// lib/core/widgets/offline_mode_banner.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/offline_manager_service.dart';

/// A reusable banner that shows when offline mode is active
class OfflineModeBanner extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Consumer<OfflineManagerService>(
      builder: (context, offlineManager, child) {
        if (!offlineManager.offlineModeEnabled) {
          return const SizedBox.shrink(); // Don't show banner if not in offline mode
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          color: backgroundColor,
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                Icon(Icons.offline_bolt, color: textColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Offline Mode Active',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (showDismissButton)
                  TextButton(
                    onPressed: () => offlineManager.setOfflineMode(false),
                    style: TextButton.styleFrom(
                      foregroundColor: textColor,
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
