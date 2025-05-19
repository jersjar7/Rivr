// lib/core/formatters/flow_value_formatter.dart

import 'package:intl/intl.dart';
import '../models/flow_unit.dart';
import '../services/flow_units_service.dart';

/// A utility class for formatting flow values with appropriate units
class FlowValueFormatter {
  final FlowUnitsService _unitsService;
  final NumberFormat _formatter;
  final NumberFormat _compactFormatter;
  final NumberFormat _largeFormatter;

  /// Creates a new formatter with the specified units service and number formats
  FlowValueFormatter({
    required FlowUnitsService unitsService,
    NumberFormat? formatter,
    NumberFormat? compactFormatter,
    NumberFormat? largeFormatter,
  }) : _unitsService = unitsService,
       _formatter = formatter ?? NumberFormat('#,##0.0'),
       _compactFormatter = compactFormatter ?? NumberFormat('#,##0'),
       _largeFormatter = largeFormatter ?? NumberFormat.compact();

  String formatRawNumber(double value) {
    if (value.isNaN || value.isInfinite) return 'Invalid';
    return _formatter.format(
      value,
    ); // Always use regular formatter, never compact
  }

  String formatIntegerOnly(double value) {
    if (value.isNaN || value.isInfinite) return 'Invalid';
    return NumberFormat('#,##0').format(value.ceil());
  }

  /// Format a flow value assuming it's in the current preferred unit
  String format(double value) {
    if (value.isNaN || value.isInfinite) return 'Invalid';
    return '${_formatter.format(value)} ${_unitsService.unitLabel}';
  }

  /// Format a flow value that's in the specified unit, converting if necessary
  String formatWithUnit(double value, FlowUnit fromUnit) {
    if (value.isNaN || value.isInfinite) return 'Invalid';

    // Convert the value to the preferred unit
    final convertedValue = _unitsService.convertToPreferredUnit(
      value,
      fromUnit,
    );
    return format(convertedValue);
  }

  /// Format a flow value for compact display (less space)
  String formatCompact(double value) {
    if (value.isNaN || value.isInfinite) return 'Invalid';

    // Use a more compact number format
    return '${_compactFormatter.format(value)} ${_unitsService.unitLabel}';
  }

  /// Format a flow value without units (just the number)
  String formatNumberOnly(double value) {
    if (value.isNaN || value.isInfinite) return 'Invalid';

    // Choose formatter based on the size of the number
    final formatter = value >= 10000 ? _largeFormatter : _formatter;
    return formatter.format(value);
  }

  /// Format a flow value that needs to be converted first, returning just the number
  String formatNumberOnlyWithConversion(double value, FlowUnit fromUnit) {
    if (value.isNaN || value.isInfinite) return 'Invalid';

    final convertedValue = _unitsService.convertToPreferredUnit(
      value,
      fromUnit,
    );
    return formatNumberOnly(convertedValue);
  }

  /// Format a range of values (e.g., min-max)
  String formatRange(double minValue, double maxValue) {
    if (minValue.isNaN ||
        maxValue.isNaN ||
        minValue.isInfinite ||
        maxValue.isInfinite)
      return 'Invalid range';

    return '${_formatter.format(minValue)}-${_formatter.format(maxValue)} ${_unitsService.unitLabel}';
  }

  /// Format a flow value with a percentage change indicator
  String formatWithPercentChange(double current, double reference) {
    if (current.isNaN || reference.isNaN || reference == 0)
      return format(current);

    final percentChange = ((current - reference) / reference * 100).round();
    final sign = percentChange > 0 ? '+' : '';
    return '${_formatter.format(current)} ${_unitsService.unitLabel} ($sign$percentChange%)';
  }

  /// Format a flow value with appropriate suffix for large numbers (K, M)
  String formatLarge(double value) {
    if (value.isNaN || value.isInfinite) return 'Invalid';

    return '${_largeFormatter.format(value)} ${_unitsService.unitLabel}';
  }

  /// Get just the unit string
  String get unitString => _unitsService.unitLabel;

  /// Get the short unit name (CFS or CMS)
  String get shortUnitName => _unitsService.unitShortName;

  /// Check if the current unit is CFS
  bool get isCfs => _unitsService.preferredUnit == FlowUnit.cfs;

  /// Check if the current unit is CMS
  bool get isCms => _unitsService.preferredUnit == FlowUnit.cms;

  /// Format a threshold value (for return periods)
  String formatThreshold(double value) {
    if (value.isNaN || value.isInfinite) return 'Invalid';

    return '${_formatter.format(value)} ${_unitsService.unitLabel}';
  }
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

  /// Format this value as a number only (no units)
  String formatFlowNumberOnly(FlowValueFormatter formatter) {
    return formatter.formatNumberOnly(this);
  }
}

/// Extension methods for List<double> to make batch formatting easier
extension FlowListFormatterExtension on List<double> {
  /// Format all values in this list assuming they're in the given unit
  List<String> formatFlowList(FlowValueFormatter formatter, FlowUnit fromUnit) {
    return map((value) => formatter.formatWithUnit(value, fromUnit)).toList();
  }
}
