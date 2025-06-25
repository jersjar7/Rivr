// lib/features/notifications/presentation/pages/notification_history_page.dart
// Clean notification history page using reusable widgets

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/navigation/app_router.dart';
import '../widgets/notification_widgets.dart';

/// Clean notification history page using modular widgets
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
      return NotificationEmptyState(
        filter: filter,
        onSettingsPressed:
            filter != 'all'
                ? () => AppRouter.navigateToNotificationSettings(context)
                : null,
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshNotifications,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: filteredNotifications.length,
        itemBuilder: (context, index) {
          final notification = filteredNotifications[index];
          return NotificationCard(
            notification: notification,
            onTap: () => _onNotificationTap(notification),
            onActionSelected: _handleNotificationAction,
          );
        },
      ),
    );
  }

  List<NotificationHistoryItem> _getFilteredNotifications(String filter) {
    if (filter == 'all') return _notifications;
    return _notifications.where((n) => n.category == filter).toList();
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
      // Fixed: Use navigateToForecast instead of navigateToReachDetails
      AppRouter.navigateToForecast(
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
      // Refresh the list - this would update from your data source
    });
  }
}
