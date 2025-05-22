import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rivr/core/services/flow_units_service.dart';
import 'package:rivr/features/auth/domain/entities/user.dart';
import 'package:rivr/features/forecast/presentation/widgets/unit_selector_widget.dart';
import 'package:rivr/features/settings/presentation/pages/theme_settings_page.dart';
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

  void _toggleSection(String section) {
    setState(() {
      _expandedSections[section] = !(_expandedSections[section] ?? false);
    });
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
            currentAccountPicture: CircleAvatar(
              backgroundColor: colors.secondary,
              child: Icon(Icons.person, size: 40, color: colors.onSecondary),
            ),
            accountName: Text(
              user?.firstName ?? 'River Enthusiast',
              style: textTheme.titleMedium?.copyWith(
                color: colors.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            accountEmail: Text(
              user?.email ?? 'user@example.com',
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onPrimary.withOpacity(0.8),
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

                // Notifications & Alerts Section (Expandable)
                ExpansionTile(
                  initiallyExpanded:
                      _expandedSections['notifications'] ?? false,
                  onExpansionChanged:
                      (expanded) => _toggleSection('notifications'),
                  leading: Icon(
                    Icons.notifications_none,
                    color: colors.primary,
                  ),
                  title: Text(
                    'Notifications & Alerts',
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
                      title: Text('Flow Level Notifications'),
                      trailing: Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Flow notifications coming soon'),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                // Data Management Section (Expandable)
                ExpansionTile(
                  initiallyExpanded: _expandedSections['data'] ?? false,
                  onExpansionChanged: (expanded) => _toggleSection('data'),
                  leading: Icon(Icons.storage, color: colors.primary),
                  title: Text(
                    'Data Management',
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
                      title: Text('Clear Cache'),
                      trailing: Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cache clearing coming soon'),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                // Help & Information Section (Expandable)
                ExpansionTile(
                  initiallyExpanded: _expandedSections['help'] ?? false,
                  onExpansionChanged: (expanded) => _toggleSection('help'),
                  leading: Icon(Icons.help_outline, color: colors.primary),
                  title: Text(
                    'Help & Information',
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
                      title: Text('About the App'),
                      trailing: Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('About page coming soon'),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      contentPadding: const EdgeInsets.only(
                        left: 72,
                        right: 16,
                      ),
                      title: Text('Data Sources'),
                      trailing: Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Data sources info coming soon'),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                // Feedback & Support Section (Expandable)
                ExpansionTile(
                  initiallyExpanded: _expandedSections['feedback'] ?? false,
                  onExpansionChanged: (expanded) => _toggleSection('feedback'),
                  leading: Icon(Icons.feedback_outlined, color: colors.primary),
                  title: Text(
                    'Feedback & Support',
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
                      title: Text('Report a Bug'),
                      trailing: Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Bug reporting coming soon'),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      contentPadding: const EdgeInsets.only(
                        left: 72,
                        right: 16,
                      ),
                      title: Text('Feature Requests'),
                      trailing: Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Feature requests coming soon'),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      contentPadding: const EdgeInsets.only(
                        left: 72,
                        right: 16,
                      ),
                      title: Text('Contact Developers'),
                      trailing: Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Contact form coming soon'),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                // Log Out Button (Always visible)
                Divider(),
                ListTile(
                  leading: Icon(Icons.exit_to_app, color: colors.error),
                  title: Text(
                    'Log Out',
                    style: TextStyle(
                      color: colors.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: widget.onLogout,
                ),
                ListTile(
                  leading: Icon(Icons.bug_report, color: colors.error),
                  title: Text('Debug User'),
                  onTap: _debugUser,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getUserDisplayName(User? user) {
    if (user == null) return 'River Enthusiast';

    // Try firstName first
    if (user.firstName != null && user.firstName!.trim().isNotEmpty) {
      return user.firstName!.trim();
    }

    // Fallback to email username
    if (user.email.isNotEmpty) {
      final emailParts = user.email.split('@');
      if (emailParts.isNotEmpty) {
        final username = emailParts[0];
        // Capitalize first letter
        return username.isEmpty
            ? 'River Enthusiast'
            : '${username[0].toUpperCase()}${username.substring(1)}';
      }
    }

    return 'River Enthusiast';
  }

  void _debugUser() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    print('=== USER DEBUG ===');
    print('User exists: ${user != null}');
    if (user != null) {
      print('UID: ${user.uid}');
      print('Email: ${user.email}');
      print(
        'FirstName: "${user.firstName}" (${user.firstName?.length ?? 0} chars)',
      );
      print(
        'LastName: "${user.lastName}" (${user.lastName?.length ?? 0} chars)',
      );
      print(
        'Profession: "${user.profession}" (${user.profession?.length ?? 0} chars)',
      );
    }
    print('==================');
  }
}
