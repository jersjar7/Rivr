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
  final int quietMinuteStart; // Minute (0-59)
  final int quietHourEnd; // Hour in 24-hour format (e.g., 7 for 7 AM)
  final int quietMinuteEnd; // Minute (0-59)
  final DateTime createdAt;
  final DateTime updatedAt;

  const NotificationPreferences({
    required this.userId,
    required this.enabled,
    required this.monitoredRiverIds,
    required this.includeShortRange,
    required this.includeMediumRange,
    required this.quietHoursEnabled,
    required this.quietHourStart,
    required this.quietMinuteStart,
    required this.quietHourEnd,
    required this.quietMinuteEnd,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create default preferences for a new user
  factory NotificationPreferences.defaultPreferences(String userId) {
    return NotificationPreferences(
      userId: userId,
      enabled: false,
      monitoredRiverIds: [],
      includeShortRange: true,
      includeMediumRange: true,
      quietHoursEnabled: false,
      quietHourStart: 22,
      quietMinuteStart: 0,
      quietHourEnd: 7,
      quietMinuteEnd: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Create from Firestore document
  factory NotificationPreferences.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return NotificationPreferences(
      userId: data['userId'] as String,
      enabled: data['enabled'] as bool? ?? false,
      monitoredRiverIds: List<String>.from(data['monitoredRiverIds'] ?? []),
      includeShortRange: data['includeShortRange'] as bool? ?? true,
      includeMediumRange: data['includeMediumRange'] as bool? ?? true,
      quietHoursEnabled: data['quietHoursEnabled'] as bool? ?? false,
      quietHourStart: data['quietHourStart'] as int? ?? 22,
      quietMinuteStart: data['quietMinuteStart'] as int? ?? 0,
      quietHourEnd: data['quietHourEnd'] as int? ?? 7,
      quietMinuteEnd: data['quietMinuteEnd'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
      'quietMinuteStart': quietMinuteStart,
      'quietHourEnd': quietHourEnd,
      'quietMinuteEnd': quietMinuteEnd,
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
    int? quietMinuteStart,
    int? quietHourEnd,
    int? quietMinuteEnd,
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
      quietMinuteStart: quietMinuteStart ?? this.quietMinuteStart,
      quietHourEnd: quietHourEnd ?? this.quietHourEnd,
      quietMinuteEnd: quietMinuteEnd ?? this.quietMinuteEnd,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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

  /// Check if notifications should be sent at this time (considering quiet hours with minutes)
  bool shouldSendNotificationNow() {
    if (!enabled) return false;
    if (!quietHoursEnabled) return true;

    final now = DateTime.now();
    final currentMinutesSinceMidnight = now.hour * 60 + now.minute;
    final quietStartMinutes = quietHourStart * 60 + quietMinuteStart;
    final quietEndMinutes = quietHourEnd * 60 + quietMinuteEnd;

    // Handle quiet hours that cross midnight (e.g., 22:30 to 7:15)
    if (quietStartMinutes > quietEndMinutes) {
      // Quiet period crosses midnight
      return !(currentMinutesSinceMidnight >= quietStartMinutes ||
          currentMinutesSinceMidnight < quietEndMinutes);
    } else {
      // Quiet period within same day (e.g., 1:00 to 5:30)
      return !(currentMinutesSinceMidnight >= quietStartMinutes &&
          currentMinutesSinceMidnight < quietEndMinutes);
    }
  }

  /// Get formatted quiet start time as string (HH:MM)
  String get quietStartTimeFormatted {
    return '${quietHourStart.toString().padLeft(2, '0')}:${quietMinuteStart.toString().padLeft(2, '0')}';
  }

  /// Get formatted quiet end time as string (HH:MM)
  String get quietEndTimeFormatted {
    return '${quietHourEnd.toString().padLeft(2, '0')}:${quietMinuteEnd.toString().padLeft(2, '0')}';
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
        other.quietMinuteStart == quietMinuteStart &&
        other.quietHourEnd == quietHourEnd &&
        other.quietMinuteEnd == quietMinuteEnd;
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
      quietMinuteStart,
      quietHourEnd,
      quietMinuteEnd,
    );
  }
}
