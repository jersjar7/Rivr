// lib/features/simple_notifications/dummy_rivers/widgets/forecast_generator_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/dummy_river.dart';
import '../models/dummy_river_forecast.dart';
import '../providers/dummy_river_forecast_provider.dart';
import 'forecast_range_selector.dart';

class ForecastGeneratorWidget extends StatefulWidget {
  final DummyRiver dummyRiver;
  final Function(Map<String, dynamic>) onGenerate;

  const ForecastGeneratorWidget({
    super.key,
    required this.dummyRiver,
    required this.onGenerate,
  });

  @override
  State<ForecastGeneratorWidget> createState() =>
      _ForecastGeneratorWidgetState();
}

class _ForecastGeneratorWidgetState extends State<ForecastGeneratorWidget> {
  late TextEditingController _shortHoursController;
  late TextEditingController _mediumDaysController;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _shortHoursController = TextEditingController(text: '18');
    _mediumDaysController = TextEditingController(text: '10');

    // Initialize form provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final formProvider = Provider.of<DummyRiverForecastFormProvider>(
        context,
        listen: false,
      );
      formProvider.updateTimePeriods(shortHours: 18, mediumDays: 10);
    });
  }

  @override
  void dispose() {
    _shortHoursController.dispose();
    _mediumDaysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DummyRiverForecastFormProvider>(
      builder: (context, formProvider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildConfigurationCard(formProvider),
            const SizedBox(height: 16),
            _buildRangeSelectors(formProvider),
            const SizedBox(height: 16),
            _buildTimePeriodControls(formProvider),
            const SizedBox(height: 16),
            _buildGenerateSection(formProvider),
          ],
        );
      },
    );
  }

  Widget _buildConfigurationCard(DummyRiverForecastFormProvider formProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Custom Forecast Config',
                  softWrap: true,
                  maxLines: 2,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                _buildStatusIndicator(formProvider),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Set specific flow ranges and time periods for testing',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            _buildUnitSelector(formProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(DummyRiverForecastFormProvider formProvider) {
    final hasData = formProvider.hasAnyRangeData;
    final isValid = formProvider.isValid;

    Color color;
    IconData icon;
    String text;

    if (!hasData) {
      color = Colors.grey;
      icon = Icons.radio_button_unchecked;
      text = 'Not Set';
    } else if (!isValid) {
      color = Colors.red;
      icon = Icons.error;
      text = 'Invalid';
    } else {
      color = Colors.green;
      icon = Icons.check_circle;
      text = 'Ready';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitSelector(DummyRiverForecastFormProvider formProvider) {
    final units = ['cfs', 'cms', 'm³/s', 'ft³/s'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Flow Unit',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<String>(
            value: formProvider.unit,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            items:
                units
                    .map(
                      (unit) =>
                          DropdownMenuItem(value: unit, child: Text(unit)),
                    )
                    .toList(),
            onChanged: (value) {
              if (value != null) {
                formProvider.updateUnit(value);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRangeSelectors(DummyRiverForecastFormProvider formProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Flow Ranges',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Define min/max flow values for forecast generation',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 12),
        ForecastRangeSelector(
          dummyRiver: widget.dummyRiver,
          range: ForecastRange.shortRange,
          title: 'Short Range Forecast',
          subtitle: 'Hourly forecasts for immediate testing',
          icon: Icons.schedule,
          color: Colors.orange,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 8),
        ForecastRangeSelector(
          dummyRiver: widget.dummyRiver,
          range: ForecastRange.mediumRange,
          title: 'Medium Range Forecast',
          subtitle: 'Daily forecasts for extended testing',
          icon: Icons.date_range,
          color: Colors.purple,
          onChanged: () => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildTimePeriodControls(DummyRiverForecastFormProvider formProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.access_time, color: Colors.green),
                const SizedBox(width: 8),
                const Text(
                  'Time Periods',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Configure how many forecast points to generate',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTimePeriodInput(
                    controller: _shortHoursController,
                    label: 'Short Range Hours',
                    subtitle: 'Hourly forecasts',
                    suffix: 'hours',
                    min: 1,
                    max: 72,
                    onChanged: (value) {
                      formProvider.updateTimePeriods(shortHours: value);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTimePeriodInput(
                    controller: _mediumDaysController,
                    label: 'Medium Range Days',
                    subtitle: 'Daily forecasts',
                    suffix: 'days',
                    min: 1,
                    max: 30,
                    onChanged: (value) {
                      formProvider.updateTimePeriods(mediumDays: value);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePeriodInput({
    required TextEditingController controller,
    required String label,
    required String subtitle,
    required String suffix,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            suffixText: suffix,
            helperText: '$min-$max',
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (value) {
            final intValue = int.tryParse(value);
            if (intValue != null && intValue >= min && intValue <= max) {
              onChanged(intValue);
            }
          },
        ),
      ],
    );
  }

  Widget _buildGenerateSection(DummyRiverForecastFormProvider formProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.play_arrow, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Generate Forecasts',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (formProvider.errors.isNotEmpty) ...[
              _buildValidationErrors(formProvider),
              const SizedBox(height: 16),
            ],
            _buildGenerationSummary(formProvider),
            const SizedBox(height: 16),
            _buildGenerateButton(formProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildValidationErrors(DummyRiverForecastFormProvider formProvider) {
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
                'Please fix the following issues:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...formProvider.errors.values.map(
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

  Widget _buildGenerationSummary(DummyRiverForecastFormProvider formProvider) {
    final shortCount =
        formProvider.hasShortRangeData ? formProvider.shortRangeHours : 0;
    final mediumCount =
        formProvider.hasMediumRangeData ? formProvider.mediumRangeDays : 0;
    final totalCount = shortCount + mediumCount;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Generation Summary',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (formProvider.hasShortRangeData)
            _buildSummaryRow(
              'Short Range',
              '$shortCount hourly forecasts',
              Icons.schedule,
              Colors.orange,
            ),
          if (formProvider.hasMediumRangeData)
            _buildSummaryRow(
              'Medium Range',
              '$mediumCount daily forecasts',
              Icons.date_range,
              Colors.purple,
            ),
          if (totalCount > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Total: $totalCount forecast points',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
          ],
          if (totalCount == 0)
            Text(
              'No forecast ranges configured',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGenerateButton(DummyRiverForecastFormProvider formProvider) {
    final canGenerate = formProvider.isValid && !_isGenerating;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: canGenerate ? () => _handleGenerate(formProvider) : null,
        icon:
            _isGenerating
                ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : const Icon(Icons.play_arrow),
        label: Text(_isGenerating ? 'Generating...' : 'Generate Forecasts'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          backgroundColor:
              canGenerate ? Theme.of(context).colorScheme.primary : null,
        ),
      ),
    );
  }

  void _handleGenerate(DummyRiverForecastFormProvider formProvider) async {
    if (!formProvider.isValid) return;

    setState(() => _isGenerating = true);

    try {
      final formData = formProvider.getFormData();
      await Future.delayed(const Duration(milliseconds: 500)); // UI feedback
      widget.onGenerate(formData);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating forecasts: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }
}
