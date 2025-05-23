// lib/features/auth/presentation/widgets/enhanced_error_display.dart

import 'package:flutter/material.dart';

class EnhancedErrorDisplay extends StatefulWidget {
  final String message;
  final VoidCallback? onRetry;
  final String? recoverySuggestion;
  final bool collapsible;
  final bool showIcon;

  const EnhancedErrorDisplay({
    super.key,
    required this.message,
    this.onRetry,
    this.recoverySuggestion,
    this.collapsible = false,
    this.showIcon = true,
  });

  @override
  State<EnhancedErrorDisplay> createState() => _EnhancedErrorDisplayState();
}

class _EnhancedErrorDisplayState extends State<EnhancedErrorDisplay> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    // Get theme colors for proper light/dark mode support
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // Error colors based on theme
    final errorColor = colors.error;
    final errorContainerColor = colors.error.withValues(alpha: 0.1);
    final errorBorderColor = colors.error.withValues(alpha: 0.3);

    final secondaryTextColor = colors.onSurfaceVariant;

    final String mainMessage =
        widget.collapsible && !_isExpanded && widget.message.length > 80
            ? '${widget.message.substring(0, 80)}...'
            : widget.message;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: errorContainerColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: errorBorderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main error message
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.showIcon) ...[
                  Icon(Icons.error_outline, color: errorColor, size: 20),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mainMessage,
                        style: TextStyle(
                          color: errorColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      // Recovery suggestion if provided
                      if (widget.recoverySuggestion != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          widget.recoverySuggestion!,
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // Show expand/collapse button if collapsible and message is long
            if (widget.collapsible && widget.message.length > 80) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: errorColor,
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    _isExpanded ? 'Show less' : 'Show more',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],

            // Retry button if provided
            if (widget.onRetry != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: widget.onRetry,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry'),
                  style: TextButton.styleFrom(
                    foregroundColor: errorColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Utility to get recovery suggestions for common errors
class ErrorRecoverySuggestions {
  static String? getForAuthError(String errorMessage) {
    final lowerCase = errorMessage.toLowerCase();

    if (lowerCase.contains('password') && lowerCase.contains('incorrect')) {
      return 'Try using the "Forgot Password" option to reset your password';
    } else if (lowerCase.contains('user') && lowerCase.contains('not found')) {
      return 'Check your email address or register for a new account';
    } else if (lowerCase.contains('network') ||
        lowerCase.contains('connection')) {
      return 'Check your internet connection and try again';
    } else if (lowerCase.contains('too many')) {
      return 'Wait a few minutes before trying again';
    } else if (lowerCase.contains('email') && lowerCase.contains('use')) {
      return 'Try signing in instead, or use a different email address';
    }

    return null;
  }
}
