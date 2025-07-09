// lib/features/simple_notifications/models/notification_preferences.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Simple notification preferences model for the basic notification system
/// Focuses only on essential settings for monitoring favorite rivers
class NotificationPreferences {
  final String userId;
  final bool enabled;
  final List<String> monitoredRiverIds;
  final bool includeShortRange;
  final bool includeMediumRange;
  final bool quietHoursEnabled;
  final int quietHourStart; // Hour in 24-hour format (e.g., 22 for 10 PM)
  final int quietHourEnd; // Hour in 24-hour format (e.g., 7 for 7 AM)
  final DateTime createdAt;
  final DateTime updatedAt;

  const NotificationPreferences({
    required this.userId,
    required this.enabled,
    required this.monitoredRiverIds,
    this.includeShortRange = true,
    this.includeMediumRange = true,
    this.quietHoursEnabled = false,
    this.quietHourStart = 22, // 10 PM default
    this.quietHourEnd = 7, // 7 AM default
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create default preferences for a new user
  factory NotificationPreferences.defaultPreferences(String userId) {
    final now = DateTime.now();
    return NotificationPreferences(
      userId: userId,
      enabled: false, // Start disabled, user must opt in
      monitoredRiverIds: [], // No rivers monitored by default
      includeShortRange: true,
      includeMediumRange: true,
      quietHoursEnabled: false,
      quietHourStart: 22,
      quietHourEnd: 7,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Create from Firestore document
  factory NotificationPreferences.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data()!;
    return NotificationPreferences(
      userId: data['userId'] as String,
      enabled: data['enabled'] as bool? ?? false,
      monitoredRiverIds: List<String>.from(
        data['monitoredRiverIds'] as List? ?? [],
      ),
      includeShortRange: data['includeShortRange'] as bool? ?? true,
      includeMediumRange: data['includeMediumRange'] as bool? ?? true,
      quietHoursEnabled: data['quietHoursEnabled'] as bool? ?? false,
      quietHourStart: data['quietHourStart'] as int? ?? 22,
      quietHourEnd: data['quietHourEnd'] as int? ?? 7,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'enabled': enabled,
      'monitoredRiverIds': monitoredRiverIds,
      'includeShortRange': includeShortRange,
      'includeMediumRange': includeMediumRange,
      'quietHoursEnabled': quietHoursEnabled,
      'quietHourStart': quietHourStart,
      'quietHourEnd': quietHourEnd,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Create a copy with updated values
  NotificationPreferences copyWith({
    String? userId,
    bool? enabled,
    List<String>? monitoredRiverIds,
    bool? includeShortRange,
    bool? includeMediumRange,
    bool? quietHoursEnabled,
    int? quietHourStart,
    int? quietHourEnd,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotificationPreferences(
      userId: userId ?? this.userId,
      enabled: enabled ?? this.enabled,
      monitoredRiverIds: monitoredRiverIds ?? this.monitoredRiverIds,
      includeShortRange: includeShortRange ?? this.includeShortRange,
      includeMediumRange: includeMediumRange ?? this.includeMediumRange,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHourStart: quietHourStart ?? this.quietHourStart,
      quietHourEnd: quietHourEnd ?? this.quietHourEnd,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Add a river to monitoring list
  NotificationPreferences addRiver(String riverId) {
    if (monitoredRiverIds.contains(riverId)) {
      return this; // Already monitoring this river
    }
    return copyWith(
      monitoredRiverIds: [...monitoredRiverIds, riverId],
      updatedAt: DateTime.now(),
    );
  }

  /// Remove a river from monitoring list
  NotificationPreferences removeRiver(String riverId) {
    return copyWith(
      monitoredRiverIds:
          monitoredRiverIds.where((id) => id != riverId).toList(),
      updatedAt: DateTime.now(),
    );
  }

  /// Check if a river is being monitored
  bool isRiverMonitored(String riverId) {
    return monitoredRiverIds.contains(riverId);
  }

  /// Check if notifications should be sent at this time (considering quiet hours)
  bool shouldSendNotificationNow() {
    if (!enabled) return false;
    if (!quietHoursEnabled) return true;

    final now = DateTime.now();
    final currentHour = now.hour;

    // Handle quiet hours that cross midnight (e.g., 22 to 7)
    if (quietHourStart > quietHourEnd) {
      return !(currentHour >= quietHourStart || currentHour < quietHourEnd);
    } else {
      // Handle quiet hours within same day (e.g., 1 to 5)
      return !(currentHour >= quietHourStart && currentHour < quietHourEnd);
    }
  }

  /// Get number of monitored rivers
  int get monitoredRiversCount => monitoredRiverIds.length;

  /// Check if any rivers are being monitored
  bool get hasMonitoredRivers => monitoredRiverIds.isNotEmpty;

  /// Check if notifications are fully configured and ready
  bool get isFullyConfigured => enabled && hasMonitoredRivers;

  @override
  String toString() {
    return 'NotificationPreferences('
        'userId: $userId, '
        'enabled: $enabled, '
        'monitoredRivers: ${monitoredRiverIds.length}, '
        'shortRange: $includeShortRange, '
        'mediumRange: $includeMediumRange, '
        'quietHours: $quietHoursEnabled'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationPreferences &&
        other.userId == userId &&
        other.enabled == enabled &&
        other.monitoredRiverIds.length == monitoredRiverIds.length &&
        other.monitoredRiverIds.every((id) => monitoredRiverIds.contains(id)) &&
        other.includeShortRange == includeShortRange &&
        other.includeMediumRange == includeMediumRange &&
        other.quietHoursEnabled == quietHoursEnabled &&
        other.quietHourStart == quietHourStart &&
        other.quietHourEnd == quietHourEnd;
  }

  @override
  int get hashCode {
    return Object.hash(
      userId,
      enabled,
      monitoredRiverIds.length,
      includeShortRange,
      includeMediumRange,
      quietHoursEnabled,
      quietHourStart,
      quietHourEnd,
    );
  }
}
