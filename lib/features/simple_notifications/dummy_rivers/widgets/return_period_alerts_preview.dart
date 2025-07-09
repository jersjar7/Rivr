// lib/features/simple_notifications/dummy_rivers/widgets/return_period_alerts_preview.dart

import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/dummy_river_forecast.dart';
import '../services/dummy_river_forecast_service.dart';

class ReturnPeriodAlertsPreview extends StatefulWidget {
  final DummyRiverForecast forecast;
  final Map<int, double> returnPeriods;

  const ReturnPeriodAlertsPreview({
    super.key,
    required this.forecast,
    required this.returnPeriods,
  });

  @override
  State<ReturnPeriodAlertsPreview> createState() =>
      _ReturnPeriodAlertsPreviewState();
}

class _ReturnPeriodAlertsPreviewState extends State<ReturnPeriodAlertsPreview>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DummyRiverForecastService _service = DummyRiverForecastService();

  Map<int, List<ForecastDataPoint>> _triggeredAlerts = {};
  ForecastSummary? _summary;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _calculateAlerts();
  }

  @override
  void didUpdateWidget(ReturnPeriodAlertsPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.forecast != widget.forecast ||
        oldWidget.returnPeriods != widget.returnPeriods) {
      _calculateAlerts();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _calculateAlerts() {
    _triggeredAlerts = _service.calculateTriggeredReturnPeriods(
      widget.forecast,
      widget.returnPeriods,
    );
    _summary = _service.getForecastSummary(
      widget.forecast,
      widget.returnPeriods,
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildTabBar(),
          SizedBox(
            height: 400,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildAlertsTab(),
                _buildNotificationsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final hasAlerts = _summary?.hasAlerts ?? false;
    final alertCount = _summary?.alertCount ?? 0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasAlerts ? Icons.warning : Icons.check_circle,
                color: hasAlerts ? Colors.red : Colors.green,
              ),
              const SizedBox(width: 8),
              const Text(
                'Alert Analysis',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              _buildAlertCountBadge(alertCount, hasAlerts),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasAlerts
                ? 'This forecast would trigger $alertCount notification${alertCount == 1 ? '' : 's'}'
                : 'No alerts would be triggered by this forecast',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCountBadge(int count, bool hasAlerts) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color:
            hasAlerts
                ? Colors.red.withOpacity(0.1)
                : Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              hasAlerts
                  ? Colors.red.withOpacity(0.3)
                  : Colors.green.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasAlerts ? Icons.warning : Icons.check,
            size: 16,
            color: hasAlerts ? Colors.red : Colors.green,
          ),
          const SizedBox(width: 4),
          Text(
            '$count Alert${count == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: hasAlerts ? Colors.red : Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      tabs: const [
        Tab(icon: Icon(Icons.analytics), text: 'Overview'),
        Tab(icon: Icon(Icons.warning), text: 'Alerts'),
        Tab(icon: Icon(Icons.notifications), text: 'Notifications'),
      ],
    );
  }

  Widget _buildOverviewTab() {
    if (_summary == null) return _buildLoadingState();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCards(),
          const SizedBox(height: 16),
          _buildReturnPeriodBreakdown(),
          const SizedBox(height: 16),
          _buildTimelineOverview(),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final summary = _summary!;

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'All Forecasts',
            '${summary.totalForecasts}',
            Icons.timeline,
            Colors.blue,
            subtitle:
                '${summary.shortRangeCount} short, ${summary.mediumRangeCount} medium',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Alerts Sent',
            '${summary.alertCount}',
            summary.hasAlerts ? Icons.warning : Icons.check_circle,
            summary.hasAlerts ? Colors.red : Colors.green,
            subtitle:
                summary.hasAlerts
                    ? '${summary.triggeredReturnPeriods.length} return period${summary.triggeredReturnPeriods.length == 1 ? '' : 's'}'
                    : 'No notifications',
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 10, color: color.withOpacity(0.8)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReturnPeriodBreakdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Return Period Analysis',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...widget.returnPeriods.entries.map((period) {
          final triggeredForecasts = _triggeredAlerts[period.key] ?? [];
          final isTriggered = triggeredForecasts.isNotEmpty;
          final color = _getReturnPeriodColor(period.key);

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  isTriggered
                      ? color.withOpacity(0.1)
                      : Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border:
                  isTriggered
                      ? Border.all(color: color.withOpacity(0.3))
                      : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isTriggered ? color : Colors.grey,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${period.key}yr',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${period.key}-Year Return Period',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Threshold: ${_formatFlow(period.value)} ${_summary?.unit ?? 'cfs'}',
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Icon(
                      isTriggered ? Icons.warning : Icons.check,
                      color: isTriggered ? color : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isTriggered
                          ? '${triggeredForecasts.length} alerts'
                          : 'No alerts',
                      style: TextStyle(
                        fontSize: 10,
                        color: isTriggered ? color : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTimelineOverview() {
    if (_triggeredAlerts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No Alerts Expected',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'All forecast flows are below return period thresholds. No notifications would be sent.',
                    style: TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Get all triggered alerts sorted by time
    final allAlerts = <MapEntry<ForecastDataPoint, int>>[];
    _triggeredAlerts.forEach((returnPeriod, forecasts) {
      for (final forecast in forecasts) {
        allAlerts.add(MapEntry(forecast, returnPeriod));
      }
    });
    allAlerts.sort((a, b) => a.key.timestamp.compareTo(b.key.timestamp));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Alert Timeline',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          child: ListView.builder(
            itemCount: math.min(allAlerts.length, 5), // Show max 5 alerts
            itemBuilder: (context, index) {
              final alert = allAlerts[index];
              final forecast = alert.key;
              final returnPeriod = alert.value;
              final color = _getReturnPeriodColor(returnPeriod);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text('⚠️', style: const TextStyle(fontSize: 10)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$returnPeriod-year alert ${forecast.relativeTime}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                          Text(
                            'Flow: ${forecast.formattedFlow} ${forecast.unit}',
                            style: TextStyle(
                              fontSize: 10,
                              color: color.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (allAlerts.length > 5)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '... and ${allAlerts.length - 5} more alerts',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAlertsTab() {
    if (_triggeredAlerts.isEmpty) {
      return _buildNoAlertsState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _triggeredAlerts.length,
      itemBuilder: (context, index) {
        final entry = _triggeredAlerts.entries.elementAt(index);
        final returnPeriod = entry.key;
        final forecasts = entry.value;
        final color = _getReturnPeriodColor(returnPeriod);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: color,
              child: Text(
                '${returnPeriod}yr',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              '$returnPeriod-Year Return Period',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${forecasts.length} alert${forecasts.length == 1 ? '' : 's'} • Threshold: ${_formatFlow(widget.returnPeriods[returnPeriod]!)} ${_summary?.unit ?? 'cfs'}',
            ),
            children:
                forecasts
                    .map(
                      (forecast) => ListTile(
                        contentPadding: const EdgeInsets.only(
                          left: 72,
                          right: 16,
                        ),
                        title: Text(
                          '${forecast.formattedFlow} ${forecast.unit}',
                        ),
                        subtitle: Text(forecast.relativeTime),
                        trailing: Icon(Icons.warning, color: color, size: 16),
                      ),
                    )
                    .toList(),
          ),
        );
      },
    );
  }

  Widget _buildNotificationsTab() {
    if (_triggeredAlerts.isEmpty) {
      return _buildNoAlertsState();
    }

    // Get sample notifications
    final notifications = _generateSampleNotifications();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return _buildNotificationPreview(notification);
      },
    );
  }

  Widget _buildNotificationPreview(Map<String, dynamic> notification) {
    final returnPeriod = notification['returnPeriod'] as int;
    final forecast = notification['forecast'] as ForecastDataPoint;
    final color = _getReturnPeriodColor(returnPeriod);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.notifications, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Flow Alert Notification',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Sent ${forecast.relativeTime}',
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${returnPeriod}yr',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
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
                  Text(
                    '🌊 ${widget.forecast.riverName}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Flow forecast: ${forecast.formattedFlow} ${forecast.unit}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'This exceeds the $returnPeriod-year return period threshold of ${_formatFlow(widget.returnPeriods[returnPeriod]!)} ${forecast.unit}.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Forecast time: ${forecast.relativeTime}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoAlertsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              'No Alerts',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All forecast flows are below return period thresholds',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Analyzing alerts...'),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _generateSampleNotifications() {
    final notifications = <Map<String, dynamic>>[];

    _triggeredAlerts.forEach((returnPeriod, forecasts) {
      for (final forecast in forecasts.take(3)) {
        // Limit to 3 per return period
        notifications.add({
          'returnPeriod': returnPeriod,
          'forecast': forecast,
          'timestamp': forecast.timestamp,
        });
      }
    });

    notifications.sort(
      (a, b) =>
          (a['timestamp'] as DateTime).compareTo(b['timestamp'] as DateTime),
    );

    return notifications.take(5).toList(); // Show max 5 notifications
  }

  Color _getReturnPeriodColor(int years) {
    switch (years) {
      case 2:
        return Colors.yellow.shade700;
      case 5:
        return Colors.orange;
      case 10:
        return Colors.deepOrange;
      case 25:
        return Colors.red;
      case 50:
        return Colors.red.shade800;
      case 100:
        return Colors.purple;
      default:
        return Colors.red;
    }
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
