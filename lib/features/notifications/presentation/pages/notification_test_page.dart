// File 2: lib/features/notifications/presentation/notification_test_page.dart
// Create this new file for testing notifications on your development device

import 'package:flutter/material.dart';
import 'package:rivr/core/services/notification_service.dart';

/// Test page for notification functionality during development
/// This helps verify FCM setup and notification delivery
class NotificationTestPage extends StatefulWidget {
  const NotificationTestPage({super.key});

  @override
  State<NotificationTestPage> createState() => _NotificationTestPageState();
}

class _NotificationTestPageState extends State<NotificationTestPage> {
  final NotificationService _notificationService = NotificationService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧪 Notification Testing'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            _buildStatusCard(),
            const SizedBox(height: 20),

            // Test Buttons
            _buildTestSection(),
            const SizedBox(height: 20),

            // Integration Info
            _buildIntegrationInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📊 Notification Status',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),

            _buildStatusRow(
              '🔔 Permissions',
              _notificationService.permissionGranted
                  ? 'Granted'
                  : 'Not Granted',
              _notificationService.permissionGranted
                  ? Colors.green
                  : Colors.red,
            ),

            _buildStatusRow(
              '🎫 FCM Token',
              _notificationService.fcmToken != null
                  ? 'Available'
                  : 'Not Available',
              _notificationService.fcmToken != null
                  ? Colors.green
                  : Colors.orange,
            ),

            if (_notificationService.fcmToken != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Token: ${_notificationService.fcmToken!.substring(0, 50)}...',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🧪 Test Notifications',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // Information Alert Test
            _buildTestButton(
              title: '📊 Information Alert',
              subtitle: 'Normal flow conditions',
              onPressed:
                  () => _sendTestNotification(
                    title: '📊 Flow Update: Green River',
                    body:
                        'Normal flow conditions (250 cfs). Ideal for most activities.',
                    category: 'Normal',
                    priority: 'information',
                  ),
              color: Colors.blue,
            ),

            const SizedBox(height: 12),

            // Activity Alert Test
            _buildTestButton(
              title: '🎯 Activity Alert',
              subtitle: 'Kayaking threshold triggered',
              onPressed:
                  () => _sendTestNotification(
                    title: '🎯 Activity Alert: Perfect Kayaking',
                    body:
                        'Green River: Moderate flow (300 cfs). Ideal for kayaking!',
                    category: 'Moderate',
                    priority: 'activity',
                  ),
              color: Colors.orange,
            ),

            const SizedBox(height: 12),

            // Safety Alert Test
            _buildTestButton(
              title: '⚠️ Safety Alert',
              subtitle: 'High flow warning',
              onPressed:
                  () => _sendTestNotification(
                    title: '⚠️ Safety Alert: High Flow',
                    body:
                        'Green River: Very High flow (700 cfs). Extreme danger - avoid water activities!',
                    category: 'Very High',
                    priority: 'safety',
                  ),
              color: Colors.red,
            ),

            const SizedBox(height: 12),

            // Thesis Demo Alert Test
            _buildTestButton(
              title: '🎓 Thesis Demo',
              subtitle: 'Demonstration notification',
              onPressed:
                  () => _sendTestNotification(
                    title: '🎓 Thesis Demo: NOAA Integration',
                    body:
                        'Real-time flow data (450 cfs) from NOAA National Water Model.',
                    category: 'Elevated',
                    priority: 'demonstration',
                  ),
              color: Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestButton({
    required String title,
    required String subtitle,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.1),
          foregroundColor: color,
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: color.withValues(alpha: 0.3)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: color.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntegrationInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🔗 Integration Status',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),

            const _InfoRow(
              icon: '✅',
              title: 'FCM Dependencies',
              subtitle:
                  'firebase_messaging: ^15.2.7\nflutter_local_notifications: ^19.2.1',
            ),

            const _InfoRow(
              icon: '✅',
              title: 'Alert Engine',
              subtitle: 'Flow classification and threshold checking ready',
            ),

            const _InfoRow(
              icon: '🔧',
              title: 'Cloud Functions',
              subtitle: 'Ready for deployment and testing',
            ),

            const _InfoRow(
              icon: '📱',
              title: 'Deep Linking',
              subtitle: 'rivr://reach/{id} format configured',
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📋 Next Steps:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1. Test notifications work on this device\n'
                    '2. Deploy Cloud Functions with alert engine\n'
                    '3. Connect NOAA data flow to monitoring\n'
                    '4. Test end-to-end alert generation',
                    style: TextStyle(color: Colors.blue.shade700, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendTestNotification({
    required String title,
    required String body,
    required String category,
    required String priority,
  }) async {
    if (!_notificationService.permissionGranted) {
      _showMessage('❌ Notification permissions not granted');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _notificationService.sendTestNotification(
        title: title,
        body: body,
        category: category,
        priority: priority,
        reachId: 'test-reach-001',
      );

      _showMessage('✅ Test notification sent!');
    } catch (e) {
      _showMessage('❌ Error sending notification: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
