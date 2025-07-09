// lib/features/simple_notifications/models/flow_alert.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a flow alert when forecasted values match return periods
/// Simple model focused only on essential alert information
class FlowAlert {
  final String alertId;
  final String userId;
  final String riverId;
  final String riverName;
  final double forecastedFlow;
  final String flowUnit; // 'cfs' or 'cms'
  final int returnPeriod; // Years (2, 5, 10, 25, 50, 100)
  final double returnPeriodFlow; // The flow value for this return period
  final ForecastRange forecastRange; // Short or medium range
  final DateTime forecastDateTime; // When this flow is forecasted to occur
  final DateTime alertTriggeredAt; // When alert was generated
  final AlertSeverity severity; // Based on return period
  final bool sent; // Whether notification was actually sent
  final DateTime? sentAt; // When notification was sent

  const FlowAlert({
    required this.alertId,
    required this.userId,
    required this.riverId,
    required this.riverName,
    required this.forecastedFlow,
    required this.flowUnit,
    required this.returnPeriod,
    required this.returnPeriodFlow,
    required this.forecastRange,
    required this.forecastDateTime,
    required this.alertTriggeredAt,
    required this.severity,
    this.sent = false,
    this.sentAt,
  });

  /// Create from forecast data and return period match
  factory FlowAlert.fromForecastMatch({
    required String userId,
    required String riverId,
    required String riverName,
    required double forecastedFlow,
    required String flowUnit,
    required int returnPeriod,
    required double returnPeriodFlow,
    required ForecastRange forecastRange,
    required DateTime forecastDateTime,
  }) {
    return FlowAlert(
      alertId: _generateAlertId(riverId, returnPeriod, forecastDateTime),
      userId: userId,
      riverId: riverId,
      riverName: riverName,
      forecastedFlow: forecastedFlow,
      flowUnit: flowUnit,
      returnPeriod: returnPeriod,
      returnPeriodFlow: returnPeriodFlow,
      forecastRange: forecastRange,
      forecastDateTime: forecastDateTime,
      alertTriggeredAt: DateTime.now(),
      severity: AlertSeverity.fromReturnPeriod(returnPeriod),
    );
  }

  /// Generate unique alert ID
  static String _generateAlertId(
    String riverId,
    int returnPeriod,
    DateTime forecastDateTime,
  ) {
    final timestamp = forecastDateTime.millisecondsSinceEpoch;
    return '${riverId}_${returnPeriod}yr_$timestamp';
  }

