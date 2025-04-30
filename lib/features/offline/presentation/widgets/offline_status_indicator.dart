// lib/features/offline/presentation/widgets/offline_status_indicator.dart

import 'package:flutter/material.dart';

class OfflineStatusIndicator extends StatelessWidget {
  final bool isEnabled;
  final Function(bool) onToggle;

  const OfflineStatusIndicator({
    super.key,
    required this.isEnabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isEnabled ? Icons.offline_bolt : Icons.cloud_off,
                  color: isEnabled ? Colors.green : Colors.grey,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Offline Mode',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isEnabled ? Colors.green : Colors.grey[700],
                  ),
                ),
                const Spacer(),
                Switch(
                  value: isEnabled,
                  onChanged: onToggle,
                  activeColor: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              isEnabled
                  ? 'Offline mode is active. The app will use cached data and avoid network requests.'
                  : 'Offline mode is disabled. Enable it when you are in areas with poor connectivity.',
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
            ),
            if (isEnabled) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You\'re viewing cached data which may not be the most current.',
                        style: TextStyle(
                          color: Colors.green[800],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
