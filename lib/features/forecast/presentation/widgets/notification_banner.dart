// lib/features/forecast/presentation/widgets/notification_banner.dart
// Enhanced dismissible notification banner for forecast page

import 'package:flutter/material.dart';

/// Enhanced notification banner widget with dismiss functionality
class NotificationBanner extends StatefulWidget {
  final Map<String, dynamic>? notificationData;
  final VoidCallback? onDismiss;
  final VoidCallback? onViewHistory;

  const NotificationBanner({
    super.key,
    this.notificationData,
    this.onDismiss,
    this.onViewHistory,
  });

  @override
  State<NotificationBanner> createState() => _NotificationBannerState();
}

class _NotificationBannerState extends State<NotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Animate in
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_isDismissed) return;

    setState(() {
      _isDismissed = true;
    });

    await _animationController.reverse();
    widget.onDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDismissed) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -50 * (1 - _slideAnimation.value)),
          child: Opacity(opacity: _slideAnimation.value, child: child),
        );
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade100, Colors.blue.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border(
            bottom: BorderSide(color: Colors.blue.shade200, width: 1),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Notification icon with animation
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.notifications_active,
                  color: Colors.blue.shade700,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Main content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Opened from notification',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (widget.notificationData?['category'] != null)
                      Text(
                        'Alert: ${widget.notificationData!['category']}',
                        style: TextStyle(
                          color: Colors.blue.shade600,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),

              // Category chip
              if (widget.notificationData?['category'] != null)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getNotificationCategoryColor(),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.notificationData!['category'],
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),

              // Action buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.onViewHistory != null)
                    IconButton(
                      onPressed: widget.onViewHistory,
                      icon: Icon(
                        Icons.history,
                        color: Colors.blue.shade600,
                        size: 18,
                      ),
                      tooltip: 'View notification history',
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  IconButton(
                    onPressed: _dismiss,
                    icon: Icon(
                      Icons.close,
                      color: Colors.blue.shade600,
                      size: 18,
                    ),
                    tooltip: 'Dismiss banner',
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getNotificationCategoryColor() {
    final category =
        widget.notificationData?['category']?.toString().toLowerCase();
    switch (category) {
      case 'extreme':
        return Colors.purple;
      case 'very high':
      case 'high':
        return Colors.red;
      case 'elevated':
        return Colors.orange;
      case 'moderate':
        return Colors.yellow.shade700;
      case 'normal':
        return Colors.green;
      case 'low':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}

/// Highlight wrapper widget for emphasizing flow components
class FlowHighlightWrapper extends StatefulWidget {
  final Widget child;
  final bool isHighlighted;
  final String? highlightMessage;
  final bool isCard;

  const FlowHighlightWrapper({
    super.key,
    required this.child,
    required this.isHighlighted,
    this.highlightMessage,
    this.isCard = false,
  });

  @override
  State<FlowHighlightWrapper> createState() => _FlowHighlightWrapperState();
}

class _FlowHighlightWrapperState extends State<FlowHighlightWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isHighlighted) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(FlowHighlightWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHighlighted != oldWidget.isHighlighted) {
      if (widget.isHighlighted) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isHighlighted) return widget.child;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final glowIntensity = 0.3 + (_pulseAnimation.value * 0.7);

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.isCard ? 12 : 8),
            boxShadow: [
              BoxShadow(
                color: Colors.yellow.withValues(alpha: glowIntensity * 0.3),
                blurRadius: 8 + (_pulseAnimation.value * 4),
                spreadRadius: 1 + (_pulseAnimation.value * 2),
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.yellow.shade100.withValues(alpha: 0.8),
                  Colors.yellow.shade50.withValues(alpha: 0.4),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: Colors.yellow.shade400.withValues(alpha: glowIntensity),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(widget.isCard ? 12 : 8),
            ),
            child: Column(
              children: [
                // Highlight indicator
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.yellow.shade200.withValues(
                      alpha: glowIntensity,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(widget.isCard ? 10 : 6),
                      topRight: Radius.circular(widget.isCard ? 10 : 6),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.star, color: Colors.yellow.shade800, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.highlightMessage ??
                              'Flow highlighted from notification',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.yellow.shade800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Original widget with padding
                Padding(padding: const EdgeInsets.all(8), child: widget.child),
              ],
            ),
          ),
        );
      },
    );
  }
}