  /// Create from Firestore document
  factory FlowAlert.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data()!;
    return FlowAlert(
      alertId: data['alertId'] as String,
      userId: data['userId'] as String,
      riverId: data['riverId'] as String,
      riverName: data['riverName'] as String,
      forecastedFlow: (data['forecastedFlow'] as num).toDouble(),
      flowUnit: data['flowUnit'] as String,
      returnPeriod: data['returnPeriod'] as int,
      returnPeriodFlow: (data['returnPeriodFlow'] as num).toDouble(),
      forecastRange: ForecastRange.values.byName(
        data['forecastRange'] as String,
      ),
      forecastDateTime: (data['forecastDateTime'] as Timestamp).toDate(),
      alertTriggeredAt: (data['alertTriggeredAt'] as Timestamp).toDate(),
      severity: AlertSeverity.values.byName(data['severity'] as String),
      sent: data['sent'] as bool? ?? false,
      sentAt:
          data['sentAt'] != null
              ? (data['sentAt'] as Timestamp).toDate()
              : null,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'alertId': alertId,
      'userId': userId,
      'riverId': riverId,
      'riverName': riverName,
      'forecastedFlow': forecastedFlow,
      'flowUnit': flowUnit,
      'returnPeriod': returnPeriod,
      'returnPeriodFlow': returnPeriodFlow,
      'forecastRange': forecastRange.name,
      'forecastDateTime': Timestamp.fromDate(forecastDateTime),
      'alertTriggeredAt': Timestamp.fromDate(alertTriggeredAt),
      'severity': severity.name,
      'sent': sent,
      'sentAt': sentAt != null ? Timestamp.fromDate(sentAt!) : null,
    };
  }

  /// Mark alert as sent
  FlowAlert markAsSent() {
    return FlowAlert(
      alertId: alertId,
      userId: userId,
      riverId: riverId,
      riverName: riverName,
      forecastedFlow: forecastedFlow,
      flowUnit: flowUnit,
      returnPeriod: returnPeriod,
      returnPeriodFlow: returnPeriodFlow,
      forecastRange: forecastRange,
      forecastDateTime: forecastDateTime,
      alertTriggeredAt: alertTriggeredAt,
      severity: severity,
      sent: true,
      sentAt: DateTime.now(),
    );
  }

  /// Generate notification title
  String get notificationTitle {
    return '${severity.displayName} Flow Alert: $riverName';
  }

  /// Generate notification body
  String get notificationBody {
    final flowFormatted = forecastedFlow.toStringAsFixed(0);
    final returnFlowFormatted = returnPeriodFlow.toStringAsFixed(0);
    final dateFormatted = _formatForecastDate(forecastDateTime);

    return 'Forecasted flow: $flowFormatted $flowUnit ($dateFormatted)\n'
        'Matches $returnPeriod-year return period ($returnFlowFormatted $flowUnit)';
  }

  /// Generate formatted forecast date
  String _formatForecastDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Tomorrow';
    } else if (difference <= 7) {
      return 'In $difference days';
    } else {
      return '${date.month}/${date.day}';
    }
  }

  /// Get data for push notification
  Map<String, String> get notificationData {
    return {
      'type': 'flow_alert',
      'riverId': riverId,
      'riverName': riverName,
      'forecastedFlow': forecastedFlow.toString(),
      'returnPeriod': returnPeriod.toString(),
      'severity': severity.name,
      'forecastRange': forecastRange.name,
      'alertId': alertId,
    };
  }

  /// Check if this alert is still relevant (not too old)
  bool get isRelevant {
    final now = DateTime.now();
    final hoursSinceTriggered = now.difference(alertTriggeredAt).inHours;

    // Alert is relevant if:
    // 1. Forecast is in the future
    // 2. Alert was triggered less than 24 hours ago
    return forecastDateTime.isAfter(now) && hoursSinceTriggered < 24;
  }

  @override
  String toString() {
    return 'FlowAlert('
        'river: $riverName, '
        'flow: $forecastedFlow $flowUnit, '
        'returnPeriod: ${returnPeriod}yr, '
        'severity: ${severity.name}, '
        'sent: $sent'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FlowAlert && other.alertId == alertId;
  }

  @override
  int get hashCode => alertId.hashCode;
}

/// Forecast range enumeration
enum ForecastRange {
  short,
  medium;

  String get displayName {
    switch (this) {
      case ForecastRange.short:
        return 'Short Range';
      case ForecastRange.medium:
        return 'Medium Range';
    }
  }

  /// Get forecast range in days
  int get daysAhead {
    switch (this) {
      case ForecastRange.short:
        return 3; // 0-3 days
      case ForecastRange.medium:
        return 10; // 4-10 days
    }
  }
}

/// Alert severity based on return period
enum AlertSeverity {
  moderate, // 2-year
  significant, // 5-year
  major, // 10-year
  severe, // 25-year
  extreme; // 50+ year

  /// Create severity from return period
  factory AlertSeverity.fromReturnPeriod(int returnPeriod) {
    if (returnPeriod >= 50) return AlertSeverity.extreme;
    if (returnPeriod >= 25) return AlertSeverity.severe;
    if (returnPeriod >= 10) return AlertSeverity.major;
    if (returnPeriod >= 5) return AlertSeverity.significant;
    return AlertSeverity.moderate;
  }

  String get displayName {
    switch (this) {
      case AlertSeverity.moderate:
        return 'Moderate';
      case AlertSeverity.significant:
        return 'Significant';
      case AlertSeverity.major:
        return 'Major';
      case AlertSeverity.severe:
        return 'Severe';
      case AlertSeverity.extreme:
        return 'Extreme';
    }
  }

  /// Get notification priority for this severity
  String get notificationPriority {
    switch (this) {
      case AlertSeverity.moderate:
      case AlertSeverity.significant:
        return 'default';
      case AlertSeverity.major:
        return 'high';
      case AlertSeverity.severe:
      case AlertSeverity.extreme:
        return 'max';
    }
  }
}
