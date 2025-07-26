// lib/features/settings/presentation/pages/notification_settings_page.dart
// Simplified notification settings page - single toggle only

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/services/notification_service.dart';
import '../widgets/settings_card.dart';

/// Simplified notification settings page with single toggle
class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final NotificationService _notificationService = NotificationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Single setting state
  bool _notificationsEnabled = true;
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
      appBar: AppBar(title: const Text('Notification Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMainToggleSection(),
          const SizedBox(height: 24),
          _buildInfoSection(),
        ],
      ),
      bottomNavigationBar: _isSaving ? const LinearProgressIndicator() : null,
    );
  }

  Widget _buildMainToggleSection() {
    return SettingsCard(
      title: 'Flow Notifications',
      subtitle: 'Get alerts when your favorite rivers cross flow thresholds',
      children: [
        CustomSwitchListTile(
          title: 'Enable Notifications',
          subtitle:
              _notificationsEnabled
                  ? 'You\'ll receive alerts for favorite rivers'
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

  Widget _buildInfoSection() {
    if (!_notificationsEnabled) return const SizedBox.shrink();

    return SettingsCard(
      title: 'How It Works',
      children: [
        const ListTile(
          leading: Icon(Icons.favorite, color: Colors.red),
          title: Text('Favorites Only'),
          subtitle: Text(
            'Notifications are sent only for rivers in your favorites',
          ),
        ),
        const ListTile(
          leading: Icon(Icons.trending_up, color: Colors.orange),
          title: Text('Threshold Alerts'),
          subtitle: Text(
            'Get notified when forecasts exceed return period levels',
          ),
        ),
        const ListTile(
          leading: Icon(Icons.schedule, color: Colors.green),
          title: Text('Smart Timing'),
          subtitle: Text(
            'Checks short and medium range forecasts automatically',
          ),
        ),
      ],
    );
  }

  // Event handlers

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
      final user = _auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Load from Firestore users collection
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        setState(() {
          _notificationsEnabled = userData?['notificationsEnabled'] ?? true;
          _isLoading = false;
        });
      } else {
        // Create user document with default settings
        await _createUserDocument();
        setState(() {
          _notificationsEnabled = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Save to Firestore users collection (required by cloud function)
      await _firestore.collection('users').doc(user.uid).set({
        'notificationsEnabled': _notificationsEnabled,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Also update FCM token if we have one
      final fcmToken = _notificationService.fcmToken;
      if (fcmToken != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': fcmToken,
          'tokenUpdatedAt': FieldValue.serverTimestamp(),
        });
      }

      debugPrint('✅ Notification settings saved to Firestore');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _notificationsEnabled
                  ? 'Notifications enabled for your favorite rivers'
                  : 'Notifications disabled',
            ),
          ),
        );
      }
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

  Future<void> _createUserDocument() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('users').doc(user.uid).set({
        'notificationsEnabled': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ User document created');
    } catch (e) {
      debugPrint('❌ Error creating user document: $e');
    }
  }
}
