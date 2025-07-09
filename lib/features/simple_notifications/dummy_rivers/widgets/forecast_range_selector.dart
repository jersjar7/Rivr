// lib/features/simple_notifications/dummy_rivers/widgets/forecast_range_selector.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/dummy_river.dart';
import '../models/dummy_river_forecast.dart';
import '../providers/dummy_river_forecast_provider.dart';

class ForecastRangeSelector extends StatefulWidget {
  final DummyRiver dummyRiver;
  final ForecastRange range;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color? color;
  final VoidCallback? onChanged;

  const ForecastRangeSelector({
    super.key,
    required this.dummyRiver,
    required this.range,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.color,
    this.onChanged,
  });

  @override
  State<ForecastRangeSelector> createState() => _ForecastRangeSelectorState();
}

class _ForecastRangeSelectorState extends State<ForecastRangeSelector> {
  late TextEditingController _minController;
  late TextEditingController _maxController;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _minController = TextEditingController();
    _maxController = TextEditingController();

    // Initialize controllers with existing values
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateControllersFromProvider();
    });
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  void _updateControllersFromProvider() {
    final formProvider = Provider.of<DummyRiverForecastFormProvider>(
      context,
      listen: false,
    );

    switch (widget.range) {
      case ForecastRange.shortRange:
        _minController.text = formProvider.shortRangeMin?.toString() ?? '';
        _maxController.text = formProvider.shortRangeMax?.toString() ?? '';
        break;
      case ForecastRange.mediumRange:
        _minController.text = formProvider.mediumRangeMin?.toString() ?? '';
        _maxController.text = formProvider.mediumRangeMax?.toString() ?? '';
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DummyRiverForecastFormProvider>(
      builder: (context, formProvider, child) {
        final hasData = _hasRangeData(formProvider);
        final errors = _getRangeErrors(formProvider);

        return Card(
          child: Column(
            children: [
              _buildHeader(hasData, errors.isNotEmpty),
              if (_isExpanded) _buildExpandedContent(formProvider, errors),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool hasData, bool hasErrors) {
    return InkWell(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (widget.color ?? Colors.blue).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                widget.icon,
                color: widget.color ?? Colors.blue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            if (hasData) _buildStatusChip(hasErrors),
            const SizedBox(width: 8),
            Icon(
              _isExpanded ? Icons.expand_less : Icons.expand_more,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(bool hasErrors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color:
            hasErrors
                ? Colors.red.withOpacity(0.1)
                : Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              hasErrors
                  ? Colors.red.withOpacity(0.3)
                  : Colors.green.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasErrors ? Icons.error : Icons.check,
            size: 12,
            color: hasErrors ? Colors.red : Colors.green,
          ),
          const SizedBox(width: 4),
          Text(
            hasErrors ? 'Error' : 'Set',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: hasErrors ? Colors.red : Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(
    DummyRiverForecastFormProvider formProvider,
    List<String> errors,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 8),
          _buildFlowRangeInputs(formProvider),
          const SizedBox(height: 16),
          _buildQuickActions(formProvider),
          if (errors.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildErrorDisplay(errors),
          ],
        ],
      ),
    );
  }

  Widget _buildFlowRangeInputs(DummyRiverForecastFormProvider formProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Flow Range (${widget.dummyRiver.unit})',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildFlowInput(
                controller: _minController,
                label: 'Minimum',
                hint: 'Min flow',
                onChanged: (value) => _updateMinValue(formProvider, value),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildFlowInput(
                controller: _maxController,
                label: 'Maximum',
                hint: 'Max flow',
                onChanged: (value) => _updateMaxValue(formProvider, value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildRangePreview(formProvider),
      ],
    );
  }

  Widget _buildFlowInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            suffixText: widget.dummyRiver.unit,
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildRangePreview(DummyRiverForecastFormProvider formProvider) {
    final min = _getCurrentMin(formProvider);
    final max = _getCurrentMax(formProvider);

    if (min == null || max == null) {
      return const SizedBox.shrink();
    }

    final range = max - min;
    final midpoint = (min + max) / 2;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.trending_up,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
          const SizedBox(width: 8),
          Text(
            'Range: ${_formatFlow(range)} ${widget.dummyRiver.unit} • Midpoint: ${_formatFlow(midpoint)}',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(DummyRiverForecastFormProvider formProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildQuickActionChip(
              'Load Defaults',
              Icons.auto_fix_high,
              () => _loadDefaults(formProvider),
            ),
            _buildQuickActionChip(
              'Low Alert',
              Icons.notification_important,
              () => _setAlertLevel(formProvider, 'low'),
            ),
            _buildQuickActionChip(
              'High Alert',
              Icons.warning,
              () => _setAlertLevel(formProvider, 'high'),
            ),
            _buildQuickActionChip(
              'Clear',
              Icons.clear,
              () => _clearRange(formProvider),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionChip(
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onTap,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }

  Widget _buildErrorDisplay(List<String> errors) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error, color: Colors.red, size: 16),
              SizedBox(width: 8),
              Text(
                'Validation Errors',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...errors.map(
            (error) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• $error',
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  bool _hasRangeData(DummyRiverForecastFormProvider formProvider) {
    switch (widget.range) {
      case ForecastRange.shortRange:
        return formProvider.hasShortRangeData;
      case ForecastRange.mediumRange:
        return formProvider.hasMediumRangeData;
    }
  }

  List<String> _getRangeErrors(DummyRiverForecastFormProvider formProvider) {
    final errors = <String>[];
    final allErrors = formProvider.errors;

    switch (widget.range) {
      case ForecastRange.shortRange:
        if (allErrors.containsKey('shortMin'))
          errors.add(allErrors['shortMin']!);
        if (allErrors.containsKey('shortMax'))
          errors.add(allErrors['shortMax']!);
        if (allErrors.containsKey('shortRange'))
          errors.add(allErrors['shortRange']!);
        break;
      case ForecastRange.mediumRange:
        if (allErrors.containsKey('mediumMin'))
          errors.add(allErrors['mediumMin']!);
        if (allErrors.containsKey('mediumMax'))
          errors.add(allErrors['mediumMax']!);
        if (allErrors.containsKey('mediumRange'))
          errors.add(allErrors['mediumRange']!);
        break;
    }

    return errors;
  }

  double? _getCurrentMin(DummyRiverForecastFormProvider formProvider) {
    switch (widget.range) {
      case ForecastRange.shortRange:
        return formProvider.shortRangeMin;
      case ForecastRange.mediumRange:
        return formProvider.mediumRangeMin;
    }
  }

  double? _getCurrentMax(DummyRiverForecastFormProvider formProvider) {
    switch (widget.range) {
      case ForecastRange.shortRange:
        return formProvider.shortRangeMax;
      case ForecastRange.mediumRange:
        return formProvider.mediumRangeMax;
    }
  }

  void _updateMinValue(
    DummyRiverForecastFormProvider formProvider,
    String value,
  ) {
    final doubleValue = double.tryParse(value);
    switch (widget.range) {
      case ForecastRange.shortRange:
        formProvider.updateShortRange(min: doubleValue);
        break;
      case ForecastRange.mediumRange:
        formProvider.updateMediumRange(min: doubleValue);
        break;
    }
    widget.onChanged?.call();
  }

  void _updateMaxValue(
    DummyRiverForecastFormProvider formProvider,
    String value,
  ) {
    final doubleValue = double.tryParse(value);
    switch (widget.range) {
      case ForecastRange.shortRange:
        formProvider.updateShortRange(max: doubleValue);
        break;
      case ForecastRange.mediumRange:
        formProvider.updateMediumRange(max: doubleValue);
        break;
    }
    widget.onChanged?.call();
  }

  void _loadDefaults(DummyRiverForecastFormProvider formProvider) {
    final returnPeriods = widget.dummyRiver.returnPeriods;
    if (returnPeriods.isEmpty) return;

    final sortedPeriods =
        returnPeriods.entries.toList()
          ..sort((a, b) => a.value.compareTo(b.value));

    final minReturnFlow = sortedPeriods.first.value;
    final maxReturnFlow = sortedPeriods.last.value;

    double min, max;
    switch (widget.range) {
      case ForecastRange.shortRange:
        min = minReturnFlow * 0.8;
        max = maxReturnFlow * 0.9;
        formProvider.updateShortRange(min: min, max: max);
        break;
      case ForecastRange.mediumRange:
        min = minReturnFlow * 0.7;
        max = maxReturnFlow * 0.8;
        formProvider.updateMediumRange(min: min, max: max);
        break;
    }

    _updateControllersFromProvider();
    widget.onChanged?.call();
  }

  void _setAlertLevel(
    DummyRiverForecastFormProvider formProvider,
    String level,
  ) {
    final returnPeriods = widget.dummyRiver.returnPeriods;
    if (returnPeriods.isEmpty) return;

    final sortedPeriods =
        returnPeriods.entries.toList()
          ..sort((a, b) => a.value.compareTo(b.value));

    double min, max;
    if (level == 'low') {
      // Flows below 2-year return period
      final threshold = sortedPeriods.first.value;
      min = threshold * 0.3;
      max = threshold * 0.8;
    } else {
      // Flows above 25-year return period
      final threshold =
          sortedPeriods.length > 3
              ? sortedPeriods[sortedPeriods.length - 2].value
              : sortedPeriods.last.value;
      min = threshold * 1.1;
      max = threshold * 1.5;
    }

    switch (widget.range) {
      case ForecastRange.shortRange:
        formProvider.updateShortRange(min: min, max: max);
        break;
      case ForecastRange.mediumRange:
        formProvider.updateMediumRange(min: min, max: max);
        break;
    }

    _updateControllersFromProvider();
    widget.onChanged?.call();
  }

  void _clearRange(DummyRiverForecastFormProvider formProvider) {
    switch (widget.range) {
      case ForecastRange.shortRange:
        formProvider.clearShortRange();
        break;
      case ForecastRange.mediumRange:
        formProvider.clearMediumRange();
        break;
    }

    _minController.clear();
    _maxController.clear();
    widget.onChanged?.call();
  }

  String _formatFlow(double flow) {
    if (flow >= 1000000) {
      return '${(flow / 1000000).toStringAsFixed(1)}M';
    } else if (flow >= 1000) {
      return '${(flow / 1000).toStringAsFixed(1)}K';
    } else {
      return flow.toStringAsFixed(0);
    }
  }
}
