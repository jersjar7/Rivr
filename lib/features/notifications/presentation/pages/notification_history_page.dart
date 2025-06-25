// lib/features/notifications/presentation/pages/notification_history_page.dart
// Production notification history page for users

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/navigation/app_router.dart';

/// Production notification history page
///
/// Allows users to view, manage, and interact with their notification history
/// This is a real feature users would want in a production app
class NotificationHistoryPage extends StatefulWidget {
  final Map<String, dynamic>? arguments;

  const NotificationHistoryPage({super.key, this.arguments});

  @override
  State<NotificationHistoryPage> createState() =>
      _NotificationHistoryPageState();
}

class _NotificationHistoryPageState extends State<NotificationHistoryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'all';

  // Mock data - in production this would come from your database/storage
  final List<NotificationHistoryItem> _notifications = [
    NotificationHistoryItem(
      id: '1',
      title: 'High Flow Alert: Green River',
      body: 'Flow has reached 580 cfs - exercise caution',
      category: 'safety',
      priority: 'high',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      read: true,
      reachId: 'green-river-001',
    ),
    NotificationHistoryItem(
      id: '2',
      title: 'Optimal Kayaking Conditions',
      body: 'Blue River is at perfect flow (240 cfs) for kayaking',
      category: 'activity',
      priority: 'medium',
      timestamp: DateTime.now().subtract(const Duration(hours: 6)),
      read: true,
      reachId: 'blue-river-002',
    ),
    NotificationHistoryItem(
      id: '3',
      title: 'Flow Update: Normal Conditions',
      body: 'Colorado River has returned to normal levels',
      category: 'information',
      priority: 'low',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      read: false,
      reachId: 'colorado-river-003',
    ),
    NotificationHistoryItem(
      id: '4',
      title: 'Safety Alert: Flash Flood Warning',
      body: 'Rapid Creek showing dangerous conditions - avoid area',
      category: 'safety',
      priority: 'critical',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      read: true,
      reachId: 'rapid-creek-004',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // Check if we should filter to a specific type from arguments
    final filterType = widget.arguments?['filterType'];
    if (filterType != null) {
      _selectedFilter = filterType;
      _updateTabBasedOnFilter();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _updateTabBasedOnFilter() {
    switch (_selectedFilter) {
      case 'safety':
        _tabController.index = 1;
        break;
      case 'activity':
        _tabController.index = 2;
        break;
      case 'information':
        _tabController.index = 3;
        break;
      default:
        _tabController.index = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => AppRouter.navigateToNotificationSettings(context),
            tooltip: 'Notification Settings',
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'mark_all_read',
                    child: Text('Mark All as Read'),
                  ),
                  const PopupMenuItem(
                    value: 'clear_old',
                    child: Text('Clear Old Notifications'),
                  ),
                ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          onTap: _onTabChanged,
          tabs: [
            Tab(
              text: 'All',
              icon: Badge(
                label: Text('${_getFilteredNotifications('all').length}'),
                child: const Icon(Icons.notifications),
              ),
            ),
            Tab(
              text: 'Safety',
              icon: Badge(
                label: Text('${_getFilteredNotifications('safety').length}'),
                child: const Icon(Icons.warning),
              ),
            ),
            Tab(
              text: 'Activity',
              icon: Badge(
                label: Text('${_getFilteredNotifications('activity').length}'),
                child: const Icon(Icons.kayaking),
              ),
            ),
            Tab(
              text: 'Info',
              icon: Badge(
                label: Text(
                  '${_getFilteredNotifications('information').length}',
                ),
                child: const Icon(Icons.info),
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNotificationList('all'),
          _buildNotificationList('safety'),
          _buildNotificationList('activity'),
          _buildNotificationList('information'),
        ],
      ),
    );
  }

  Widget _buildNotificationList(String filter) {
    final filteredNotifications = _getFilteredNotifications(filter);

    if (filteredNotifications.isEmpty) {
      return _buildEmptyState(filter);
    }

    return RefreshIndicator(
      onRefresh: _refreshNotifications,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: filteredNotifications.length,
        itemBuilder: (context, index) {
          final notification = filteredNotifications[index];
          return _buildNotificationCard(notification);
        },
      ),
    );
  }

  Widget _buildNotificationCard(NotificationHistoryItem notification) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      elevation: notification.read ? 1 : 3,
      child: ListTile(
        leading: _buildNotificationIcon(notification),
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
                _buildPriorityChip(notification.priority),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected:
              (action) => _handleNotificationAction(action, notification),
          itemBuilder:
              (context) => [
                PopupMenuItem(
                  value: notification.read ? 'mark_unread' : 'mark_read',
                  child: Text(
                    notification.read ? 'Mark as Unread' : 'Mark as Read',
                  ),
                ),
                const PopupMenuItem(
                  value: 'view_details',
                  child: Text('View Details'),
                ),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
        ),
        onTap: () => _onNotificationTap(notification),
      ),
    );
  }

  Widget _buildNotificationIcon(NotificationHistoryItem notification) {
    IconData iconData;
    Color iconColor;

    switch (notification.category) {
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

  Widget _buildPriorityChip(String priority) {
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

  Widget _buildEmptyState(String filter) {
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
          if (filter != 'all') ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed:
                  () => AppRouter.navigateToNotificationSettings(context),
              child: const Text('Open Settings'),
            ),
          ],
        ],
      ),
    );
  }

  List<NotificationHistoryItem> _getFilteredNotifications(String filter) {
    if (filter == 'all') return _notifications;
    return _notifications.where((n) => n.category == filter).toList();
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

  void _onTabChanged(int index) {
    final filters = ['all', 'safety', 'activity', 'information'];
    setState(() {
      _selectedFilter = filters[index];
    });
  }

  void _onNotificationTap(NotificationHistoryItem notification) {
    // Mark as read
    setState(() {
      notification.read = true;
    });

    // Navigate to the relevant screen based on notification content
    if (notification.reachId != null) {
      AppRouter.navigateToReachDetails(
        context,
        notification.reachId!,
        fromNotification: true,
        highlightFlow: true,
        notificationData: {
          'notificationId': notification.id,
          'category': notification.category,
          'priority': notification.priority,
        },
      );
    }
  }

  void _handleNotificationAction(
    String action,
    NotificationHistoryItem notification,
  ) {
    switch (action) {
      case 'mark_read':
        setState(() {
          notification.read = true;
        });
        break;
      case 'mark_unread':
        setState(() {
          notification.read = false;
        });
        break;
      case 'view_details':
        _showNotificationDetails(notification);
        break;
      case 'delete':
        _deleteNotification(notification);
        break;
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'mark_all_read':
        setState(() {
          for (var notification in _notifications) {
            notification.read = true;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications marked as read')),
        );
        break;
      case 'clear_old':
        _clearOldNotifications();
        break;
    }
  }

  void _showNotificationDetails(NotificationHistoryItem notification) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(notification.title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notification.body),
                const SizedBox(height: 16),
                Text(
                  'Category: ${notification.category}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Priority: ${notification.priority}'),
                Text(
                  'Received: ${DateFormat('MMM d, y \'at\' h:mm a').format(notification.timestamp)}',
                ),
                if (notification.reachId != null)
                  Text('Reach: ${notification.reachId}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
              if (notification.reachId != null)
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _onNotificationTap(notification);
                  },
                  child: const Text('View Details'),
                ),
            ],
          ),
    );
  }

  void _deleteNotification(NotificationHistoryItem notification) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Notification'),
            content: const Text(
              'Are you sure you want to delete this notification?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _notifications.remove(notification);
                  });
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notification deleted')),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  void _clearOldNotifications() {
    final cutoffDate = DateTime.now().subtract(const Duration(days: 30));

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Clear Old Notifications'),
            content: const Text(
              'This will remove notifications older than 30 days. This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _notifications.removeWhere(
                      (n) => n.timestamp.isBefore(cutoffDate),
                    );
                  });
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Old notifications cleared')),
                  );
                },
                child: const Text('Clear'),
              ),
            ],
          ),
    );
  }

  Future<void> _refreshNotifications() async {
    // Simulate network request
    await Future.delayed(const Duration(seconds: 1));

    // In production, you would fetch latest notifications from your backend
    setState(() {
      // Refresh the list
    });
  }
}

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
