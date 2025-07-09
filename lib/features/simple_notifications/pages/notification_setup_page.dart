// lib/features/simple_notifications/pages/notification_setup_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:rivr/features/simple_notifications/dummy_rivers/pages/dummy_rivers_page.dart';

import '../models/notification_preferences.dart';
import '../services/simple_notification_service.dart';
import '../services/favorites_integration_service.dart';
import '../dummy_rivers/providers/dummy_rivers_provider.dart';
import '../dummy_rivers/models/dummy_river.dart';

/// Simple notification setup page accessed from favorites drawer
/// Allows users to enable notifications and select which rivers to monitor
class NotificationSetupPage extends StatefulWidget {
  const NotificationSetupPage({super.key});

  @override
  State<NotificationSetupPage> createState() => _NotificationSetupPageState();
}

class _NotificationSetupPageState extends State<NotificationSetupPage> {
  final SimpleNotificationService _notificationService =
      SimpleNotificationService();
  final FavoritesIntegrationService _favoritesService =
      FavoritesIntegrationService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // State variables
  bool _isLoading = true;
  bool _isSaving = false;
  String? _userId;
  NotificationPreferences? _preferences;
  List<FavoriteRiver> _favoriteRivers = [];
  List<DummyRiver> _dummyRivers = [];
  Set<String> _selectedRiverIds = {};

  // Settings
  bool _notificationsEnabled = false;
  bool _shortRangeEnabled = true;
  bool _mediumRangeEnabled = true;
  bool _quietHoursEnabled = false;
  TimeOfDay _quietTimeStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietTimeEnd = const TimeOfDay(hour: 7, minute: 0);

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  Future<void> _initializePage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    _userId = user.uid;

