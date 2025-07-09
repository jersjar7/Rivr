// lib/features/simple_notifications/dummy_rivers/providers/dummy_river_forecast_provider.dart

import 'package:flutter/foundation.dart';
import '../models/dummy_river_forecast.dart';
import '../models/dummy_river.dart';
import '../services/dummy_river_forecast_service.dart';

/// Main provider for managing dummy river forecast data
class DummyRiverForecastProvider extends ChangeNotifier {
  final DummyRiverForecastService _service = DummyRiverForecastService();

  // State
  Map<String, DummyRiverForecast> _forecasts = {};
  bool _isLoading = false;
  String? _error;
  String? _selectedRiverId;
  ForecastSummary? _currentSummary;

  // Getters
  Map<String, DummyRiverForecast> get forecasts => Map.unmodifiable(_forecasts);
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedRiverId => _selectedRiverId;
  ForecastSummary? get currentSummary => _currentSummary;

  DummyRiverForecast? get selectedForecast {
    if (_selectedRiverId == null) return null;
    return _forecasts[_selectedRiverId];
  }

  bool get hasForecasts => _forecasts.isNotEmpty;
  int get forecastCount => _forecasts.length;

  /// Initialize provider and load cached forecasts
  void initialize() {
    _loadCachedForecasts();
  }

  /// Load all cached forecasts from service
  void _loadCachedForecasts() {
    try {
      _forecasts = _service.getAllCachedForecasts();
      _clearError();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load cached forecasts: $e');
    }
  }

