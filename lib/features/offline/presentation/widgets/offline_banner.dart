// lib/features/offline/presentation/widgets/offline_banner.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/offline_manager_provider.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineManagerProvider>(
      builder: (context, provider, child) {
        if (!provider.offlineModeEnabled) {
          return const SizedBox.shrink(); // Don't show banner if not in offline mode
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          color: Colors.orange,
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                const Icon(Icons.offline_bolt, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Offline Mode Active',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => provider.toggleOfflineMode(false),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
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
