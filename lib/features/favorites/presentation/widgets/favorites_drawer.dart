// lib/features/favorites/presentation/widgets/favorites_drawer.dart
// Updated to work with simplified notification system

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:rivr/core/services/flow_units_service.dart';
import 'package:rivr/features/forecast/presentation/widgets/unit_selector_widget.dart';
import 'package:rivr/features/settings/presentation/pages/theme_settings_page.dart';
import 'package:rivr/features/settings/presentation/pages/notification_settings_page.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';

class FavoritesDrawer extends StatefulWidget {
  final Function() onLogout;

  const FavoritesDrawer({super.key, required this.onLogout});

  @override
  State<FavoritesDrawer> createState() => _FavoritesDrawerState();
}

class _FavoritesDrawerState extends State<FavoritesDrawer> {
  // Track which sections are expanded
  final Map<String, bool> _expandedSections = {
    'measurement': false,
    'notifications': false,
    'data': false,
    'help': false,
    'feedback': false,
  };

  // Track notification status
  bool _notificationsEnabled = false;
  bool _isLoadingNotificationStatus = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationStatus();
  }

  void _toggleSection(String section) {
    setState(() {
      _expandedSections[section] = !(_expandedSections[section] ?? false);
    });
  }

  Future<void> _loadNotificationStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      debugPrint('🔔 Loading notification status for user: ${user?.uid}');

      if (user != null) {
        final userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();

        debugPrint('🔔 User document exists: ${userDoc.exists}');

        if (userDoc.exists) {
          final userData = userDoc.data();
          final notificationStatus = userData?['notificationsEnabled'] ?? false;
          debugPrint(
            '🔔 Notification status from Firestore: $notificationStatus',
          );

          setState(() {
            _notificationsEnabled = notificationStatus;
            _isLoadingNotificationStatus = false;
          });
        } else {
          debugPrint('🔔 User document does not exist, defaulting to false');
          setState(() {
            _notificationsEnabled = false;
            _isLoadingNotificationStatus = false;
          });
        }
      } else {
        debugPrint('🔔 No authenticated user found');
        setState(() {
          _notificationsEnabled = false;
          _isLoadingNotificationStatus = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading notification status: $e');
      setState(() {
        _notificationsEnabled = false;
        _isLoadingNotificationStatus = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    // Get user from AuthProvider for profile display
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return Drawer(
      child: Column(
        children: [
          // Static User Profile Header
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: colors.primary),
            currentAccountPicture: null,
            accountName: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.firstName ?? 'River',
                  style: textTheme.titleLarge?.copyWith(
                    color: colors.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  user?.lastName ?? 'Enthusiast',
                  style: textTheme.titleLarge?.copyWith(
                    color: colors.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            accountEmail: Text(
              user?.profession ?? 'River Explorer',
              style: textTheme.titleMedium?.copyWith(
                color: colors.onPrimary.withValues(alpha: 0.8),
              ),
            ),
          ),

          // Scrollable Content Area with Expandable Sections
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Measurement & Display Section (Expandable)
                ExpansionTile(
                  initiallyExpanded: _expandedSections['measurement'] ?? false,
                  onExpansionChanged:
                      (expanded) => _toggleSection('measurement'),
                  leading: Icon(Icons.straighten, color: colors.primary),
                  title: Text(
                    'Units & Theme',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.only(
                        left: 72,
                        right: 16,
                      ),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Units'),
                          Consumer<FlowUnitsService>(
                            builder:
                                (
                                  context,
                                  unitsService,
                                  _,
                                ) => UnitSelectorWidget(
                                  useDropdown: false,
                                  onUnitChanged: (unit) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Flow units changed to ${unit.shortName}',
                                        ),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                ),
                          ),
                        ],
                      ),
                    ),
                    ListTile(
                      contentPadding: const EdgeInsets.only(
                        left: 72,
                        right: 16,
                      ),
                      title: Text('Theme Settings'),
                      trailing: Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const ThemeSettingsPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                // ── Flow Notifications Section ──────────────────────────
                ExpansionTile(
                  initiallyExpanded:
                      _expandedSections['notifications'] ?? false,
                  onExpansionChanged:
                      (expanded) => _toggleSection('notifications'),
                  leading: Icon(
                    _notificationsEnabled
                        ? Icons.notifications
                        : Icons.notifications_off,
                    color:
                        _notificationsEnabled ? colors.primary : colors.outline,
                  ),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Flow Notifications',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_isLoadingNotificationStatus)
                        Text(
                          'Loading...',
                          style: textTheme.labelSmall?.copyWith(
                            color: colors.onSurface.withOpacity(0.6),
                          ),
                        )
                      else
                        Text(
                          _notificationsEnabled ? 'Enabled' : 'Disabled',
                          style: textTheme.labelSmall?.copyWith(
                            color:
                                _notificationsEnabled
                                    ? Colors.green
                                    : colors.onSurface.withOpacity(0.6),
                            fontWeight:
                                _notificationsEnabled
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                          ),
                        ),
                    ],
                  ),
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.only(
                        left: 72,
                        right: 16,
                      ),
                      leading: Icon(
                        Icons.settings,
                        color: colors.primary,
                        size: 20,
                      ),
                      title: Text('Notification Settings'),
                      subtitle: Text(
                        'Configure alerts for your favorite rivers',
                      ),
                      trailing: Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () async {
                        // Navigate to notification settings
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (context) => const NotificationSettingsPage(),
                          ),
                        );

                        // Always reload status when returning from settings
                        _loadNotificationStatus();
                      },
                    ),
                    ListTile(
                      contentPadding: const EdgeInsets.only(
                        left: 72,
                        right: 16,
                      ),
                      leading: Icon(
                        Icons.info_outline,
                        color: colors.outline,
                        size: 20,
                      ),
                      title: Text('How It Works'),
                      subtitle: Text(
                        'Alerts when forecasts exceed return periods',
                      ),
                      onTap: () {
                        _showHowItWorksDialog();
                      },
                    ),
                  ],
                ),

                // ── Data Management Section ────────────────────────────────
                ExpansionTile(
                  initiallyExpanded: _expandedSections['data'] ?? false,
                  onExpansionChanged: (expanded) => _toggleSection('data'),
                  leading: Icon(Icons.storage, color: colors.primary),
                  title: Text(
                    'Data & Offline',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.only(
                        left: 72,
                        right: 16,
                      ),
                      title: Text('Offline Manager'),
                      trailing: Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.of(context).pushNamed('/offline_manager');
                      },
                    ),
                  ],
                ),

                // ── Help & Support Section ────────────────────────────────
                ExpansionTile(
                  initiallyExpanded: _expandedSections['help'] ?? false,
                  onExpansionChanged: (expanded) => _toggleSection('help'),
                  leading: Icon(Icons.help_outline, color: colors.primary),
                  title: Text(
                    'Help & Support',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.only(
                        left: 72,
                        right: 16,
                      ),
                      title: Text('User Guide'),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('User guide coming soon'),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                // ── Feedback Section ───────────────────────────────────────
                ExpansionTile(
                  initiallyExpanded: _expandedSections['feedback'] ?? false,
                  onExpansionChanged: (expanded) => _toggleSection('feedback'),
                  leading: Icon(Icons.feedback, color: colors.primary),
                  title: Text(
                    'Feedback',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.only(
                        left: 72,
                        right: 16,
                      ),
                      title: Text('Send Feedback'),
                      onTap: () async {
                        final Uri emailUri = Uri(
                          scheme: 'mailto',
                          path: 'feedback@rivr.app',
                          query: 'subject=Rivr App Feedback',
                        );
                        if (await canLaunchUrl(emailUri)) {
                          await launchUrl(emailUri);
                        }
                      },
                    ),
                  ],
                ),

                const Divider(),

                // Static Auth Section
                ListTile(
                  leading: Icon(Icons.logout, color: colors.error),
                  title: Text(
                    'Sign Out',
                    style: textTheme.titleSmall?.copyWith(
                      color: colors.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: widget.onLogout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showHowItWorksDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('How Flow Notifications Work'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  '🎯',
                  'Favorites Only',
                  'Notifications are sent only for rivers in your favorites list',
                ),
                SizedBox(height: 12),
                _buildInfoRow(
                  '📊',
                  'Return Period Alerts',
                  'Get notified when forecasts exceed return period thresholds',
                ),
                SizedBox(height: 12),
                _buildInfoRow(
                  '⏰',
                  'Smart Timing',
                  'Automatically checks short and medium range forecasts',
                ),
                SizedBox(height: 12),
                _buildInfoRow(
                  '📱',
                  'Background Monitoring',
                  'Works even when the app is closed',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Got it'),
              ),
            ],
          ),
    );
  }

  Widget _buildInfoRow(String emoji, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: TextStyle(fontSize: 16)),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                description,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
