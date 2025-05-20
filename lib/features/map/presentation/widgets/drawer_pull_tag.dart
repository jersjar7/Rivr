// lib/features/map/presentation/widgets/drawer_pull_tag.dart

import 'package:flutter/material.dart';

class DrawerPullTag extends StatelessWidget {
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? iconColor;
  final double top;

  const DrawerPullTag({
    super.key,
    required this.onTap,
    this.backgroundColor,
    this.iconColor,
    this.top = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final brightness = theme.brightness;

    // Use more explicit color assignments
    Color bgColor =
        backgroundColor ??
        (brightness == Brightness.light
            ? colors.primary
            : colors
                .secondary); // Use secondary in dark mode for more visibility

    Color chevronColor =
        iconColor ??
        (brightness == Brightness.light
            ? colors.onPrimary
            : colors.onSecondary);

    return Material(
      color: Colors.transparent,
      elevation: 6, // Increased elevation for better visibility
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 70,
          width: 24,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(8),
              bottomRight: Radius.circular(8),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(
                  0.3,
                ), // Use fixed shadow color for better visibility
                blurRadius: 4,
                offset: const Offset(2, 2),
              ),
            ],
          ),
          child: Center(
            child: Icon(Icons.chevron_right, color: chevronColor, size: 20),
          ),
        ),
      ),
    );
  }
}
