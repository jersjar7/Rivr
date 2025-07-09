import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rivr/core/services/flow_units_service.dart';
import 'package:rivr/features/forecast/presentation/widgets/unit_selector_widget.dart';
import 'package:rivr/features/settings/presentation/pages/theme_settings_page.dart';
import 'package:rivr/features/simple_notifications/dummy_rivers/pages/dummy_rivers_page.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../core/navigation/app_router.dart';
// Remove notification widget import - using ExpansionTile instead

class FavoritesDrawer extends StatefulWidget {
  final Function() onLogout;

  const FavoritesDrawer({super.key, required this.onLogout});

  @override
  State<FavoritesDrawer> createState() => _FavoritesDrawerState();
}

class _FavoritesDrawerState extends State<FavoritesDrawer> {
  // Track which sections are expanded - add notifications back
  final Map<String, bool> _expandedSections = {
    'measurement': false,
    'notifications': false, // Added back for ExpansionTile
    'help': false,
    'feedback': false,
    // Removed 'data' - Data Management section deleted
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

            // 1) Remove the avatar
            currentAccountPicture: null,

            // 2) Two‐line name, but let the Column shrink to fit
            accountName: Column(
              mainAxisSize:
                  MainAxisSize.min, // ← key: only as tall as its children
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

            // 3) Profession in place of email
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

                // ── Flow Notifications Section (ExpansionTile) ──────────────────
                ExpansionTile(
                  initiallyExpanded:
                      _expandedSections['notifications'] ?? false,
                  onExpansionChanged:
                      (expanded) => _toggleSection('notifications'),
                  leading: Icon(
                    Icons.notifications_active,
                    color: colors.primary,
                  ),
                  title: Text(
                    'Flow Notifications',
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
                      leading: Icon(
                        Icons.settings,
                        color: colors.primary,
                        size: 20,
                      ),
                      title: Text('Setup Notifications'),

                      trailing: Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        // Close drawer
                        Navigator.of(context).pop();
                        // Navigate to notification setup
                        AppRouter.navigateToNotificationSetup(context);
                      },
                    ),
                    ListTile(
                      contentPadding: const EdgeInsets.only(
                        left: 72,
                        right: 16,
                      ),
                      leading: Icon(
                        Icons.info_outline,
                        color: colors.onSurface.withValues(alpha: 0.6),
                        size: 20,
                      ),
                      title: Text('How It Works'),
                      trailing: Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        _showNotificationInfoDialog(context);
                      },
                    ),
                    ListTile(
                      contentPadding: const EdgeInsets.only(
                        left: 72,
                        right: 16,
                      ),
                      leading: Icon(
                        Icons.science,
                        color: Colors.orange,
                        size: 20,
                      ),
                      title: Text('Dummy Rivers'),
                      subtitle: Text(
                        'Test notification system',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      trailing: Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        // Close drawer
                        Navigator.of(context).pop();
                        // Navigate to dummy rivers page
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const DummyRiversPage(),
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
                      onTap: () async {
                        final uri = Uri.parse(
                          'https://docs.ciroh.org/docuhub-staging/docs/products/Mobile%20Apps/RIVR/',
                        );
                        if (!await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        )) {
                          // optional: handle failure, e.g. show a SnackBar or log
                          print('Could not launch $uri');
                        }
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
                      title: Text('Report a Bug or\nRequest a Feature'),
                      trailing: Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () async {
                        final uri = Uri.parse(
                          'https://github.com/jersjar7/Rivr/issues',
                        );
                        if (!await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        )) {
                          // optional: handle failure, e.g. show a SnackBar or log
                          print('Could not launch $uri');
                        }
                      },
                    ),
                  ],
                ),

                // Log Out Button (Always visible)
                Divider(indent: 10, endIndent: 10),
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
                Divider(indent: 10, endIndent: 10),

                // ── SPONSORS LOGO GRID ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16.0,
                    horizontal: 24.0,
                  ),
                  child: Column(
                    children: [
                      // Row 1: single BYU SVG centered
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/img/sponsors/BYU MonogramWordmark_navy@2x.png',
                            height: 130,
                          ),
                        ],
                      ),
                      // Row 2: two logos
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Image.asset(
                            'assets/img/sponsors/NOAA-logo.png',
                            height: 80,
                          ),
                          Image.asset(
                            'assets/img/sponsors/ciroh_logo.png',
                            height: 80,
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Row 3: two more logos
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Image.asset(
                            'assets/img/sponsors/Office_of_Water_Prediction_Logo.png',
                            height: 80,
                          ),
                          Image.asset(
                            'assets/img/sponsors/University-of-Alabama-Logo.png',
                            height: 70,
                          ),
                        ],
                      ),

                      const SizedBox(height: 2),
                    ],
                  ),
                ),
                // ─────────────────────────────────────────────────────────────
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Show information dialog about how notifications work
  void _showNotificationInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.notifications_active,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                const Text('Flow Notifications'),
              ],
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How it works:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('• Add rivers to your favorites'),
                Text('• Enable notifications for selected rivers'),
                Text('• Get alerts when forecasted flows match return periods'),
                Text('• Only short & medium range forecasts monitored'),
                SizedBox(height: 12),
                Text(
                  'Return periods indicate statistical flood frequency:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text('• 2-year: Moderate flow'),
                Text('• 10-year: Major flow'),
                Text('• 50+ year: Extreme flow'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Got it'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(); // Close drawer
                  AppRouter.navigateToNotificationSetup(context);
                },
                child: const Text('Setup Now'),
              ),
            ],
          ),
    );
  }
}
