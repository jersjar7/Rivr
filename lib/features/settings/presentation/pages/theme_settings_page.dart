// lib/features/settings/presentation/pages/theme_settings_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rivr/core/providers/theme_provider.dart';

class ThemeSettingsPage extends StatelessWidget {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Theme Settings',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colors.onPrimary,
          ),
        ),
        elevation: 0,
        backgroundColor: colors.primary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Choose Theme',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          _buildThemeOption(
            context,
            'System Default',
            'Follow system settings',
            Icons.brightness_auto,
            ThemeMode.system,
            themeProvider,
          ),
          _buildThemeOption(
            context,
            'Light',
            'Always use light theme',
            Icons.brightness_7,
            ThemeMode.light,
            themeProvider,
          ),
          _buildThemeOption(
            context,
            'Dark',
            'Always use dark theme',
            Icons.brightness_4,
            ThemeMode.dark,
            themeProvider,
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    ThemeMode mode,
    ThemeProvider provider,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isSelected = provider.themeMode == mode;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side:
            isSelected
                ? BorderSide(color: colors.primary, width: 2)
                : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => provider.setThemeMode(mode),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? colors.primary
                          : colors.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(12),
                child: Icon(
                  icon,
                  color:
                      isSelected ? colors.onPrimary : colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected) Icon(Icons.check_circle, color: colors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
