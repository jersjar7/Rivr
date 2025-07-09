// lib/features/simple_notifications/dummy_rivers/pages/dummy_river_forecast_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/dummy_river.dart';
import '../providers/dummy_river_forecast_provider.dart';
import '../services/dummy_river_forecast_service.dart';
import '../widgets/forecast_generator_widget.dart';
import '../widgets/forecast_display_widget.dart';
import '../widgets/return_period_alerts_preview.dart';

class DummyRiverForecastPage extends StatefulWidget {
  final DummyRiver dummyRiver;

  const DummyRiverForecastPage({super.key, required this.dummyRiver});

  @override
  State<DummyRiverForecastPage> createState() => _DummyRiverForecastPageState();
}

class _DummyRiverForecastPageState extends State<DummyRiverForecastPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showScenarios = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Initialize providers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final forecastProvider = Provider.of<DummyRiverForecastProvider>(
        context,
        listen: false,
      );
      final formProvider = Provider.of<DummyRiverForecastFormProvider>(
        context,
        listen: false,
      );

      forecastProvider.selectRiver(widget.dummyRiver.id);
      formProvider.updateUnit(widget.dummyRiver.unit);

      // Update summary if forecast exists
      if (forecastProvider.hasForecastForRiver(widget.dummyRiver.id)) {
        forecastProvider.updateForecastSummary(
          widget.dummyRiver.id,
          widget.dummyRiver.returnPeriods,
        );
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.dummyRiver.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: _handleMenuAction,
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'clear_forecasts',
                    child: ListTile(
                      leading: Icon(Icons.clear_all),
                      title: Text('Clear Forecasts'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'refresh',
                    child: ListTile(
                      leading: Icon(Icons.refresh),
                      title: Text('Refresh'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'help',
                    child: ListTile(
                      leading: Icon(Icons.help_outline),
                      title: Text('Help'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.timeline), text: 'Generate'),
            Tab(icon: Icon(Icons.analytics_outlined), text: 'Analysis'),
          ],
        ),
      ),
      body: Consumer<DummyRiverForecastProvider>(
        builder: (context, forecastProvider, child) {
          if (forecastProvider.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Generating forecasts...'),
                ],
              ),
            );
          }

          if (forecastProvider.error != null) {
            return _buildErrorState(forecastProvider.error!);
          }

          return TabBarView(
            controller: _tabController,
            children: [_buildGenerateTab(), _buildAnalysisTab()],
          );
        },
      ),
      floatingActionButton: Consumer<DummyRiverForecastProvider>(
        builder: (context, provider, child) {
          final hasForecast = provider.hasForecastForRiver(
            widget.dummyRiver.id,
          );
          if (!hasForecast) return const SizedBox.shrink();

          return FloatingActionButton.extended(
            onPressed: _showTestNotificationDialog,
            icon: const Icon(Icons.notifications_active),
            label: const Text('Test Alerts'),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          );
        },
      ),
    );
  }

  Widget _buildGenerateTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRiverInfoCard(),
          const SizedBox(height: 16),
          _buildGenerationModeSelector(),
          const SizedBox(height: 16),
          if (_showScenarios)
            _buildScenarioGenerator()
          else
            _buildCustomGenerator(),
          const SizedBox(height: 100), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildAnalysisTab() {
    return Consumer<DummyRiverForecastProvider>(
      builder: (context, provider, child) {
        final forecast = provider.getForecast(widget.dummyRiver.id);

        if (forecast == null) {
          return _buildNoForecastState();
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ForecastDisplayWidget(
                forecast: forecast,
                returnPeriods: widget.dummyRiver.returnPeriods,
              ),
              const SizedBox(height: 16),
              ReturnPeriodAlertsPreview(
                forecast: forecast,
                returnPeriods: widget.dummyRiver.returnPeriods,
              ),
              const SizedBox(height: 100), // Space for FAB
            ],
          ),
        );
      },
    );
  }

  Widget _buildRiverInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.water, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  widget.dummyRiver.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.5)),
                  ),
                  child: const Text(
                    'TESTING',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            if (widget.dummyRiver.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                widget.dummyRiver.description,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoChip(
                  'Unit: ${widget.dummyRiver.unit}',
                  Icons.straighten,
                ),
                const SizedBox(width: 8),
                _buildInfoChip(
                  '${widget.dummyRiver.returnPeriods.length} Return Periods',
                  Icons.timeline,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildGenerationModeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Generation Mode',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildModeButton(
                    'Custom Ranges',
                    'Set specific min/max flow values',
                    Icons.tune,
                    !_showScenarios,
                    () => setState(() => _showScenarios = false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildModeButton(
                    'Preset Scenarios',
                    'Quick testing scenarios',
                    Icons.auto_awesome,
                    _showScenarios,
                    () => setState(() => _showScenarios = true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton(
    String title,
    String subtitle,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color:
                isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color:
              isSelected
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                  : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color:
                  isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.7),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color:
                    isSelected ? Theme.of(context).colorScheme.primary : null,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomGenerator() {
    return ForecastGeneratorWidget(
      dummyRiver: widget.dummyRiver,
      onGenerate: _handleCustomGeneration,
    );
  }

  Widget _buildScenarioGenerator() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Preset Testing Scenarios',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Quick scenarios designed for different testing purposes',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            ...DummyRiverForecastFormProvider.getScenarioOptions().map(
              (scenarioData) => _buildScenarioCard(scenarioData),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScenarioCard(Map<String, dynamic> scenarioData) {
    final scenario = scenarioData['scenario'] as ForecastScenario;
    final name = scenarioData['name'] as String;
    final description = scenarioData['description'] as String;
    final icon = scenarioData['icon'] as String;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Text(icon, style: const TextStyle(fontSize: 24)),
        title: Text(
          name
              .replaceAllMapped(
                RegExp(r'([A-Z])'),
                (match) => ' ${match.group(0)}',
              )
              .trim(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(description),
        trailing: const Icon(Icons.play_arrow),
        onTap: () => _handleScenarioGeneration(scenario),
      ),
    );
  }

  Widget _buildNoForecastState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.timeline,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No Forecast Data',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Generate forecasts using the Generate tab to see analysis',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _tabController.animateTo(0),
            icon: const Icon(Icons.timeline),
            label: const Text('Generate Forecasts'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed:
                      () =>
                          Provider.of<DummyRiverForecastProvider>(
                            context,
                            listen: false,
                          ).refresh(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleCustomGeneration(Map<String, dynamic> formData) async {
    final provider = Provider.of<DummyRiverForecastProvider>(
      context,
      listen: false,
    );

    await provider.generateCustomForecasts(
      riverId: widget.dummyRiver.id,
      riverName: widget.dummyRiver.name,
      unit: formData['unit'],
      shortRangeMin: formData['shortRangeMin'],
      shortRangeMax: formData['shortRangeMax'],
      mediumRangeMin: formData['mediumRangeMin'],
      mediumRangeMax: formData['mediumRangeMax'],
      shortRangeHours: formData['shortRangeHours'],
      mediumRangeDays: formData['mediumRangeDays'],
    );

    if (provider.error == null) {
      provider.updateForecastSummary(
        widget.dummyRiver.id,
        widget.dummyRiver.returnPeriods,
      );
      _tabController.animateTo(1); // Switch to analysis tab

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Forecasts generated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _handleScenarioGeneration(ForecastScenario scenario) async {
    final provider = Provider.of<DummyRiverForecastProvider>(
      context,
      listen: false,
    );

    await provider.generateScenarioForecasts(
      riverId: widget.dummyRiver.id,
      riverName: widget.dummyRiver.name,
      dummyRiver: widget.dummyRiver,
      scenario: scenario,
    );

    if (provider.error == null) {
      provider.updateForecastSummary(
        widget.dummyRiver.id,
        widget.dummyRiver.returnPeriods,
      );
      _tabController.animateTo(1); // Switch to analysis tab

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ ${scenario.toString().split('.').last} scenario generated!',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _handleMenuAction(String action) {
    final provider = Provider.of<DummyRiverForecastProvider>(
      context,
      listen: false,
    );

    switch (action) {
      case 'clear_forecasts':
        _showClearConfirmation();
        break;
      case 'refresh':
        provider.refresh();
        break;
      case 'help':
        _showHelpDialog();
        break;
    }
  }

  void _showClearConfirmation() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Clear Forecasts'),
            content: const Text(
              'Are you sure you want to clear all forecast data for this river?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Provider.of<DummyRiverForecastProvider>(
                    context,
                    listen: false,
                  ).clearForecast(widget.dummyRiver.id);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Forecasts cleared')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Clear'),
              ),
            ],
          ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Forecast Management Help'),
            content: const SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Generate Tab:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• Custom Ranges: Set specific min/max flows for testing',
                  ),
                  Text(
                    '• Preset Scenarios: Quick scenarios for different alert levels',
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Analysis Tab:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text('• View generated forecast timeline'),
                  Text('• See which return periods would be triggered'),
                  Text('• Preview expected notifications'),
                  SizedBox(height: 12),
                  Text(
                    'Testing:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text('• Use "Test Alerts" button to simulate notifications'),
                  Text('• Forecasts are stored in memory for testing'),
                  Text('• Try different scenarios to test edge cases'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it'),
              ),
            ],
          ),
    );
  }

  void _showTestNotificationDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Test Notifications'),
            content: const Text(
              'This would simulate sending notifications based on the current forecast data. '
              'In the real monitoring system, these forecasts would trigger alerts when '
              'they exceed the configured return period thresholds.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        '🚨 Test notification simulation completed!',
                      ),
                      backgroundColor: Colors.orange,
                    ),
                  );
                },
                child: const Text('Send Test'),
              ),
            ],
          ),
    );
  }
}
