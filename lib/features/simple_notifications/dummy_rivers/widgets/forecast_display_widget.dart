// lib/features/simple_notifications/dummy_rivers/widgets/forecast_display_widget.dart

import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/dummy_river_forecast.dart';

class ForecastDisplayWidget extends StatefulWidget {
  final DummyRiverForecast forecast;
  final Map<int, double> returnPeriods;

  const ForecastDisplayWidget({
    super.key,
    required this.forecast,
    required this.returnPeriods,
  });

  @override
  State<ForecastDisplayWidget> createState() => _ForecastDisplayWidgetState();
}

class _ForecastDisplayWidgetState extends State<ForecastDisplayWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _viewMode = 'timeline'; // 'timeline', 'list', 'chart'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.forecast.hasForecasts ? 2 : 1,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          if (widget.forecast.hasForecasts) ...[
            _buildTabBar(),
            SizedBox(
              height: 400,
              child: TabBarView(
                controller: _tabController,
                children: [_buildOverviewTab(), _buildDetailedTab()],
              ),
            ),
          ] else
            _buildEmptyState(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline, color: Colors.blue),
              const SizedBox(width: 8),
              const Text(
                'Forecast Timeline',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (widget.forecast.hasForecasts) _buildViewModeSelector(),
            ],
          ),
          const SizedBox(height: 8),
          _buildForecastSummary(),
        ],
      ),
    );
  }

  Widget _buildViewModeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildViewModeButton('timeline', Icons.timeline, 'Timeline'),
          _buildViewModeButton('list', Icons.list, 'List'),
          _buildViewModeButton('chart', Icons.show_chart, 'Chart'),
        ],
      ),
    );
  }

  Widget _buildViewModeButton(String mode, IconData icon, String tooltip) {
    final isSelected = _viewMode == mode;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => setState(() => _viewMode = mode),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).colorScheme.primary : null,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 16,
            color:
                isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildForecastSummary() {
    if (!widget.forecast.hasForecasts) return const SizedBox.shrink();

    final shortCount = widget.forecast.shortRangeForecasts.length;
    final mediumCount = widget.forecast.mediumRangeForecasts.length;
    final maxFlow = widget.forecast.maxFlow ?? 0;
    final minFlow = widget.forecast.minFlow ?? 0;
    final unit = widget.forecast.unit ?? 'cfs';

    return Row(
      children: [
        if (shortCount > 0) ...[
          _buildSummaryChip(
            '$shortCount Short',
            'Hourly forecasts',
            Icons.schedule,
            Colors.orange,
          ),
          const SizedBox(width: 8),
        ],
        if (mediumCount > 0) ...[
          _buildSummaryChip(
            '$mediumCount Medium',
            'Daily forecasts',
            Icons.date_range,
            Colors.purple,
          ),
          const SizedBox(width: 8),
        ],
        _buildSummaryChip(
          '${_formatFlow(minFlow)} - ${_formatFlow(maxFlow)}',
          'Flow range ($unit)',
          Icons.water,
          Colors.blue,
        ),
      ],
    );
  }

  Widget _buildSummaryChip(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 8, color: color.withOpacity(0.8)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      tabs: const [Tab(text: 'Overview'), Tab(text: 'Detailed')],
    );
  }

  Widget _buildOverviewTab() {
    switch (_viewMode) {
      case 'timeline':
        return _buildTimelineView();
      case 'list':
        return _buildListView();
      case 'chart':
        return _buildChartView();
      default:
        return _buildTimelineView();
    }
  }

  Widget _buildDetailedTab() {
    return _buildDetailedList();
  }

  Widget _buildTimelineView() {
    final allForecasts = widget.forecast.allForecasts;
    if (allForecasts.isEmpty) return _buildEmptyState();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReturnPeriodLegend(),
          const SizedBox(height: 16),
          ...allForecasts.asMap().entries.map((entry) {
            final index = entry.key;
            final forecast = entry.value;
            final isLast = index == allForecasts.length - 1;
            return _buildTimelineItem(forecast, isLast);
          }),
        ],
      ),
    );
  }

  Widget _buildReturnPeriodLegend() {
    final sortedPeriods =
        widget.returnPeriods.entries.toList()
          ..sort((a, b) => a.value.compareTo(b.value));

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
            'Return Period Thresholds',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children:
                sortedPeriods.map((period) {
                  final color = _getReturnPeriodColor(period.key);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: color.withOpacity(0.3)),
                    ),
                    child: Text(
                      '${period.key}yr: ${_formatFlow(period.value)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(ForecastDataPoint forecast, bool isLast) {
    final triggeredPeriod = _getHighestTriggeredReturnPeriod(
      forecast.flowValue,
    );
    final isShortRange = widget.forecast.shortRangeForecasts.contains(forecast);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline line
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color:
                    triggeredPeriod != null
                        ? _getReturnPeriodColor(triggeredPeriod)
                        : Colors.grey,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isShortRange ? Colors.orange : Colors.purple,
                  width: 2,
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 50,
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              ),
          ],
        ),
        const SizedBox(width: 12),
        // Content
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  triggeredPeriod != null
                      ? _getReturnPeriodColor(triggeredPeriod).withOpacity(0.1)
                      : Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border:
                  triggeredPeriod != null
                      ? Border.all(
                        color: _getReturnPeriodColor(
                          triggeredPeriod,
                        ).withOpacity(0.3),
                      )
                      : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      forecast.relativeTime,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isShortRange
                                ? Colors.orange.withOpacity(0.2)
                                : Colors.purple.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isShortRange ? 'SHORT' : 'MEDIUM',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: isShortRange ? Colors.orange : Colors.purple,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${forecast.formattedFlow} ${forecast.unit}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (triggeredPeriod != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getReturnPeriodColor(
                            triggeredPeriod,
                          ).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '⚠️ ${triggeredPeriod}yr Alert',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _getReturnPeriodColor(triggeredPeriod),
                          ),
                        ),
                      ),
                  ],
                ),
                if (triggeredPeriod != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Exceeds $triggeredPeriod-year return period threshold',
                    style: TextStyle(
                      fontSize: 10,
                      color: _getReturnPeriodColor(triggeredPeriod),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListView() {
    final allForecasts = widget.forecast.allForecasts;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allForecasts.length,
      itemBuilder: (context, index) {
        final forecast = allForecasts[index];
        final triggeredPeriod = _getHighestTriggeredReturnPeriod(
          forecast.flowValue,
        );
        final isShortRange = widget.forecast.shortRangeForecasts.contains(
          forecast,
        );

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  triggeredPeriod != null
                      ? _getReturnPeriodColor(triggeredPeriod)
                      : Colors.grey,
              radius: 16,
              child: Icon(
                triggeredPeriod != null ? Icons.warning : Icons.check,
                color: Colors.white,
                size: 16,
              ),
            ),
            title: Text(
              '${forecast.formattedFlow} ${forecast.unit}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(forecast.relativeTime),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isShortRange
                            ? Colors.orange.withOpacity(0.2)
                            : Colors.purple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isShortRange ? 'S' : 'M',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isShortRange ? Colors.orange : Colors.purple,
                    ),
                  ),
                ),
                if (triggeredPeriod != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${triggeredPeriod}yr',
                    style: TextStyle(
                      fontSize: 10,
                      color: _getReturnPeriodColor(triggeredPeriod),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChartView() {
    final allForecasts = widget.forecast.allForecasts;
    if (allForecasts.isEmpty) return _buildEmptyState();

    final maxFlow = allForecasts.map((f) => f.flowValue).reduce(math.max);
    final minFlow = allForecasts.map((f) => f.flowValue).reduce(math.min);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildReturnPeriodLegend(),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: CustomPaint(
              painter: ForecastChartPainter(
                forecasts: allForecasts,
                returnPeriods: widget.returnPeriods,
                maxFlow: maxFlow,
                minFlow: minFlow,
              ),
              size: const Size(double.infinity, 200),
            ),
          ),
          const SizedBox(height: 16),
          _buildChartLegend(),
        ],
      ),
    );
  }

  Widget _buildChartLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildLegendItem('Short Range', Colors.orange),
        _buildLegendItem('Medium Range', Colors.purple),
        _buildLegendItem('Return Period', Colors.red),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  Widget _buildDetailedList() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [Tab(text: 'Short Range'), Tab(text: 'Medium Range')],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildRangeDetailList(
                  widget.forecast.shortRangeForecasts,
                  true,
                ),
                _buildRangeDetailList(
                  widget.forecast.mediumRangeForecasts,
                  false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeDetailList(
    List<ForecastDataPoint> forecasts,
    bool isShortRange,
  ) {
    if (forecasts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isShortRange ? Icons.schedule : Icons.date_range,
              size: 48,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No ${isShortRange ? 'short' : 'medium'} range forecasts',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: forecasts.length,
      itemBuilder: (context, index) {
        final forecast = forecasts[index];
        final triggeredPeriod = _getHighestTriggeredReturnPeriod(
          forecast.flowValue,
        );

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color:
                        triggeredPeriod != null
                            ? _getReturnPeriodColor(
                              triggeredPeriod,
                            ).withOpacity(0.1)
                            : Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color:
                            triggeredPeriod != null
                                ? _getReturnPeriodColor(triggeredPeriod)
                                : Theme.of(context).colorScheme.onSurface,
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
                        '${forecast.formattedFlow} ${forecast.unit}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        forecast.relativeTime,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      if (triggeredPeriod != null)
                        Text(
                          '⚠️ Triggers $triggeredPeriod-year return period',
                          style: TextStyle(
                            fontSize: 10,
                            color: _getReturnPeriodColor(triggeredPeriod),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
                if (triggeredPeriod != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getReturnPeriodColor(
                        triggeredPeriod,
                      ).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getReturnPeriodColor(
                          triggeredPeriod,
                        ).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      '${triggeredPeriod}yr',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _getReturnPeriodColor(triggeredPeriod),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timeline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No Forecast Data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Generate forecasts to see the timeline',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  int? _getHighestTriggeredReturnPeriod(double flowValue) {
    final sortedPeriods =
        widget.returnPeriods.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)); // Highest first

    for (final period in sortedPeriods) {
      if (flowValue >= period.value) {
        return period.key;
      }
    }
    return null;
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

// Custom painter for the chart view
class ForecastChartPainter extends CustomPainter {
  final List<ForecastDataPoint> forecasts;
  final Map<int, double> returnPeriods;
  final double maxFlow;
  final double minFlow;

  ForecastChartPainter({
    required this.forecasts,
    required this.returnPeriods,
    required this.maxFlow,
    required this.minFlow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (forecasts.isEmpty) return;

    final paint =
        Paint()
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;

    final pointPaint = Paint()..style = PaintingStyle.fill;

    // Draw return period lines
    final sortedPeriods =
        returnPeriods.entries.toList()
          ..sort((a, b) => a.value.compareTo(b.value));

    for (final period in sortedPeriods) {
      final y =
          size.height -
          ((period.value - minFlow) / (maxFlow - minFlow)) * size.height;
      paint.color = _getReturnPeriodColor(period.key).withOpacity(0.5);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Draw forecast line and points
    final path = Path();
    final points = <Offset>[];

    for (int i = 0; i < forecasts.length; i++) {
      final forecast = forecasts[i];
      final x = (i / (forecasts.length - 1)) * size.width;
      final y =
          size.height -
          ((forecast.flowValue - minFlow) / (maxFlow - minFlow)) * size.height;

      points.add(Offset(x, y));

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Draw the forecast line
    paint.color = Colors.blue;
    canvas.drawPath(path, paint);

    // Draw forecast points
    for (int i = 0; i < points.length; i++) {
      final forecast = forecasts[i];
      final triggeredPeriod = _getHighestTriggeredReturnPeriod(
        forecast.flowValue,
      );

      pointPaint.color =
          triggeredPeriod != null
              ? _getReturnPeriodColor(triggeredPeriod)
              : Colors.blue;

      canvas.drawCircle(points[i], 4, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;

  int? _getHighestTriggeredReturnPeriod(double flowValue) {
    final sortedPeriods =
        returnPeriods.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    for (final period in sortedPeriods) {
      if (flowValue >= period.value) {
        return period.key;
      }
    }
    return null;
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
}
