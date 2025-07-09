class DummyRiver {
  final String id;
  final String name;
  final String description;
  final Map<int, double> returnPeriods; // year -> flow value
  final String unit; // 'cfs', 'cms', etc.
  final DateTime createdAt;
  final DateTime updatedAt;

  const DummyRiver({
    required this.id,
    required this.name,
    required this.description,
    required this.returnPeriods,
    required this.unit,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create a copy with updated fields
  DummyRiver copyWith({
    String? id,
    String? name,
    String? description,
    Map<int, double>? returnPeriods,
    String? unit,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DummyRiver(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      returnPeriods: returnPeriods ?? Map.from(this.returnPeriods),
      unit: unit ?? this.unit,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Create from JSON (Firebase document)
  factory DummyRiver.fromJson(Map<String, dynamic> json, String id) {
    return DummyRiver(
      id: id,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      returnPeriods: _parseReturnPeriods(json['returnPeriods']),
      unit: json['unit'] as String? ?? 'cfs',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Convert to JSON for Firebase storage
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'returnPeriods': _returnPeriodsToJson(),
      'unit': unit,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Helper method to parse return periods from JSON
  static Map<int, double> _parseReturnPeriods(dynamic returnPeriodsJson) {
    if (returnPeriodsJson == null) return {};

    final Map<int, double> periods = {};

    if (returnPeriodsJson is Map) {
      returnPeriodsJson.forEach((key, value) {
        final year = int.tryParse(key.toString());
        final flow = double.tryParse(value.toString());
        if (year != null && flow != null) {
          periods[year] = flow;
        }
      });
    }

    return periods;
  }

  /// Convert return periods to JSON-serializable format
  Map<String, double> _returnPeriodsToJson() {
    return returnPeriods.map((year, flow) => MapEntry(year.toString(), flow));
  }

  /// Get sorted list of return period years
  List<int> get sortedReturnPeriodYears {
    final years = returnPeriods.keys.toList();
    years.sort();
    return years;
  }

  /// Get flow value for specific return period
  double? getFlowForReturnPeriod(int years) {
    return returnPeriods[years];
  }

  /// Check if this dummy river has any return periods defined
  bool get hasReturnPeriods => returnPeriods.isNotEmpty;

  /// Get the highest return period flow value
  double? get maxFlow {
    if (returnPeriods.isEmpty) return null;
    return returnPeriods.values.reduce((a, b) => a > b ? a : b);
  }

  /// Get the lowest return period flow value
  double? get minFlow {
    if (returnPeriods.isEmpty) return null;
    return returnPeriods.values.reduce((a, b) => a < b ? a : b);
  }

  /// Create a new dummy river with default return periods for testing
  factory DummyRiver.createDefault({
    required String name,
    String? description,
    String unit = 'cfs',
  }) {
    final now = DateTime.now();
    final id = 'dummy_${now.millisecondsSinceEpoch}';

    // Default return periods that are good for testing
    const defaultReturnPeriods = {
      2: 5000.0,
      5: 8000.0,
      10: 12000.0,
      25: 15000.0,
      50: 18000.0,
      100: 22000.0,
    };

    return DummyRiver(
      id: id,
      name: name,
      description: description ?? 'Test river for notifications',
      returnPeriods: defaultReturnPeriods,
      unit: unit,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Update return period for specific year
  DummyRiver updateReturnPeriod(int year, double flow) {
    final updatedPeriods = Map<int, double>.from(returnPeriods);
    updatedPeriods[year] = flow;

    return copyWith(returnPeriods: updatedPeriods, updatedAt: DateTime.now());
  }

  /// Remove return period for specific year
  DummyRiver removeReturnPeriod(int year) {
    final updatedPeriods = Map<int, double>.from(returnPeriods);
    updatedPeriods.remove(year);

    return copyWith(returnPeriods: updatedPeriods, updatedAt: DateTime.now());
  }

  /// Validate if return periods make sense (higher years should have higher flows)
  bool get isReturnPeriodsValid {
    if (returnPeriods.length < 2) return true;

    final sortedEntries =
        returnPeriods.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    for (int i = 1; i < sortedEntries.length; i++) {
      if (sortedEntries[i].value <= sortedEntries[i - 1].value) {
        return false;
      }
    }

    return true;
  }

  /// Get validation errors for return periods
  List<String> get returnPeriodsValidationErrors {
    final errors = <String>[];

    if (returnPeriods.isEmpty) {
      errors.add('At least one return period is required');
      return errors;
    }

    if (!isReturnPeriodsValid) {
      errors.add('Return periods must increase with longer return years');
    }

    // Check for reasonable flow values
    for (final entry in returnPeriods.entries) {
      if (entry.value <= 0) {
        errors.add('${entry.key}-year return period must be greater than 0');
      }
      if (entry.value > 1000000) {
        errors.add('${entry.key}-year return period seems unreasonably high');
      }
    }

    return errors;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DummyRiver) return false;

    return other.id == id &&
        other.name == name &&
        other.description == description &&
        _mapEquals(other.returnPeriods, returnPeriods) &&
        other.unit == unit &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      description,
      returnPeriods,
      unit,
      createdAt,
      updatedAt,
    );
  }

  @override
  String toString() {
    return 'DummyRiver(id: $id, name: $name, returnPeriods: $returnPeriods, unit: $unit)';
  }

  /// Helper method to compare maps for equality
  static bool _mapEquals<K, V>(Map<K, V> map1, Map<K, V> map2) {
    if (map1.length != map2.length) return false;
    for (final key in map1.keys) {
      if (!map2.containsKey(key) || map1[key] != map2[key]) {
        return false;
      }
    }
    return true;
  }
}
