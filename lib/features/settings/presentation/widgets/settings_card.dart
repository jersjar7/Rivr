// lib/features/settings/presentation/widgets/settings_card.dart
// Reusable settings card widget for notification settings

import 'package:flutter/material.dart';

/// Reusable settings card widget
/// Provides consistent styling for settings sections
class SettingsCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  const SettingsCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!, style: const TextStyle(color: Colors.grey)),
            ],
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Custom switch list tile with enhanced styling
class CustomSwitchListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? secondary;
  final Color? activeColor;

  const CustomSwitchListTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    this.onChanged,
    this.secondary,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      value: value,
      onChanged: onChanged,
      secondary: secondary,
      activeColor: activeColor,
    );
  }
}

/// Custom radio list tile with enhanced styling
class CustomRadioListTile<T> extends StatelessWidget {
  final String title;
  final String? subtitle;
  final T value;
  final T? groupValue;
  final ValueChanged<T?>? onChanged;

  const CustomRadioListTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    this.groupValue,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RadioListTile<T>(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
    );
  }
}
