// lib/features/forecast/domain/entities/return_period.dart

class ReturnPeriod {
  static const List<int> standardYears = [2, 5, 10, 25, 50, 100];

  final String reachId;
  final Map<int, double> flowValues;
  final DateTime retrievedAt;

  ReturnPeriod({
    required this.reachId,
    required this.flowValues,
    DateTime? retrievedAt,
  }) : retrievedAt = retrievedAt ?? DateTime.now();

  double? getFlowForYear(int year) {
    return flowValues[year];
  }

  bool isStale() {
    // Return periods rarely change, so we consider them stale after 30 days
    final now = DateTime.now();
    return now.difference(retrievedAt).inDays > 30;
  }

  String getFlowCategory(double flow) {
    if (flow < (flowValues[2] ?? double.infinity)) {
      return 'Low';
    } else if (flow < (flowValues[5] ?? double.infinity)) {
      return 'Normal';
    } else if (flow < (flowValues[10] ?? double.infinity)) {
      return 'Moderate';
    } else if (flow < (flowValues[25] ?? double.infinity)) {
      return 'High';
    } else if (flow < (flowValues[50] ?? double.infinity)) {
      return 'Very High';
    } else if (flow < (flowValues[100] ?? double.infinity)) {
      return 'Extreme';
    } else {
      return 'Catastrophic';
    }
  }

  int? getReturnPeriod(double flow) {
    // Find the closest return period year for this flow
    int? closestYear;
    double minDifference = double.infinity;

    for (final year in standardYears) {
      final returnFlow = flowValues[year];
      if (returnFlow == null) continue;

      final difference = (returnFlow - flow).abs();
      if (difference < minDifference) {
        minDifference = difference;
        closestYear = year;
      }
    }

    return closestYear;
  }
}

class ReturnPeriodModel extends ReturnPeriod {
  ReturnPeriodModel({
    required super.reachId,
    required super.flowValues,
    super.retrievedAt,
  });

  factory ReturnPeriodModel.fromJson(
    Map<String, dynamic> json,
    String reachId,
  ) {
    final Map<int, double> flowValues = {};

    for (final year in ReturnPeriod.standardYears) {
      final key = 'return_period_$year';
      if (json.containsKey(key) && json[key] != null) {
        flowValues[year] = (json[key] as num).toDouble();
      }
    }

    return ReturnPeriodModel(
      reachId: reachId,
      flowValues: flowValues,
      retrievedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      'reach_id': reachId,
      'timestamp': retrievedAt.millisecondsSinceEpoch,
    };

    for (final entry in flowValues.entries) {
      json['return_period_${entry.key}'] = entry.value;
    }

    return json;
  }
}
