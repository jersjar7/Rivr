// lib/features/map/presentation/widgets/drawer_pull_tag.dart

import 'package:flutter/material.dart';

class DrawerPullTag extends StatelessWidget {
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? iconColor;

  const DrawerPullTag({
    super.key,
    required this.onTap,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Positioned(
      left: 0,
      top:
          MediaQuery.of(context).padding.top +
          16, // Position at top for visibility
      child: Material(
        color: Colors.transparent,
        elevation: 4, // Add elevation for better visibility
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 80,
            width: 24,
            decoration: BoxDecoration(
              color: backgroundColor ?? theme.primaryColor,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: 0.3,
                  ), // More visible shadow
                  blurRadius: 4,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.chevron_right,
                color: iconColor ?? Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
