// lib/features/settings/presentation/pages/notification_settings_page.dart
// Production notification settings page

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/notification_service.dart';
import '../../../../core/navigation/app_router.dart';

/// Production notification settings page
///
/// Allows users to configure their notification preferences
/// This is a real feature users need in a production app
class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final NotificationService _notificationService = NotificationService();

  // Notification preferences
  bool _notificationsEnabled = true;
  bool _safetyAlerts = true;
  bool _activityAlerts = true;
  bool _informationAlerts = false;

  // Quiet hours
  bool _quietHoursEnabled = false;
  TimeOfDay _quietHoursStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietHoursEnd = const TimeOfDay(hour: 7, minute: 0);

  // Frequency settings
  String _notificationFrequency = 'realtime'; // 'realtime', 'daily', 'weekly'

  // Sound and vibration
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  // Loading state
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notification Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => AppRouter.navigateToNotificationHistory(context),
            tooltip: 'Notification History',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMainToggleSection(),
          const SizedBox(height: 24),
          _buildAlertTypesSection(),
          const SizedBox(height: 24),
          _buildFrequencySection(),
          const SizedBox(height: 24),
          _buildQuietHoursSection(),
          const SizedBox(height: 24),
          _buildSoundVibrationSection(),
          const SizedBox(height: 24),
          _buildTestSection(),
          const SizedBox(height: 24),
          _buildAdvancedSection(),
        ],
      ),
      bottomNavigationBar: _isSaving ? const LinearProgressIndicator() : null,
    );
  }

  Widget _buildMainToggleSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Flow Notifications',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Get alerts about river flow conditions and safety updates',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Enable Notifications'),
              subtitle: Text(
                _notificationsEnabled
                    ? 'You\'ll receive flow alerts'
                    : 'All notifications are disabled',
              ),
              value: _notificationsEnabled,
              onChanged: _onMainToggleChanged,
              secondary: Icon(
                _notificationsEnabled
                    ? Icons.notifications
                    : Icons.notifications_off,
                color: _notificationsEnabled ? Colors.blue : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertTypesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Alert Types', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Choose which types of alerts you want to receive',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Safety Alerts'),
              subtitle: const Text(
                'Critical warnings about dangerous conditions',
              ),
              value: _safetyAlerts,
              onChanged:
                  _notificationsEnabled
                      ? (value) {
                        setState(() => _safetyAlerts = value);
                        _saveSettings();
                      }
                      : null,
              secondary: Icon(
                Icons.warning,
                color: _safetyAlerts ? Colors.red : Colors.grey,
              ),
            ),
            SwitchListTile(
              title: const Text('Activity Alerts'),
              subtitle: const Text('Notifications for your custom thresholds'),
              value: _activityAlerts,
              onChanged:
                  _notificationsEnabled
                      ? (value) {
                        setState(() => _activityAlerts = value);
                        _saveSettings();
                      }
                      : null,
              secondary: Icon(
                Icons.kayaking,
                color: _activityAlerts ? Colors.blue : Colors.grey,
              ),
            ),
            SwitchListTile(
              title: const Text('Information Updates'),
              subtitle: const Text('General flow condition updates'),
              value: _informationAlerts,
              onChanged:
                  _notificationsEnabled
                      ? (value) {
                        setState(() => _informationAlerts = value);
                        _saveSettings();
                      }
                      : null,
              secondary: Icon(
                Icons.info,
                color: _informationAlerts ? Colors.green : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrequencySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notification Frequency',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'How often should we check for flow changes?',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            RadioListTile<String>(
              title: const Text('Real-time'),
              subtitle: const Text('Immediate alerts when conditions change'),
              value: 'realtime',
              groupValue: _notificationFrequency,
              onChanged:
                  _notificationsEnabled
                      ? (value) {
                        setState(() => _notificationFrequency = value!);
                        _saveSettings();
                      }
                      : null,
            ),
            RadioListTile<String>(
              title: const Text('Daily Summary'),
              subtitle: const Text('Once per day digest of conditions'),
              value: 'daily',
              groupValue: _notificationFrequency,
              onChanged:
                  _notificationsEnabled
                      ? (value) {
                        setState(() => _notificationFrequency = value!);
                        _saveSettings();
                      }
                      : null,
            ),
            RadioListTile<String>(
              title: const Text('Weekly Summary'),
              subtitle: const Text('Weekly overview of flow conditions'),
              value: 'weekly',
              groupValue: _notificationFrequency,
              onChanged:
                  _notificationsEnabled
                      ? (value) {
                        setState(() => _notificationFrequency = value!);
                        _saveSettings();
                      }
                      : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuietHoursSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quiet Hours', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Pause non-critical notifications during specific hours',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Enable Quiet Hours'),
              subtitle: Text(
                _quietHoursEnabled
                    ? 'Active from ${_formatTime(_quietHoursStart)} to ${_formatTime(_quietHoursEnd)}'
                    : 'Notifications allowed all day',
              ),
              value: _quietHoursEnabled,
              onChanged:
                  _notificationsEnabled
                      ? (value) {
                        setState(() => _quietHoursEnabled = value);
                        _saveSettings();
                      }
                      : null,
              secondary: Icon(
                _quietHoursEnabled ? Icons.bedtime : Icons.schedule,
                color: _quietHoursEnabled ? Colors.purple : Colors.grey,
              ),
            ),
            if (_quietHoursEnabled) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTimeSelector(
                      'Start Time',
                      _quietHoursStart,
                      (time) => setState(() => _quietHoursStart = time),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTimeSelector(
                      'End Time',
                      _quietHoursEnd,
                      (time) => setState(() => _quietHoursEnd = time),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.amber.shade700,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Safety alerts will still be delivered during quiet hours',
                        style: TextStyle(fontSize: 12),
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

  Widget _buildTimeSelector(
    String label,
    TimeOfDay time,
    Function(TimeOfDay) onChanged,
  ) {
    return InkWell(
      onTap: () async {
        final newTime = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (newTime != null) {
          onChanged(newTime);
          _saveSettings();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(time),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoundVibrationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sound & Vibration',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Configure how notifications get your attention',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Sound'),
              subtitle: const Text('Play notification sound'),
              value: _soundEnabled,
              onChanged:
                  _notificationsEnabled
                      ? (value) {
                        setState(() => _soundEnabled = value);
                        _saveSettings();
                      }
                      : null,
              secondary: Icon(
                _soundEnabled ? Icons.volume_up : Icons.volume_off,
                color: _soundEnabled ? Colors.blue : Colors.grey,
              ),
            ),
            SwitchListTile(
              title: const Text('Vibration'),
              subtitle: const Text('Vibrate for notifications'),
              value: _vibrationEnabled,
              onChanged:
                  _notificationsEnabled
                      ? (value) {
                        setState(() => _vibrationEnabled = value);
                        _saveSettings();
                      }
                      : null,
              secondary: Icon(
                _vibrationEnabled ? Icons.vibration : Icons.phone_android,
                color: _vibrationEnabled ? Colors.blue : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Test Notifications',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Send test notifications to verify your settings',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        _notificationsEnabled ? _sendTestSafetyAlert : null,
                    icon: const Icon(Icons.warning),
                    label: const Text('Test Safety Alert'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        _notificationsEnabled ? _sendTestActivityAlert : null,
                    icon: const Icon(Icons.kayaking),
                    label: const Text('Test Activity Alert'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Advanced', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Notification History'),
              subtitle: const Text('View and manage past notifications'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => AppRouter.navigateToNotificationHistory(context),
            ),
            ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('Custom Thresholds'),
              subtitle: const Text('Set up activity-specific alerts'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _openThresholdSettings,
            ),
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('Reset to Defaults'),
              subtitle: const Text('Restore original notification settings'),
              trailing: const Icon(Icons.refresh),
              onTap: _resetToDefaults,
            ),
          ],
        ),
      ),
    );
  }

  // Event handlers and utility methods

  void _onMainToggleChanged(bool value) async {
    if (value) {
      // Request permission when enabling notifications
      final permissionGranted = await _notificationService.requestPermissions();
      if (!permissionGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Notification permission is required to receive alerts',
            ),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: null, // TODO: Open app settings
            ),
          ),
        );
        return;
      }
    }

    setState(() => _notificationsEnabled = value);
    await _saveSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
        _safetyAlerts = prefs.getBool('safety_alerts') ?? true;
        _activityAlerts = prefs.getBool('activity_alerts') ?? true;
        _informationAlerts = prefs.getBool('information_alerts') ?? false;
        _quietHoursEnabled = prefs.getBool('quiet_hours_enabled') ?? false;
        _notificationFrequency =
            prefs.getString('notification_frequency') ?? 'realtime';
        _soundEnabled = prefs.getBool('sound_enabled') ?? true;
        _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;

        // Load quiet hours times
        final startHour = prefs.getInt('quiet_hours_start_hour') ?? 22;
        final startMinute = prefs.getInt('quiet_hours_start_minute') ?? 0;
        final endHour = prefs.getInt('quiet_hours_end_hour') ?? 7;
        final endMinute = prefs.getInt('quiet_hours_end_minute') ?? 0;

        _quietHoursStart = TimeOfDay(hour: startHour, minute: startMinute);
        _quietHoursEnd = TimeOfDay(hour: endHour, minute: endMinute);

        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading settings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool('notifications_enabled', _notificationsEnabled);
      await prefs.setBool('safety_alerts', _safetyAlerts);
      await prefs.setBool('activity_alerts', _activityAlerts);
      await prefs.setBool('information_alerts', _informationAlerts);
      await prefs.setBool('quiet_hours_enabled', _quietHoursEnabled);
      await prefs.setString('notification_frequency', _notificationFrequency);
      await prefs.setBool('sound_enabled', _soundEnabled);
      await prefs.setBool('vibration_enabled', _vibrationEnabled);

      // Save quiet hours times
      await prefs.setInt('quiet_hours_start_hour', _quietHoursStart.hour);
      await prefs.setInt('quiet_hours_start_minute', _quietHoursStart.minute);
      await prefs.setInt('quiet_hours_end_hour', _quietHoursEnd.hour);
      await prefs.setInt('quiet_hours_end_minute', _quietHoursEnd.minute);

      debugPrint('✅ Notification settings saved');
    } catch (e) {
      debugPrint('❌ Error saving settings: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to save settings')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _sendTestSafetyAlert() async {
    await _notificationService.sendTestNotification(
      title: '⚠️ Test Safety Alert',
      body: 'This is a test safety notification. Your settings are working!',
      category: 'Extreme',
      priority: 'safety',
    );

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Test safety alert sent')));
  }

  Future<void> _sendTestActivityAlert() async {
    await _notificationService.sendTestNotification(
      title: '🚣 Test Activity Alert',
      body:
          'Perfect kayaking conditions detected! This is a test notification.',
      category: 'Normal',
      priority: 'activity',
    );

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Test activity alert sent')));
  }

  void _openThresholdSettings() {
    // TODO: Navigate to threshold management page
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Custom threshold settings coming soon')),
    );
  }

  void _resetToDefaults() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Reset Settings'),
            content: const Text(
              'This will restore all notification settings to their default values. Are you sure?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _performReset();
                },
                child: const Text('Reset'),
              ),
            ],
          ),
    );
  }

  Future<void> _performReset() async {
    setState(() {
      _notificationsEnabled = true;
      _safetyAlerts = true;
      _activityAlerts = true;
      _informationAlerts = false;
      _quietHoursEnabled = false;
      _quietHoursStart = const TimeOfDay(hour: 22, minute: 0);
      _quietHoursEnd = const TimeOfDay(hour: 7, minute: 0);
      _notificationFrequency = 'realtime';
      _soundEnabled = true;
      _vibrationEnabled = true;
    });

    await _saveSettings();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Settings reset to defaults')));
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}
