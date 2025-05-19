// lib/core/services/flow_units_service.dart

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/flow_unit.dart';

/// Service for managing flow unit preferences and conversions
class FlowUnitsService extends ChangeNotifier {
  static const String _preferenceKey = 'preferred_flow_unit';

  /// The current flow unit preference
  FlowUnit _preferredUnit = FlowUnit.cfs; // Default to CFS

  /// A reference to the shared preferences instance
  final SharedPreferences _preferences;

  /// Constructor with required SharedPreferences dependency
  FlowUnitsService({required SharedPreferences preferences})
    : _preferences = preferences {
    _loadPreference();
  }

  /// Gets the user's preferred flow unit
  FlowUnit get preferredUnit => _preferredUnit;

  /// Sets the user's preferred flow unit and notifies listeners
  Future<void> setPreferredUnit(FlowUnit unit) async {
    if (unit == _preferredUnit) return;

    _preferredUnit = unit;
    await _preferences.setString(_preferenceKey, unit.toString());
    notifyListeners();
  }

  /// Toggle between CFS and CMS units
  Future<void> toggleUnit() async {
    await setPreferredUnit(_preferredUnit.opposite);
  }

  /// Load saved preference from SharedPreferences
  void _loadPreference() {
    final savedPref = _preferences.getString(_preferenceKey);
    if (savedPref != null) {
      try {
        if (savedPref.contains('cfs')) {
          _preferredUnit = FlowUnit.cfs;
        } else if (savedPref.contains('cms')) {
          _preferredUnit = FlowUnit.cms;
        }
      } catch (e) {
        debugPrint('Error loading flow unit preference: $e');
        // Keep default value
      }
    }
  }

  /// Converts flow value from CFS to CMS
  double cfsToCms(double flowInCfs) {
    if (flowInCfs == 0) return 0;
    return flowInCfs * FlowUnit.cfsToFcmsFactor;
  }

  /// Converts flow value from CMS to CFS
  double cmsToCfs(double flowInCms) {
    if (flowInCms == 0) return 0;
    return flowInCms * FlowUnit.cmsToFcsFactor;
  }

  /// Converts a flow value to the preferred unit
  double convertToPreferredUnit(double value, FlowUnit fromUnit) {
    if (fromUnit == _preferredUnit) return value;
    return fromUnit == FlowUnit.cfs ? cfsToCms(value) : cmsToCfs(value);
  }

  /// Converts a flow value from the preferred unit to the specified unit
  double convertFromPreferredUnit(double value, FlowUnit toUnit) {
    if (_preferredUnit == toUnit) return value;
    return _preferredUnit == FlowUnit.cfs ? cfsToCms(value) : cmsToCfs(value);
  }

  /// Converts a list of flow values to the preferred unit
  List<double> convertListToPreferredUnit(
    List<double> values,
    FlowUnit fromUnit,
  ) {
    if (fromUnit == _preferredUnit) return List.from(values);

    return values
        .map((value) => convertToPreferredUnit(value, fromUnit))
        .toList();
  }

  /// Converts a map of flow values to the preferred unit
  Map<K, double> convertMapToPreferredUnit<K>(
    Map<K, double> values,
    FlowUnit fromUnit,
  ) {
    if (fromUnit == _preferredUnit) return Map.from(values);

    final convertedMap = <K, double>{};
    values.forEach((key, value) {
      convertedMap[key] = convertToPreferredUnit(value, fromUnit);
    });
    return convertedMap;
  }

  /// Returns the appropriate unit label based on the preferred unit
  String get unitLabel => _preferredUnit.display;

  /// Returns the short unit name based on the preferred unit
  String get unitShortName => _preferredUnit.shortName;

  /// Get the conversion factor from the source unit to the preferred unit
  double getConversionFactor(FlowUnit fromUnit) {
    if (fromUnit == _preferredUnit) return 1.0;

    return fromUnit == FlowUnit.cfs
        ? FlowUnit.cfsToFcmsFactor
        : FlowUnit.cmsToFcsFactor;
  }
}
