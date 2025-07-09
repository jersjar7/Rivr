import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rivr/core/services/flow_units_service.dart';
import 'package:rivr/features/favorites/presentation/widgets/quick_notigication_test.dart';
import 'package:rivr/features/forecast/presentation/widgets/unit_selector_widget.dart';
import 'package:rivr/features/settings/presentation/pages/theme_settings_page.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../core/navigation/app_router.dart';

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

                // ── Enhanced Notifications & Alerts Section ──────────────────────────
                ExpansionTile(
                  initiallyExpanded:
                      _expandedSections['notifications'] ?? false,
                  onExpansionChanged:
                      (expanded) => _toggleSection('notifications'),
                  leading: Icon(
                    Icons.notifications_active,
                    color: colors.primary,
                  ),

                  // Title with Demo Mode badge
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Notifications & Alerts',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // Container(
                      //   padding: const EdgeInsets.symmetric(
                      //     horizontal: 8,
                      //     vertical: 2,
                      //   ),
                      //   decoration: BoxDecoration(
                      //     color: Colors.green.shade100,
                      //     borderRadius: BorderRadius.circular(12),
                      //     border: Border.all(color: Colors.green.shade300),
                      //   ),
                      //   child: Row(
                      //     mainAxisSize: MainAxisSize.min,
                      //     children: [
                      //       Icon(
                      //         Icons.circle,
                      //         color: Colors.green.shade600,
                      //         size: 8,
                      //       ),
                      //       const SizedBox(width: 4),
                      //       Text(
                      //         'Demo Ready',
                      //         style: textTheme.labelSmall?.copyWith(
                      //           color: Colors.green.shade700,
                      //           fontWeight: FontWeight.w600,
                      //         ),
                      //       ),
                      //     ],
                      //   ),
                      // ),
                    ],
                  ),

                  // Enhanced children with working functionality
                  children: [
                    // 1. Notification Settings - WORKING ✅
                    ListTile(
                      contentPadding: const EdgeInsets.only(
                        left: 72,
                        right: 16,
                      ),
                      leading: Icon(
                        Icons.check_circle,
                        color: Colors.green.shade600,
                        size: 20,
                      ),
                      title: const Text('Notification Settings'),
                      subtitle: const Text('Configure alerts & preferences'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        AppRouter.navigateToNotificationSettings(context);
                      },
                    ),

                    // 2. Notification History - WORKING ✅
                    ListTile(
                      contentPadding: const EdgeInsets.only(
                        left: 72,
                        right: 16,
                      ),
                      leading: Icon(
                        Icons.check_circle,
                        color: Colors.green.shade600,
                        size: 20,
                      ),
                      title: const Text('Notification History'),
                      subtitle: const Text('View recent alerts'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Test',
                              style: textTheme.labelSmall?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_ios, size: 16),
                        ],
                      ),
                      onTap: () {
                        AppRouter.navigateToNotificationHistory(context);
                      },
                    ),

                    // 3. Quick Alert Demo - IN DEVELOPMENT 🚧
                    ListTile(
                      contentPadding: const EdgeInsets.only(
                        left: 72,
                        right: 16,
                      ),
                      leading: Icon(
                        Icons.construction,
                        color: Colors.orange.shade600,
                        size: 20,
                      ),
                      title: const Text('Quick Alert Setup'),
                      subtitle: const Text('Demo: Custom threshold alerts'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        // TODO: Create quick_alert_demo_page.dart
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Quick Alert Setup - Coming in next development phase',
                            ),
                            backgroundColor: Colors.orange.shade600,
                            action: SnackBarAction(
                              label: 'OK',
                              textColor: Colors.white,
                              onPressed: () {},
                            ),
                          ),
                        );
                      },
                    ),

                    // 4. Test Notifications - WORKING ✅
                    ListTile(
                      contentPadding: const EdgeInsets.only(
                        left: 72,
                        right: 16,
                      ),
                      leading: Icon(
                        Icons.check_circle,
                        color: Colors.green.shade600,
                        size: 20,
                      ),
                      title: const Text('Test Notifications'),
                      subtitle: const Text('Send demo alerts'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.science, color: colors.primary, size: 16),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_ios, size: 16),
                        ],
                      ),
                      onTap: () {
                        AppRouter.navigateToNotificationTest(context);
                      },
                    ),

                    // // Progress Summary
                    // Container(
                    //   margin: const EdgeInsets.only(
                    //     left: 72,
                    //     right: 16,
                    //     top: 8,
                    //     bottom: 4,
                    //   ),
                    //   padding: const EdgeInsets.all(8),
                    //   decoration: BoxDecoration(
                    //     color: colors.primary.withOpacity(0.05),
                    //     borderRadius: BorderRadius.circular(8),
                    //     border: Border.all(
                    //       color: colors.primary.withOpacity(0.2),
                    //     ),
                    //   ),
                    //   child: Row(
                    //     children: [
                    //       Icon(
                    //         Icons.info_outline,
                    //         color: colors.primary,
                    //         size: 16,
                    //       ),
                    //       const SizedBox(width: 8),
                    //       Expanded(
                    //         child: Text(
                    //           'Thesis Progress: 3 features working • 1 in development',
                    //           style: textTheme.labelSmall?.copyWith(
                    //             color: colors.primary,
                    //             fontWeight: FontWeight.w500,
                    //           ),
                    //         ),
                    //       ),
                    //     ],
                    //   ),
                    // ),
                  ],
                ),

                // ── Data Management Section ────────────────────────────────
                ExpansionTile(
                  initiallyExpanded: _expandedSections['data'] ?? false,
                  onExpansionChanged: (expanded) => _toggleSection('data'),
                  leading: Icon(Icons.storage, color: colors.primary),

                  // Title + "Coming Soon"
                  title: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Data Management',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Coming Soon',
                        style: textTheme.labelSmall?.copyWith(
                          color: colors.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),

                  // Inert "Clear Cache" tile
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.only(
                        left: 72,
                        right: 16,
                      ),
                      title: Text('Clear Cache'),
                      // no trailing arrow, no onTap
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

                // Development Tools (Debug Mode Only)
                if (kDebugMode) ...[
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.code,
                                color: Colors.grey.shade600,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Development Tools',
                                style: textTheme.labelSmall?.copyWith(
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        const QuickNotificationTest(),
                      ],
                    ),
                  ),
                ],

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
}
