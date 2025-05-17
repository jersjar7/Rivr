// lib/core/formatters/flow_value_formatter.dart

import 'package:intl/intl.dart';
import '../models/flow_unit.dart';
import '../services/flow_units_service.dart';

/// A utility class for formatting flow values with appropriate units
class FlowValueFormatter {
  final FlowUnitsService _unitsService;
  final NumberFormat _formatter;

  /// Creates a new formatter with the specified units service and number format
  FlowValueFormatter({
    required FlowUnitsService unitsService,
    NumberFormat? formatter,
  }) : _unitsService = unitsService,
       _formatter = formatter ?? NumberFormat('#,##0.0');

  /// Format a flow value assuming it's in the current preferred unit
  String format(double value) {
    return '${_formatter.format(value)} ${_unitsService.unitLabel}';
  }

  /// Format a flow value that's in the specified unit, converting if necessary
  String formatWithUnit(double value, FlowUnit fromUnit) {
    // Convert the value to the preferred unit
    final convertedValue = _unitsService.convertToPreferredUnit(
      value,
      fromUnit,
    );
    return format(convertedValue);
  }

  /// Format a flow value for compact display (less space)
  String formatCompact(double value) {
    // Use a more compact number format
    final compactFormatter = NumberFormat('#,##0');
    return '${compactFormatter.format(value)} ${_unitsService.unitLabel}';
  }

  /// Format a flow value without units (just the number)
  String formatNumberOnly(double value) {
    return _formatter.format(value);
  }

  /// Get just the unit string
  String get unitString => _unitsService.unitLabel;

  /// Get the short unit name (CFS or CMS)
  String get shortUnitName => _unitsService.unitShortName;
}

/// Extension methods for double to make formatting easier
extension FlowValueFormatterExtension on double {
  /// Format this value as a flow with the given formatter
  String formatFlow(FlowValueFormatter formatter) {
    return formatter.format(this);
  }

  /// Format this value assuming it's in CFS, converting if needed
  String formatAsCfs(FlowValueFormatter formatter) {
    return formatter.formatWithUnit(this, FlowUnit.cfs);
  }

  /// Format this value assuming it's in CMS, converting if needed
  String formatAsCms(FlowValueFormatter formatter) {
    return formatter.formatWithUnit(this, FlowUnit.cms);
  }
}
