// lib/features/forecast/utils/format_large_numbers.dart

String formatLargeNumber(double value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(0)}M';
  } else if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(0)}K';
  } else {
    return value.toStringAsFixed(0);
  }
}