    try {
      // Initialize notification service
      await _notificationService.initialize();

      // Load existing preferences
      await _loadPreferences();

      // Load user's favorite rivers
      await _loadFavoriteRivers();

      // Load dummy rivers
      await _loadDummyRivers();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error initializing notification setup: $e');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading notification settings: $e')),
        );
      }
    }
  }

  Future<void> _loadPreferences() async {
    if (_userId == null) return;

    try {
      final doc =
          await _firestore
              .collection('simpleNotificationPreferences')
              .doc(_userId!)
              .get();

      if (doc.exists) {
        _preferences = NotificationPreferences.fromFirestore(doc);

        // Debug: Print what we loaded from Firestore
        debugPrint('🔍 Loaded from Firestore:');
        debugPrint('  quietHourStart: ${_preferences!.quietHourStart}');
        debugPrint('  quietMinuteStart: ${_preferences!.quietMinuteStart}');
        debugPrint('  quietHourEnd: ${_preferences!.quietHourEnd}');
        debugPrint('  quietMinuteEnd: ${_preferences!.quietMinuteEnd}');

        setState(() {
          _notificationsEnabled = _preferences!.enabled;
          _selectedRiverIds = Set.from(_preferences!.monitoredRiverIds);
          _shortRangeEnabled = _preferences!.includeShortRange;
          _mediumRangeEnabled = _preferences!.includeMediumRange;
          _quietHoursEnabled = _preferences!.quietHoursEnabled;
          // Convert int hours and minutes to TimeOfDay objects
          _quietTimeStart = TimeOfDay(
            hour: _preferences!.quietHourStart,
            minute: _preferences!.quietMinuteStart,
          );
          _quietTimeEnd = TimeOfDay(
            hour: _preferences!.quietHourEnd,
            minute: _preferences!.quietMinuteEnd,
          );

          // Debug: Print what TimeOfDay objects we created
          debugPrint('🕐 Created TimeOfDay objects:');
          debugPrint('  _quietTimeStart: ${_quietTimeStart.format(context)}');
          debugPrint('  _quietTimeEnd: ${_quietTimeEnd.format(context)}');
        });
      } else {
        // Create default preferences
        _preferences = NotificationPreferences.defaultPreferences(_userId!);
      }
    } catch (e) {
      debugPrint('❌ Error loading preferences: $e');
    }
  }

  Future<void> _loadFavoriteRivers() async {
    if (_userId == null) return;

    try {
      final favorites = await _favoritesService.getUserFavoriteRivers(_userId!);
      setState(() {
        _favoriteRivers =
            favorites.where((river) => river.isValidForNotifications).toList();
      });
    } catch (e) {
      debugPrint('❌ Error loading favorite rivers: $e');
    }
  }

  Future<void> _loadDummyRivers() async {
    try {
      final dummyRiversProvider = context.read<DummyRiversProvider>();
      await dummyRiversProvider.loadDummyRivers();

      setState(() {
        _dummyRivers = dummyRiversProvider.rivers;
      });
    } catch (e) {
      // Dummy rivers provider might not be available - that's okay
      debugPrint('ℹ️ Dummy rivers not available: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Flow Notifications')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flow Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
            tooltip: 'Help',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeaderSection(),
          const SizedBox(height: 24),
          _buildMainToggleSection(),
          if (_notificationsEnabled) ...[
            const SizedBox(height: 24),
            _buildRiverSelectionSection(),
            const SizedBox(height: 24),
            _buildForecastRangeSection(),
            const SizedBox(height: 24),
            _buildQuietHoursSection(),
            const SizedBox(height: 24),
            _buildTestSection(),
          ],
          const SizedBox(height: 24),
          _buildSaveButton(),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.notifications_active,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                const Text(
                  'River Flow Notifications',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Get notified when your favorite rivers reach significant flow levels '
              '(return periods). Monitors short and medium range forecasts only.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainToggleSection() {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Enable Flow Notifications'),
            subtitle: Text(
              _notificationsEnabled
                  ? 'Notifications are enabled'
                  : 'Tap to enable notifications',
            ),
            value: _notificationsEnabled,
            onChanged: _onMainToggleChanged,
          ),
          if (!_notificationService.isReady && _notificationsEnabled)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange.shade600),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Notification permission required. Tap to request permission.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: _requestPermissions,
                    child: const Text('Enable'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRiverSelectionSection() {
    final totalRivers = _favoriteRivers.length + _dummyRivers.length;

    if (totalRivers == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade600, size: 48),
              const SizedBox(height: 8),
              const Text(
                'No Rivers Available',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Add rivers to your favorites or create dummy rivers for testing.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go to Favorites'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Rivers to Monitor',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose which rivers to monitor for flow alerts:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),

            // Favorite Rivers Section
            if (_favoriteRivers.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.favorite, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Favorite Rivers',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...List.generate(_favoriteRivers.length, (index) {
                final river = _favoriteRivers[index];
                final isSelected = _selectedRiverIds.contains(river.riverId);

                return CheckboxListTile(
                  title: Text(river.riverName),
                  subtitle:
                      river.location != null
                          ? Text(
                            river.location!,
                            style: const TextStyle(fontSize: 12),
                          )
                          : null,
                  value: isSelected,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedRiverIds.add(river.riverId);
                      } else {
                        _selectedRiverIds.remove(river.riverId);
                      }
                    });
                  },
                  dense: true,
                );
              }),
            ],

            // Dummy Rivers Section
            if (_dummyRivers.isNotEmpty) ...[
              if (_favoriteRivers.isNotEmpty) const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.science, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Test Rivers',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'TESTING',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...List.generate(_dummyRivers.length, (index) {
                final river = _dummyRivers[index];
                final isSelected = _selectedRiverIds.contains(river.id);

                return CheckboxListTile(
                  title: Row(
                    children: [
                      Expanded(child: Text(river.name)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          river.unit.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color:
                                Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (river.description.isNotEmpty)
                        Text(
                          river.description,
                          style: const TextStyle(fontSize: 11),
                        ),
                      Text(
                        '${river.returnPeriods.length} return period${river.returnPeriods.length == 1 ? '' : 's'}',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  value: isSelected,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedRiverIds.add(river.id);
                      } else {
                        _selectedRiverIds.remove(river.id);
                      }
                    });
                  },
                  dense: true,
                );
              }),
            ],

            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: _selectAllRivers,
                  child: const Text('Select All'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _deselectAllRivers,
                  child: const Text('Select None'),
                ),
                const Spacer(),
                if (_dummyRivers.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _navigateToDummyRivers(),
                    icon: const Icon(Icons.science, size: 16),
                    label: const Text('Manage'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForecastRangeSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Forecast Range',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              title: const Text('Short Range (0-18 hours)'),
              subtitle: const Text('Most accurate forecasts'),
              value: _shortRangeEnabled,
              onChanged: (value) {
                setState(() {
                  _shortRangeEnabled = value ?? true;
                });
              },
              dense: true,
            ),
            CheckboxListTile(
              title: const Text('Medium Range (2-10 days)'),
              subtitle: const Text('Extended forecasts'),
              value: _mediumRangeEnabled,
              onChanged: (value) {
                setState(() {
                  _mediumRangeEnabled = value ?? true;
                });
              },
              dense: true,
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
            SwitchListTile(
              title: const Text('Quiet Hours'),
              subtitle: const Text('Disable notifications during these hours'),
              value: _quietHoursEnabled,
              onChanged: (value) {
                setState(() {
                  _quietHoursEnabled = value;
                });
              },
              dense: true,
            ),
            if (_quietHoursEnabled) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: const Text('Start'),
                      subtitle: Text(_quietTimeStart.format(context)),
                      onTap: () => _selectQuietHour(true),
                      dense: true,
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: const Text('End'),
                      subtitle: Text(_quietTimeEnd.format(context)),
                      onTap: () => _selectQuietHour(false),
                      dense: true,
                    ),
                  ),
                ],
              ),
            ],
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
            const Text(
              'Test Notifications',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Send a test notification to make sure everything is working:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    _selectedRiverIds.isNotEmpty ? _sendTestNotification : null,
                icon: const Icon(Icons.send),
                label: const Text('Send Test Notification'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _savePreferences,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child:
            _isSaving
                ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : const Text('Save Settings'),
      ),
    );
  }

  // Event handlers

  void _onMainToggleChanged(bool value) async {
    if (value && !_notificationService.isReady) {
      // Request permissions first
      final granted = await _requestPermissions();
      if (!granted) return;
    }

    setState(() {
      _notificationsEnabled = value;
    });
  }

  Future<bool> _requestPermissions() async {
    final granted = await _notificationService.requestPermissions();

    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification permission is required for flow alerts'),
        ),
      );
    }

    return granted;
  }

  void _selectAllRivers() {
    setState(() {
      _selectedRiverIds = <String>{
        ..._favoriteRivers.map((r) => r.riverId),
        ..._dummyRivers.map((r) => r.id),
      };
    });
  }

  void _deselectAllRivers() {
    setState(() {
      _selectedRiverIds.clear();
    });
  }

  void _navigateToDummyRivers() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const DummyRiversPage()));
  }

  Future<void> _selectQuietHour(bool isStart) async {
    final time = await showTimePicker(
      context: context,
      initialTime: isStart ? _quietTimeStart : _quietTimeEnd,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (time != null) {
      setState(() {
        if (isStart) {
          _quietTimeStart = time;
        } else {
          _quietTimeEnd = time;
        }
      });
    }
  }

  Future<void> _sendTestNotification() async {
    if (_selectedRiverIds.isEmpty) return;

    try {
      final firstRiverId = _selectedRiverIds.first;

      // Check if it's a favorite river or dummy river
      String riverName;
      final favoriteRiver =
          _favoriteRivers.where((r) => r.riverId == firstRiverId).firstOrNull;
      final dummyRiver =
          _dummyRivers.where((r) => r.id == firstRiverId).firstOrNull;

      if (favoriteRiver != null) {
        riverName = favoriteRiver.riverName;
      } else if (dummyRiver != null) {
        riverName = '${dummyRiver.name} (Test)';
      } else {
        riverName = 'Selected River';
      }

      final success = await _notificationService.sendTestNotification(
        riverName: riverName,
        testType: 'flow alert',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Test notification sent!'
                  : 'Failed to send test notification',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sending test: $e')));
      }
    }
  }

  Future<void> _savePreferences() async {
    if (_userId == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // Debug: Print what we're about to save
      debugPrint('💾 Saving preferences:');
      debugPrint(
        '  _quietTimeStart: ${_quietTimeStart.format(context)} (hour: ${_quietTimeStart.hour}, minute: ${_quietTimeStart.minute})',
      );
      debugPrint(
        '  _quietTimeEnd: ${_quietTimeEnd.format(context)} (hour: ${_quietTimeEnd.hour}, minute: ${_quietTimeEnd.minute})',
      );

      final updatedPreferences = (_preferences ??
              NotificationPreferences.defaultPreferences(_userId!))
          .copyWith(
            enabled: _notificationsEnabled,
            monitoredRiverIds: _selectedRiverIds.toList(),
            includeShortRange: _shortRangeEnabled,
            includeMediumRange: _mediumRangeEnabled,
            quietHoursEnabled: _quietHoursEnabled,
            // Convert TimeOfDay to separate int hours and minutes for storage
            quietHourStart: _quietTimeStart.hour,
            quietMinuteStart: _quietTimeStart.minute,
            quietHourEnd: _quietTimeEnd.hour,
            quietMinuteEnd: _quietTimeEnd.minute,
            updatedAt: DateTime.now(),
          );

      // Debug: Print what the model will save to Firestore
      debugPrint('📄 Model data to save:');
      debugPrint('  quietHourStart: ${updatedPreferences.quietHourStart}');
      debugPrint('  quietMinuteStart: ${updatedPreferences.quietMinuteStart}');
      debugPrint('  quietHourEnd: ${updatedPreferences.quietHourEnd}');
      debugPrint('  quietMinuteEnd: ${updatedPreferences.quietMinuteEnd}');

      await _firestore
          .collection('simpleNotificationPreferences')
          .doc(_userId!)
          .set(updatedPreferences.toFirestore());

      _preferences = updatedPreferences;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification settings saved!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving settings: $e')));
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Flow Notifications Help'),
            content: const Text(
              'This feature monitors your favorite rivers and sends notifications when '
              'forecasted flow levels match significant return periods (2, 5, 10, 25, 50, 100 years).\n\n'
              '• Only short and medium range forecasts are monitored\n'
              '• Return periods indicate statistical flood frequency\n'
              '• Higher return periods mean more significant flows\n'
              '• Notifications work even when the app is closed\n\n'
              'Test rivers are for development purposes only and should not be used in production.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Got it'),
              ),
            ],
          ),
    );
  }
}
