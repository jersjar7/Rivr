// lib/features/settings/presentation/pages/notification_settings_page.dart
// Clean notification settings page using reusable widgets

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/notification_service.dart';
import '../../../../core/navigation/app_router.dart';
import '../widgets/settings_card.dart';
import '../widgets/time_picker_widget.dart';

/// Clean notification settings page using modular widgets
class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final NotificationService _notificationService = NotificationService();

  // Settings state
  bool _notificationsEnabled = true;
  bool _safetyAlerts = true;
  bool _activityAlerts = true;
  bool _informationAlerts = false;
  bool _quietHoursEnabled = false;
  TimeOfDay _quietHoursStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietHoursEnd = const TimeOfDay(hour: 7, minute: 0);
  String _notificationFrequency = 'realtime';
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
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
    return SettingsCard(
      title: 'Flow Notifications',
      subtitle: 'Get alerts about river flow conditions and safety updates',
      children: [
        CustomSwitchListTile(
          title: 'Enable Notifications',
          subtitle:
              _notificationsEnabled
                  ? 'You\'ll receive flow alerts'
                  : 'All notifications are disabled',
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
    );
  }

  Widget _buildAlertTypesSection() {
    return SettingsCard(
      title: 'Alert Types',
      subtitle: 'Choose which types of alerts you want to receive',
      children: [
        CustomSwitchListTile(
          title: 'Safety Alerts',
          subtitle: 'Critical warnings about dangerous conditions',
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
        CustomSwitchListTile(
          title: 'Activity Alerts',
          subtitle: 'Notifications for your custom thresholds',
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
        CustomSwitchListTile(
          title: 'Information Updates',
          subtitle: 'General flow condition updates',
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
    );
  }

  Widget _buildFrequencySection() {
    return SettingsCard(
      title: 'Notification Frequency',
      subtitle: 'How often should we check for flow changes?',
      children: [
        CustomRadioListTile<String>(
          title: 'Real-time',
          subtitle: 'Immediate alerts when conditions change',
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
        CustomRadioListTile<String>(
          title: 'Daily Summary',
          subtitle: 'Once per day digest of conditions',
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
        CustomRadioListTile<String>(
          title: 'Weekly Summary',
          subtitle: 'Weekly overview of flow conditions',
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
    );
  }

  Widget _buildQuietHoursSection() {
    return SettingsCard(
      title: 'Quiet Hours',
      subtitle: 'Pause non-critical notifications during specific hours',
      children: [
        CustomSwitchListTile(
          title: 'Enable Quiet Hours',
          subtitle:
              _quietHoursEnabled
                  ? 'Active from ${_formatTime(_quietHoursStart)} to ${_formatTime(_quietHoursEnd)}'
                  : 'Notifications allowed all day',
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
                child: TimePickerWidget(
                  label: 'Start Time',
                  time: _quietHoursStart,
                  onTimeChanged: (time) {
                    setState(() => _quietHoursStart = time);
                    _saveSettings();
                  },
                  enabled: _notificationsEnabled,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TimePickerWidget(
                  label: 'End Time',
                  time: _quietHoursEnd,
                  onTimeChanged: (time) {
                    setState(() => _quietHoursEnd = time);
                    _saveSettings();
                  },
                  enabled: _notificationsEnabled,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InfoBanner(
            message: 'Safety alerts will still be delivered during quiet hours',
            icon: Icons.info_outline,
            color: Colors.amber,
          ),
        ],
      ],
    );
  }

  Widget _buildSoundVibrationSection() {
    return SettingsCard(
      title: 'Sound & Vibration',
      subtitle: 'Configure how notifications get your attention',
      children: [
        CustomSwitchListTile(
          title: 'Sound',
          subtitle: 'Play notification sound',
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
        CustomSwitchListTile(
          title: 'Vibration',
          subtitle: 'Vibrate for notifications',
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
    );
  }

  Widget _buildTestSection() {
    return SettingsCard(
      title: 'Test Notifications',
      subtitle: 'Send test notifications to verify your settings',
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _notificationsEnabled ? _sendTestSafetyAlert : null,
                icon: const Icon(Icons.warning),
                label: const Text('Test Safety Alert'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
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
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdvancedSection() {
    return SettingsCard(
      title: 'Advanced',
      children: [
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
    );
  }

  // Event handlers and methods

  void _onMainToggleChanged(bool value) async {
    if (value) {
      // Try to request permission when enabling notifications
      try {
        final permissionGranted =
            await _notificationService.requestPermissions();
        if (!permissionGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Notification permission is required to receive alerts',
                ),
              ),
            );
          }
          return;
        }
      } catch (e) {
        debugPrint('Permission request error: $e');
        // Continue anyway, permission might already be granted
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save settings')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _sendTestSafetyAlert() async {
    try {
      await _notificationService.sendTestNotification(
        title: '⚠️ Test Safety Alert',
        body: 'This is a test safety notification. Your settings are working!',
        category: 'Extreme',
        priority: 'safety',
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Test safety alert sent')));
      }
    } catch (e) {
      debugPrint('Test notification error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test notification failed')),
        );
      }
    }
  }

  Future<void> _sendTestActivityAlert() async {
    try {
      await _notificationService.sendTestNotification(
        title: '🚣 Test Activity Alert',
        body:
            'Perfect kayaking conditions detected! This is a test notification.',
        category: 'Normal',
        priority: 'activity',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test activity alert sent')),
        );
      }
    } catch (e) {
      debugPrint('Test notification error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test notification failed')),
        );
      }
    }
  }

  void _openThresholdSettings() {
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

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings reset to defaults')),
      );
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}
