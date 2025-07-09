import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/dummy_river.dart';

class DummyRiversService {
  static const String _collectionName = 'dummyRivers';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user ID
  String? get _currentUserId => _auth.currentUser?.uid;

  /// Get collection reference for current user's dummy rivers
  CollectionReference get _userDummyRiversCollection {
    if (_currentUserId == null) {
      throw Exception('User must be authenticated to access dummy rivers');
    }
    return _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection(_collectionName);
  }

  /// Create a new dummy river
  Future<String> createDummyRiver(DummyRiver dummyRiver) async {
    try {
      final docRef = await _userDummyRiversCollection.add(dummyRiver.toJson());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create dummy river: $e');
    }
  }

  /// Get all dummy rivers for current user
  Future<List<DummyRiver>> getDummyRivers() async {
    try {
      final querySnapshot =
          await _userDummyRiversCollection
              .orderBy('createdAt', descending: true)
              .get();

      return querySnapshot.docs
          .map(
            (doc) =>
                DummyRiver.fromJson(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to get dummy rivers: $e');
    }
  }

  /// Get a specific dummy river by ID
  Future<DummyRiver?> getDummyRiver(String id) async {
    try {
      final doc = await _userDummyRiversCollection.doc(id).get();

      if (!doc.exists) return null;

      return DummyRiver.fromJson(doc.data() as Map<String, dynamic>, doc.id);
    } catch (e) {
      throw Exception('Failed to get dummy river: $e');
    }
  }

  /// Update an existing dummy river
  Future<void> updateDummyRiver(DummyRiver dummyRiver) async {
    try {
      await _userDummyRiversCollection
          .doc(dummyRiver.id)
          .update(dummyRiver.toJson());
    } catch (e) {
      throw Exception('Failed to update dummy river: $e');
    }
  }

  /// Delete a dummy river
  Future<void> deleteDummyRiver(String id) async {
    try {
      await _userDummyRiversCollection.doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete dummy river: $e');
    }
  }

  /// Stream of dummy rivers for real-time updates
  Stream<List<DummyRiver>> streamDummyRivers() {
    if (_currentUserId == null) {
      return Stream.value([]);
    }

    return _userDummyRiversCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map(
                    (doc) => DummyRiver.fromJson(
                      doc.data() as Map<String, dynamic>,
                      doc.id,
                    ),
                  )
                  .toList(),
        );
  }

  /// Create a dummy river with preset testing scenarios
  Future<String> createTestScenario({
    required String scenarioName,
    required String description,
    required Map<int, double> returnPeriods,
    String unit = 'cfs',
  }) async {
    final dummyRiver = DummyRiver(
      id: '', // Will be set by Firestore
      name: scenarioName,
      description: description,
      returnPeriods: returnPeriods,
      unit: unit,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return await createDummyRiver(dummyRiver);
  }

  /// Create common test scenarios
  Future<List<String>> createCommonTestScenarios() async {
    final scenarios = [
      {
        'name': 'Low Flow Test River',
        'description': 'Test river with low return period thresholds',
        'returnPeriods': {2: 1000.0, 5: 2000.0, 10: 3000.0, 25: 4000.0},
        'unit': 'cfs',
      },
      {
        'name': 'High Flow Test River',
        'description': 'Test river with high return period thresholds',
        'returnPeriods': {
          2: 15000.0,
          5: 25000.0,
          10: 35000.0,
          25: 45000.0,
          50: 55000.0,
        },
        'unit': 'cfs',
      },
      {
        'name': 'Metric Test River',
        'description': 'Test river using cubic meters per second',
        'returnPeriods': {2: 100.0, 5: 200.0, 10: 350.0, 25: 500.0},
        'unit': 'cms',
      },
      {
        'name': 'Edge Case Test River',
        'description': 'Test river with very close return period values',
        'returnPeriods': {2: 5000.0, 5: 5100.0, 10: 5200.0, 25: 5300.0},
        'unit': 'cfs',
      },
    ];

    final createdIds = <String>[];

    for (final scenario in scenarios) {
      try {
        final id = await createTestScenario(
          scenarioName: scenario['name'] as String,
          description: scenario['description'] as String,
          returnPeriods: scenario['returnPeriods'] as Map<int, double>,
          unit: scenario['unit'] as String,
        );
        createdIds.add(id);
      } catch (e) {
        // Continue with other scenarios even if one fails
        print('Failed to create scenario ${scenario['name']}: $e');
      }
    }

    return createdIds;
  }

  /// Update return period for a specific dummy river
  Future<void> updateReturnPeriod(
    String dummyRiverId,
    int year,
    double flow,
  ) async {
    try {
      final dummyRiver = await getDummyRiver(dummyRiverId);
      if (dummyRiver == null) {
        throw Exception('Dummy river not found');
      }

      final updated = dummyRiver.updateReturnPeriod(year, flow);
      await updateDummyRiver(updated);
    } catch (e) {
      throw Exception('Failed to update return period: $e');
    }
  }

  /// Remove return period for a specific dummy river
  Future<void> removeReturnPeriod(String dummyRiverId, int year) async {
    try {
      final dummyRiver = await getDummyRiver(dummyRiverId);
      if (dummyRiver == null) {
        throw Exception('Dummy river not found');
      }

      final updated = dummyRiver.removeReturnPeriod(year);
      await updateDummyRiver(updated);
    } catch (e) {
      throw Exception('Failed to remove return period: $e');
    }
  }

  /// Bulk update return periods for a dummy river
  Future<void> updateAllReturnPeriods(
    String dummyRiverId,
    Map<int, double> newReturnPeriods,
  ) async {
    try {
      final dummyRiver = await getDummyRiver(dummyRiverId);
      if (dummyRiver == null) {
        throw Exception('Dummy river not found');
      }

      final updated = dummyRiver.copyWith(
        returnPeriods: newReturnPeriods,
        updatedAt: DateTime.now(),
      );

      await updateDummyRiver(updated);
    } catch (e) {
      throw Exception('Failed to update return periods: $e');
    }
  }

  /// Check if dummy river name already exists for current user
  Future<bool> isDummyRiverNameExists(String name, {String? excludeId}) async {
    try {
      final querySnapshot =
          await _userDummyRiversCollection.where('name', isEqualTo: name).get();

      if (excludeId != null) {
        return querySnapshot.docs.any((doc) => doc.id != excludeId);
      }

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      return false; // Assume name doesn't exist if we can't check
    }
  }

  /// Get dummy rivers count for current user
  Future<int> getDummyRiversCount() async {
    try {
      final querySnapshot = await _userDummyRiversCollection.get();
      return querySnapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  /// Delete all dummy rivers for current user (for cleanup/testing)
  Future<void> deleteAllDummyRivers() async {
    try {
      final querySnapshot = await _userDummyRiversCollection.get();

      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to delete all dummy rivers: $e');
    }
  }

  /// Validate dummy river data before saving
  static List<String> validateDummyRiver(DummyRiver dummyRiver) {
    final errors = <String>[];

    // Name validation
    if (dummyRiver.name.trim().isEmpty) {
      errors.add('River name is required');
    } else if (dummyRiver.name.length > 100) {
      errors.add('River name must be 100 characters or less');
    }

    // Description validation
    if (dummyRiver.description.length > 500) {
      errors.add('Description must be 500 characters or less');
    }

    // Unit validation
    const validUnits = ['cfs', 'cms', 'm3/s', 'ft3/s'];
    if (!validUnits.contains(dummyRiver.unit.toLowerCase())) {
      errors.add('Unit must be one of: ${validUnits.join(', ')}');
    }

    // Return periods validation
    errors.addAll(dummyRiver.returnPeriodsValidationErrors);

    return errors;
  }
}
