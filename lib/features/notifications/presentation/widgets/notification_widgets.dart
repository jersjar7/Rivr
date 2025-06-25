// lib/features/notifications/presentation/widgets/notification_widgets.dart
// Reusable notification-related widgets

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Data model for notification history items
class NotificationHistoryItem {
  final String id;
  final String title;
  final String body;
  final String category; // 'safety', 'activity', 'information'
  final String priority; // 'critical', 'high', 'medium', 'low'
  final DateTime timestamp;
  bool read;
  final String? reachId;

  NotificationHistoryItem({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.priority,
    required this.timestamp,
    this.read = false,
    this.reachId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'category': category,
      'priority': priority,
      'timestamp': timestamp.toIso8601String(),
      'read': read,
      'reachId': reachId,
    };
  }

  factory NotificationHistoryItem.fromJson(Map<String, dynamic> json) {
    return NotificationHistoryItem(
      id: json['id'],
      title: json['title'],
      body: json['body'],
      category: json['category'],
      priority: json['priority'],
      timestamp: DateTime.parse(json['timestamp']),
      read: json['read'] ?? false,
      reachId: json['reachId'],
    );
  }
}

/// Notification card widget for displaying notification items
class NotificationCard extends StatelessWidget {
  final NotificationHistoryItem notification;
  final VoidCallback? onTap;
  final Function(String, NotificationHistoryItem)? onActionSelected;

  const NotificationCard({
    super.key,
    required this.notification,
    this.onTap,
    this.onActionSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      elevation: notification.read ? 1 : 3,
      child: ListTile(
        leading: NotificationIcon(category: notification.category),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.read ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.body),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, size: 12, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  _formatTimestamp(notification.timestamp),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const Spacer(),
                PriorityChip(priority: notification.priority),
              ],
            ),
          ],
        ),
        trailing:
            onActionSelected != null
                ? PopupMenuButton<String>(
                  onSelected:
                      (action) => onActionSelected!(action, notification),
                  itemBuilder:
                      (context) => [
                        PopupMenuItem(
                          value:
                              notification.read ? 'mark_unread' : 'mark_read',
                          child: Text(
                            notification.read
                                ? 'Mark as Unread'
                                : 'Mark as Read',
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'view_details',
                          child: Text('View Details'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      ],
                )
                : null,
        onTap: onTap,
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, y').format(timestamp);
    }
  }
}

/// Notification icon widget based on category
class NotificationIcon extends StatelessWidget {
  final String category;

  const NotificationIcon({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    IconData iconData;
    Color iconColor;

    switch (category) {
      case 'safety':
        iconData = Icons.warning;
        iconColor = Colors.red;
        break;
      case 'activity':
        iconData = Icons.kayaking;
        iconColor = Colors.blue;
        break;
      case 'information':
        iconData = Icons.info;
        iconColor = Colors.green;
        break;
      default:
        iconData = Icons.notifications;
        iconColor = Colors.grey;
    }

    return CircleAvatar(
      backgroundColor: iconColor.withOpacity(0.1),
      child: Icon(iconData, color: iconColor, size: 20),
    );
  }
}

/// Priority chip widget
class PriorityChip extends StatelessWidget {
  final String priority;

  const PriorityChip({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    Color chipColor;
    String chipText;

    switch (priority) {
      case 'critical':
        chipColor = Colors.red;
        chipText = 'Critical';
        break;
      case 'high':
        chipColor = Colors.orange;
        chipText = 'High';
        break;
      case 'medium':
        chipColor = Colors.blue;
        chipText = 'Medium';
        break;
      case 'low':
        chipColor = Colors.green;
        chipText = 'Low';
        break;
      default:
        chipColor = Colors.grey;
        chipText = 'Normal';
    }

    return Chip(
      label: Text(
        chipText,
        style: const TextStyle(fontSize: 10, color: Colors.white),
      ),
      backgroundColor: chipColor,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

/// Empty state widget for notification lists
class NotificationEmptyState extends StatelessWidget {
  final String filter;
  final VoidCallback? onSettingsPressed;

  const NotificationEmptyState({
    super.key,
    required this.filter,
    this.onSettingsPressed,
  });

  @override
  Widget build(BuildContext context) {
    String message;
    IconData icon;

    switch (filter) {
      case 'safety':
        message = 'No safety alerts';
        icon = Icons.shield_outlined;
        break;
      case 'activity':
        message = 'No activity notifications';
        icon = Icons.sports_outlined;
        break;
      case 'information':
        message = 'No information updates';
        icon = Icons.info_outline;
        break;
      default:
        message = 'No notifications yet';
        icon = Icons.notifications_none;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            filter == 'all'
                ? 'You\'ll see your flow notifications here'
                : 'Enable $filter notifications in settings',
            style: const TextStyle(color: Colors.grey),
          ),
          if (filter != 'all' && onSettingsPressed != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onSettingsPressed,
              child: const Text('Open Settings'),
            ),
          ],
        ],
      ),
    );
  }
}