  /// Generate forecasts with custom flow ranges
  Future<void> generateCustomForecasts({
    required String riverId,
    required String riverName,
    required String unit,
    double? shortRangeMin,
    double? shortRangeMax,
    double? mediumRangeMin,
    double? mediumRangeMax,
    int shortRangeHours = 18,
    int mediumRangeDays = 10,
  }) async {
    _setLoading(true);

    try {
      final forecast = _service.generateForecasts(
        riverId: riverId,
        riverName: riverName,
        unit: unit,
        shortRangeMin: shortRangeMin,
        shortRangeMax: shortRangeMax,
        mediumRangeMin: mediumRangeMin,
        mediumRangeMax: mediumRangeMax,
        shortRangeHours: shortRangeHours,
        mediumRangeDays: mediumRangeDays,
      );

      _forecasts[riverId] = forecast;
      _selectedRiverId = riverId;
      _clearError();
    } catch (e) {
      _setError('Failed to generate forecasts: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Generate forecasts using preset scenario
  Future<void> generateScenarioForecasts({
    required String riverId,
    required String riverName,
    required DummyRiver dummyRiver,
    required ForecastScenario scenario,
  }) async {
    _setLoading(true);

    try {
      final forecast = _service.generateScenarioForecasts(
        riverId: riverId,
        riverName: riverName,
        dummyRiver: dummyRiver,
        scenario: scenario,
      );

      _forecasts[riverId] = forecast;
      _selectedRiverId = riverId;
      _clearError();
    } catch (e) {
      _setError('Failed to generate scenario forecasts: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Update specific forecast range
  Future<void> updateForecastRange({
    required String riverId,
    required ForecastRange range,
    required String unit,
    required double minFlow,
    required double maxFlow,
    int? pointCount,
  }) async {
    _setLoading(true);

    try {
      final updatedForecast = _service.updateForecastRange(
        riverId: riverId,
        range: range,
        unit: unit,
        minFlow: minFlow,
        maxFlow: maxFlow,
        pointCount: pointCount,
      );

      _forecasts[riverId] = updatedForecast;
      _clearError();
    } catch (e) {
      _setError('Failed to update forecast range: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Calculate and update forecast summary
  void updateForecastSummary(String riverId, Map<int, double> returnPeriods) {
    final forecast = _forecasts[riverId];
    if (forecast != null) {
      _currentSummary = _service.getForecastSummary(forecast, returnPeriods);
      notifyListeners();
    }
  }

  /// Select a river for detailed view
  void selectRiver(String riverId) {
    _selectedRiverId = riverId;
    notifyListeners();
  }

  /// Clear selection
  void clearSelection() {
    _selectedRiverId = null;
    _currentSummary = null;
    notifyListeners();
  }

  /// Clear forecast for specific river
  void clearForecast(String riverId) {
    _service.clearForecast(riverId);
    _forecasts.remove(riverId);

    if (_selectedRiverId == riverId) {
      _selectedRiverId = null;
      _currentSummary = null;
    }

    notifyListeners();
  }

  /// Clear all forecasts
  void clearAllForecasts() {
    _service.clearAllForecasts();
    _forecasts.clear();
    _selectedRiverId = null;
    _currentSummary = null;
    notifyListeners();
  }

  /// Check if river has forecast
  bool hasForecastForRiver(String riverId) {
    return _forecasts.containsKey(riverId);
  }

  /// Get forecast for specific river
  DummyRiverForecast? getForecast(String riverId) {
    return _forecasts[riverId];
  }

  /// Get triggered return periods for river
  Map<int, List<ForecastDataPoint>> getTriggeredReturnPeriods(
    String riverId,
    Map<int, double> returnPeriods,
  ) {
    final forecast = _forecasts[riverId];
    if (forecast == null) return {};

    return _service.calculateTriggeredReturnPeriods(forecast, returnPeriods);
  }

  /// Refresh forecasts (reload from cache)
  void refresh() {
    _loadCachedForecasts();
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    _isLoading = false;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }
}

/// Provider for managing forecast generation forms
class DummyRiverForecastFormProvider extends ChangeNotifier {
  // Form state
  String _unit = 'cfs';
  double? _shortRangeMin;
  double? _shortRangeMax;
  double? _mediumRangeMin;
  double? _mediumRangeMax;
  int _shortRangeHours = 18;
  int _mediumRangeDays = 10;
  ForecastScenario? _selectedScenario;
  bool _isValid = false;
  final Map<String, String> _errors = {};

  // Getters
  String get unit => _unit;
  double? get shortRangeMin => _shortRangeMin;
  double? get shortRangeMax => _shortRangeMax;
  double? get mediumRangeMin => _mediumRangeMin;
  double? get mediumRangeMax => _mediumRangeMax;
  int get shortRangeHours => _shortRangeHours;
  int get mediumRangeDays => _mediumRangeDays;
  ForecastScenario? get selectedScenario => _selectedScenario;
  bool get isValid => _isValid;
  Map<String, String> get errors => Map.unmodifiable(_errors);

  bool get hasShortRangeData =>
      _shortRangeMin != null && _shortRangeMax != null;
  bool get hasMediumRangeData =>
      _mediumRangeMin != null && _mediumRangeMax != null;
  bool get hasAnyRangeData => hasShortRangeData || hasMediumRangeData;

  /// Update unit
  void updateUnit(String unit) {
    _unit = unit;
    _validateForm();
    notifyListeners();
  }

  /// Update short range values
  void updateShortRange({double? min, double? max}) {
    if (min != null) _shortRangeMin = min;
    if (max != null) _shortRangeMax = max;
    _validateForm();
    notifyListeners();
  }

  /// Update medium range values
  void updateMediumRange({double? min, double? max}) {
    if (min != null) _mediumRangeMin = min;
    if (max != null) _mediumRangeMax = max;
    _validateForm();
    notifyListeners();
  }

  /// Update time periods
  void updateTimePeriods({int? shortHours, int? mediumDays}) {
    if (shortHours != null) _shortRangeHours = shortHours;
    if (mediumDays != null) _mediumRangeDays = mediumDays;
    _validateForm();
    notifyListeners();
  }

  /// Select scenario
  void selectScenario(ForecastScenario? scenario) {
    _selectedScenario = scenario;
    _validateForm();
    notifyListeners();
  }

  /// Load defaults based on return periods
  void loadDefaults(Map<int, double> returnPeriods) {
    if (returnPeriods.isEmpty) return;

    final sortedPeriods =
        returnPeriods.entries.toList()
          ..sort((a, b) => a.value.compareTo(b.value));

    final minReturnFlow = sortedPeriods.first.value;
    final maxReturnFlow = sortedPeriods.last.value;

    // Set ranges that would trigger moderate alerts
    _shortRangeMin = minReturnFlow * 0.8;
    _shortRangeMax = maxReturnFlow * 0.9;
    _mediumRangeMin = minReturnFlow * 0.7;
    _mediumRangeMax = maxReturnFlow * 0.8;

    _validateForm();
    notifyListeners();
  }

  /// Clear short range data
  void clearShortRange() {
    _shortRangeMin = null;
    _shortRangeMax = null;
    _validateForm();
    notifyListeners();
  }

  /// Clear medium range data
  void clearMediumRange() {
    _mediumRangeMin = null;
    _mediumRangeMax = null;
    _validateForm();
    notifyListeners();
  }

  /// Reset form to defaults
  void reset() {
    _unit = 'cfs';
    _shortRangeMin = null;
    _shortRangeMax = null;
    _mediumRangeMin = null;
    _mediumRangeMax = null;
    _shortRangeHours = 18;
    _mediumRangeDays = 10;
    _selectedScenario = null;
    _errors.clear();
    _isValid = false;
    notifyListeners();
  }

  /// Validate form data
  void _validateForm() {
    _errors.clear();

    // Check if at least one range is defined
    if (!hasAnyRangeData && _selectedScenario == null) {
      _errors['general'] =
          'Please define at least one forecast range or select a scenario';
    }

    // Validate short range
    if (_shortRangeMin != null || _shortRangeMax != null) {
      if (_shortRangeMin == null) {
        _errors['shortMin'] = 'Short range minimum is required';
      }
      if (_shortRangeMax == null) {
        _errors['shortMax'] = 'Short range maximum is required';
      }
      if (_shortRangeMin != null && _shortRangeMax != null) {
        if (_shortRangeMin! >= _shortRangeMax!) {
          _errors['shortRange'] = 'Minimum must be less than maximum';
        }
        if (_shortRangeMin! < 0) {
          _errors['shortMin'] = 'Flow values must be positive';
        }
      }
    }

    // Validate medium range
    if (_mediumRangeMin != null || _mediumRangeMax != null) {
      if (_mediumRangeMin == null) {
        _errors['mediumMin'] = 'Medium range minimum is required';
      }
      if (_mediumRangeMax == null) {
        _errors['mediumMax'] = 'Medium range maximum is required';
      }
      if (_mediumRangeMin != null && _mediumRangeMax != null) {
        if (_mediumRangeMin! >= _mediumRangeMax!) {
          _errors['mediumRange'] = 'Minimum must be less than maximum';
        }
        if (_mediumRangeMin! < 0) {
          _errors['mediumMin'] = 'Flow values must be positive';
        }
      }
    }

    // Validate time periods
    if (_shortRangeHours < 1 || _shortRangeHours > 72) {
      _errors['shortHours'] = 'Short range hours must be between 1-72';
    }
    if (_mediumRangeDays < 1 || _mediumRangeDays > 30) {
      _errors['mediumDays'] = 'Medium range days must be between 1-30';
    }

    _isValid = _errors.isEmpty;
  }

  /// Get form data for forecast generation
  Map<String, dynamic> getFormData() {
    return {
      'unit': _unit,
      'shortRangeMin': _shortRangeMin,
      'shortRangeMax': _shortRangeMax,
      'mediumRangeMin': _mediumRangeMin,
      'mediumRangeMax': _mediumRangeMax,
      'shortRangeHours': _shortRangeHours,
      'mediumRangeDays': _mediumRangeDays,
      'selectedScenario': _selectedScenario,
    };
  }

  /// Get scenario descriptions for UI
  static List<Map<String, dynamic>> getScenarioOptions() {
    return ForecastScenario.values
        .map(
          (scenario) => {
            'scenario': scenario,
            'name': scenario.toString().split('.').last,
            'description': DummyRiverForecastService.getScenarioDescription(
              scenario,
            ),
            'icon': DummyRiverForecastService.getScenarioIcon(scenario),
          },
        )
        .toList();
  }
}
