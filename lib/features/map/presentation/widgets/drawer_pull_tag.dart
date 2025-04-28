// Create a new file: lib/features/map/presentation/widgets/drawer_pull_tag.dart

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
          100, // Position below the top app bar
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 50,
          width: 24,
          decoration: BoxDecoration(
            color: backgroundColor ?? theme.primaryColor,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(8),
              bottomRight: Radius.circular(8),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
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
    );
  }
}
