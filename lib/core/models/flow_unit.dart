// lib/core/models/flow_unit.dart

/// Represents a flow measurement unit
enum FlowUnit {
  /// Cubic feet per second
  cfs,

  /// Cubic meters per second
  cms;

  /// Conversion factor from cubic meters per second to cubic feet per second
  static const double cmsToFcsFactor = 35.3147;

  /// Conversion factor from cubic feet per second to cubic meters per second
  static const double cfsToFcmsFactor = 0.0283168;

  /// Returns the display name of the unit
  String get display {
    switch (this) {
      case FlowUnit.cfs:
        return 'ft³/s';
      case FlowUnit.cms:
        return 'm³/s';
    }
  }

  /// Returns the short name of the unit
  String get shortName {
    switch (this) {
      case FlowUnit.cfs:
        return 'CFS';
      case FlowUnit.cms:
        return 'CMS';
    }
  }

  /// Returns the opposite unit
  FlowUnit get opposite {
    switch (this) {
      case FlowUnit.cfs:
        return FlowUnit.cms;
      case FlowUnit.cms:
        return FlowUnit.cfs;
    }
  }
}
