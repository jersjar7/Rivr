// lib/core/widgets/offline_status_indicator.dart

import 'package:flutter/material.dart';

class OfflineStatusIndicator extends StatelessWidget {
  final bool isEnabled;
  final void Function(bool) onToggle;
  final String enabledText;
  final String disabledText;

  const OfflineStatusIndicator({
    super.key,
    required this.isEnabled,
    required this.onToggle,
    this.enabledText = 'Offline Mode is ON',
    this.disabledText = 'Offline Mode is OFF',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isEnabled ? Icons.offline_bolt : Icons.cloud_queue,
                  color: isEnabled ? Colors.orange : Colors.blue,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEnabled ? enabledText : disabledText,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isEnabled
                            ? 'App will use cached data and conserve data usage'
                            : 'App will use network data when available',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isEnabled,
                  onChanged: onToggle,
                  activeColor: Theme.of(context).primaryColor,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isEnabled ? Colors.amber[50] : Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isEnabled ? Colors.amber[200]! : Colors.blue[200]!,
                ),
              ),
              child: Text(
                isEnabled
                    ? 'In offline mode, you\'ll see cached data that may not be up-to-date.'
                    : 'The app will fetch the latest data when connected to the internet.',
                style: TextStyle(
                  fontSize: 12,
                  color: isEnabled ? Colors.amber[900] : Colors.blue[900],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
