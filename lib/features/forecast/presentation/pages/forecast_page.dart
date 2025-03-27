// lib/features/forecast/presentation/pages/forecast_page.dart
// A page that displays river flow forecasts with different time ranges

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rivr/features/forecast/domain/entities/forecast.dart';
import 'package:rivr/features/forecast/domain/entities/forecast_types.dart';
import 'package:rivr/features/forecast/domain/entities/return_period.dart';
import 'package:rivr/features/forecast/presentation/providers/forecast_provider.dart';
import 'package:rivr/features/forecast/presentation/providers/return_period_provider.dart';
import 'package:rivr/features/forecast/presentation/widgets/flow_status_card.dart';
import 'package:rivr/features/forecast/presentation/widgets/hydrograph/hydrograph_factory.dart';
import 'package:rivr/features/forecast/presentation/widgets/long_range_calendar.dart';

class ForecastPage extends StatefulWidget {
  final String reachId;
  final String stationName;

  const ForecastPage({
    super.key,
    required this.reachId,
    required this.stationName,
  });

  @override
  State<ForecastPage> createState() => _ForecastPageState();
}

class _ForecastPageState extends State<ForecastPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Load forecasts when the page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadForecasts();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadForecasts() async {
    if (mounted) {
      final forecastProvider = Provider.of<ForecastProvider>(
        context,
        listen: false,
      );
      final returnPeriodProvider = Provider.of<ReturnPeriodProvider>(
        context,
        listen: false,
      );

      setState(() {
        _isRefreshing = true;
      });

      // Load all forecast types
      await forecastProvider.loadAllForecasts(widget.reachId);

      // Load return periods if not already loaded
      if (!returnPeriodProvider.hasReturnPeriodFor(widget.reachId)) {
        await returnPeriodProvider.getReturnPeriod(widget.reachId);
      }

      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _handleRefresh() async {
    final forecastProvider = Provider.of<ForecastProvider>(
      context,
      listen: false,
    );
    final returnPeriodProvider = Provider.of<ReturnPeriodProvider>(
      context,
      listen: false,
    );

    // Refresh all data
    await forecastProvider.refreshAllData(widget.reachId);
    await returnPeriodProvider.refreshReturnPeriod(widget.reachId);

    return Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    final forecastProvider = Provider.of<ForecastProvider>(context);
    final returnPeriodProvider = Provider.of<ReturnPeriodProvider>(context);

    final isLoading = forecastProvider.isLoading(widget.reachId);
    final hasError = forecastProvider.getErrorFor(widget.reachId) != null;
    final hasData = forecastProvider.hasForecastsFor(widget.reachId);

    final latestFlow = forecastProvider.getLatestFlowFor(widget.reachId);
    final returnPeriod =
        returnPeriodProvider.hasReturnPeriodFor(widget.reachId)
            ? returnPeriodProvider.getCachedReturnPeriod(widget.reachId)
            : null;

    final shortRangeForecasts = forecastProvider.getForecastCollection(
      widget.reachId,
      ForecastType.shortRange,
    );

    final mediumRangeForecasts = forecastProvider.getForecastCollection(
      widget.reachId,
      ForecastType.mediumRange,
    );

    final longRangeForecasts = forecastProvider.getForecastCollection(
      widget.reachId,
      ForecastType.longRange,
    );

    final dailyData = forecastProvider.getDailyDataFor(widget.reachId);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.stationName} Forecast'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Hourly'),
            Tab(text: 'Daily'),
            Tab(text: 'Monthly'),
          ],
        ),
      ),
      body:
          _isRefreshing || isLoading
              ? const Center(child: CircularProgressIndicator())
              : hasError
              ? _buildErrorWidget(forecastProvider.getErrorFor(widget.reachId)!)
              : !hasData
              ? _buildNoDataWidget()
              : RefreshIndicator(
                onRefresh: _handleRefresh,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Hourly Tab (Short Range)
                    _buildHourlyTab(
                      shortRangeForecasts?.forecasts ?? [],
                      latestFlow,
                      returnPeriod,
                    ),

                    // Daily Tab (Medium Range)
                    _buildDailyTab(
                      mediumRangeForecasts?.forecasts ?? [],
                      latestFlow,
                      returnPeriod,
                      dailyData,
                    ),

                    // Monthly Tab (Long Range)
                    _buildMonthlyTab(
                      longRangeForecasts?.forecasts ?? [],
                      latestFlow,
                      returnPeriod,
                      dailyData,
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildHourlyTab(
    List<Forecast> forecasts,
    Forecast? latestFlow,
    ReturnPeriod? returnPeriod,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Flow Status Card
          FlowStatusCard(
            currentFlow: latestFlow,
            returnPeriod: returnPeriod,
            expanded: true,
            onTap: () {},
          ),

          const SizedBox(height: 24),
          const Text(
            'Hourly Forecast (Next 3 Days)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Hourly Hydrograph
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: SizedBox(
                height: 300,
                child:
                    forecasts.isEmpty
                        ? const Center(
                          child: Text('No hourly forecast data available'),
                        )
                        : HydrographFactory.createHydrograph(
                          reachId: widget.reachId,
                          forecastType: ForecastType.shortRange,
                          forecasts: forecasts,
                          returnPeriod: returnPeriod,
                        ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Last Updated Info
          Text(
            'Last updated: ${DateTime.now().toString().substring(0, 16)}',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildDailyTab(
    List<Forecast> forecasts,
    Forecast? latestFlow,
    ReturnPeriod? returnPeriod,
    Map<DateTime, Map<String, double>>? dailyData,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Flow Status Card (Smaller version)
          FlowStatusCard(
            currentFlow: latestFlow,
            returnPeriod: returnPeriod,
            expanded: false,
            onTap: () {},
          ),

          const SizedBox(height: 24),
          const Text(
            'Daily Forecast (Next 10 Days)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Daily Hydrograph
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: SizedBox(
                height: 300,
                child:
                    forecasts.isEmpty
                        ? const Center(
                          child: Text('No daily forecast data available'),
                        )
                        : HydrographFactory.createHydrograph(
                          reachId: widget.reachId,
                          forecastType: ForecastType.mediumRange,
                          forecasts: forecasts,
                          returnPeriod: returnPeriod,
                          dailyStats: dailyData,
                        ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Last Updated Info
          Text(
            'Last updated: ${DateTime.now().toString().substring(0, 16)}',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildMonthlyTab(
    List<Forecast> forecasts,
    Forecast? latestFlow,
    ReturnPeriod? returnPeriod,
    Map<DateTime, Map<String, double>>? dailyData,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Flow Status Card (Smallest version)
          FlowStatusCard(
            currentFlow: latestFlow,
            returnPeriod: returnPeriod,
            expanded: false,
            onTap: () {},
          ),

          const SizedBox(height: 24),
          const Text(
            'Monthly View (Long-Range Forecast)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Calendar with forecast data
          LongRangeCalendar(
            forecasts: forecasts,
            returnPeriod: returnPeriod,
            initialMonth: DateTime.now(),
            longRangeFlows: dailyData,
            onRefresh: () => _handleRefresh(),
          ),

          const SizedBox(height: 24),

          // Last Updated Info
          Text(
            'Last updated: ${DateTime.now().toString().substring(0, 16)}',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String errorMessage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Unable to load forecast data',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadForecasts,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No forecast data available',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'We couldn\'t find forecast data for this location',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadForecasts,
              child: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}
