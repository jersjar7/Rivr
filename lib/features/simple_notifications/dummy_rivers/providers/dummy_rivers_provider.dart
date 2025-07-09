import 'package:flutter/foundation.dart';
import '../models/dummy_river.dart';
import '../services/dummy_rivers_service.dart';

class DummyRiversProvider extends ChangeNotifier {
  final DummyRiversService _service = DummyRiversService();

  List<DummyRiver> _rivers = [];
  bool _isLoading = false;
  String? _error;
  DummyRiver? _selectedRiver;

  // Getters
  List<DummyRiver> get rivers => _rivers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DummyRiver? get selectedRiver => _selectedRiver;
  int get riversCount => _rivers.length;
  bool get hasError => _error != null;

  /// Load all dummy rivers
  Future<void> loadDummyRivers() async {
    _setLoading(true);
    _clearError();

    try {
      _rivers = await _service.getDummyRivers();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// Create a new dummy river
  Future<String?> createDummyRiver(DummyRiver dummyRiver) async {
    try {
      // Validate before creating
      final validationErrors = DummyRiversService.validateDummyRiver(
        dummyRiver,
      );
      if (validationErrors.isNotEmpty) {
        _setError(validationErrors.join('\n'));
        return null;
      }

      // Check for duplicate name
      final nameExists = await _service.isDummyRiverNameExists(dummyRiver.name);
      if (nameExists) {
        _setError('A dummy river with this name already exists');
        return null;
      }

      final id = await _service.createDummyRiver(dummyRiver);
      await loadDummyRivers(); // Refresh list
      _clearError();
      return id;
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  /// Update an existing dummy river
  Future<bool> updateDummyRiver(DummyRiver dummyRiver) async {
    try {
      // Validate before updating
      final validationErrors = DummyRiversService.validateDummyRiver(
        dummyRiver,
      );
      if (validationErrors.isNotEmpty) {
        _setError(validationErrors.join('\n'));
        return false;
      }

      // Check for duplicate name (excluding current river)
      final nameExists = await _service.isDummyRiverNameExists(
        dummyRiver.name,
        excludeId: dummyRiver.id,
      );
      if (nameExists) {
        _setError('A dummy river with this name already exists');
        return false;
      }

      await _service.updateDummyRiver(dummyRiver);
      await loadDummyRivers(); // Refresh list
      _clearError();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// Delete a dummy river
  Future<bool> deleteDummyRiver(String id) async {
    try {
      await _service.deleteDummyRiver(id);
      await loadDummyRivers(); // Refresh list
      _clearError();

      // Clear selected river if it was deleted
      if (_selectedRiver?.id == id) {
        _selectedRiver = null;
        notifyListeners();
      }

      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// Select a dummy river
  void selectRiver(DummyRiver river) {
    _selectedRiver = river;
    notifyListeners();
  }

  /// Clear selected river
  void clearSelectedRiver() {
    _selectedRiver = null;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _clearError();
  }

  /// Create common test scenarios
  Future<bool> createTestScenarios() async {
    _setLoading(true);
    _clearError();

    try {
      await _service.createCommonTestScenarios();
      await loadDummyRivers(); // Refresh list
      return true;
    } catch (e) {
      _setError('Failed to create test scenarios: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Update return period for a specific river
  Future<bool> updateReturnPeriod(String riverId, int year, double flow) async {
    try {
      await _service.updateReturnPeriod(riverId, year, flow);
      await loadDummyRivers(); // Refresh list

      // Update selected river if it's the one being modified
      if (_selectedRiver?.id == riverId) {
        _selectedRiver = _rivers.firstWhere((r) => r.id == riverId);
        notifyListeners();
      }

      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// Remove return period for a specific river
  Future<bool> removeReturnPeriod(String riverId, int year) async {
    try {
      await _service.removeReturnPeriod(riverId, year);
      await loadDummyRivers(); // Refresh list

      // Update selected river if it's the one being modified
      if (_selectedRiver?.id == riverId) {
        _selectedRiver = _rivers.firstWhere((r) => r.id == riverId);
        notifyListeners();
      }

      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// Bulk update return periods
  Future<bool> updateAllReturnPeriods(
    String riverId,
    Map<int, double> returnPeriods,
  ) async {
    try {
      await _service.updateAllReturnPeriods(riverId, returnPeriods);
      await loadDummyRivers(); // Refresh list

      // Update selected river if it's the one being modified
      if (_selectedRiver?.id == riverId) {
        _selectedRiver = _rivers.firstWhere((r) => r.id == riverId);
        notifyListeners();
      }

      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// Delete all dummy rivers
  Future<bool> deleteAllDummyRivers() async {
    try {
      await _service.deleteAllDummyRivers();
      _rivers = [];
      _selectedRiver = null;
      _clearError();
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }
}

class DummyRiverFormProvider extends ChangeNotifier {
  String _name = '';
  String _description = '';
  String _unit = 'cfs';
  Map<int, double> _returnPeriods = {};
  List<String> _validationErrors = [];
  bool _isSubmitting = false;

  // Getters
  String get name => _name;
  String get description => _description;
  String get unit => _unit;
  Map<int, double> get returnPeriods => Map.from(_returnPeriods);
  List<String> get validationErrors => List.from(_validationErrors);
  bool get isSubmitting => _isSubmitting;
  bool get hasValidationErrors => _validationErrors.isNotEmpty;

  void updateName(String name) {
    _name = name;
    _validationErrors.clear();
    notifyListeners();
  }

  void updateDescription(String description) {
    _description = description;
    notifyListeners();
  }

  void updateUnit(String unit) {
    _unit = unit;
    notifyListeners();
  }

  void updateReturnPeriod(int year, double flow) {
    _returnPeriods[year] = flow;
    _validationErrors.clear();
    notifyListeners();
  }

  void removeReturnPeriod(int year) {
    _returnPeriods.remove(year);
    notifyListeners();
  }

  void loadFromDummyRiver(DummyRiver river) {
    _name = river.name;
    _description = river.description;
    _unit = river.unit;
    _returnPeriods = Map.from(river.returnPeriods);
    _validationErrors.clear();
    _isSubmitting = false;
    notifyListeners();
  }

  void reset() {
    _name = '';
    _description = '';
    _unit = 'cfs';
    _returnPeriods = {};
    _validationErrors.clear();
    _isSubmitting = false;
    notifyListeners();
  }

  void setSubmitting(bool isSubmitting) {
    _isSubmitting = isSubmitting;
    notifyListeners();
  }

  void setValidationErrors(List<String> errors) {
    _validationErrors = List.from(errors);
    notifyListeners();
  }

  /// Load default test values
  void loadDefaults() {
    _name = 'Test River ${DateTime.now().millisecondsSinceEpoch}';
    _description = 'Test river for notifications';
    _unit = 'cfs';
    _returnPeriods = {
      2: 5000.0,
      5: 8000.0,
      10: 12000.0,
      25: 15000.0,
      50: 18000.0,
    };
    _validationErrors.clear();
    notifyListeners();
  }

  /// Convert form state to DummyRiver
  DummyRiver toDummyRiver({String? id}) {
    final now = DateTime.now();
    return DummyRiver(
      id: id ?? '',
      name: _name.trim(),
      description: _description.trim(),
      returnPeriods: Map.from(_returnPeriods),
      unit: _unit,
      createdAt: now,
      updatedAt: now,
    );
  }
}
