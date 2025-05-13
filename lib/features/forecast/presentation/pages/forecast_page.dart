// lib/features/forecast/presentation/pages/forecast_page.dart
// Integrated version with loading states and error handling

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rivr/core/network/connection_monitor.dart';
import 'package:rivr/core/widgets/loading_indicator.dart';
import 'package:rivr/core/widgets/empty_state.dart';
import 'package:rivr/features/forecast/domain/entities/forecast_types.dart';
import 'package:rivr/features/forecast/presentation/providers/forecast_provider.dart';
import 'package:rivr/features/forecast/presentation/providers/return_period_provider.dart';
import 'package:rivr/features/forecast/presentation/widgets/flow_status_card.dart';
import 'package:rivr/features/forecast/presentation/widgets/horizontal_flow_timeline.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.stationName} Forecast'),
        bottom: TabBar(
          controller: _tabController,
          labelColor:
              Theme.of(
                context,
              ).colorScheme.secondary, // Color for the selected tab
          unselectedLabelColor: Theme.of(context).colorScheme.surface
              .withValues(alpha: 0.7), // Color for unselected tabs
          tabs: const [
            Tab(text: 'Hourly'),
            Tab(text: 'Daily'),
            Tab(text: 'Monthly'),
          ],
        ),
      ),
      body: ConnectionAwareWidget(
        offlineBuilder:
            (context, status) => Column(
              children: [
                const ConnectionStatusBanner(),
                Expanded(child: _buildPageContent()),
              ],
            ),
        child: _buildPageContent(),
      ),
    );
  }

  Widget _buildPageContent() {
    final forecastProvider = Provider.of<ForecastProvider>(context);
    final returnPeriodProvider = Provider.of<ReturnPeriodProvider>(context);

    final isLoading = forecastProvider.isLoading(widget.reachId);
    final hasError = forecastProvider.getErrorFor(widget.reachId) != null;
    final hasData = forecastProvider.hasForecastsFor(widget.reachId);

    if (_isRefreshing || isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const LoadingIndicator(
              size: 60,
              withBackground: true,
              message: 'Loading forecast data...',
            ),
            const SizedBox(height: 40),
            SkeletonForecastCard(),
            const SizedBox(height: 20),
            SkeletonHydrograph(),
          ],
        ),
      );
    }

    if (hasError) {
      return ErrorStateView(
        message:
            forecastProvider.getErrorFor(widget.reachId) ??
            'An error occurred while loading forecast data',
        onRetry: _handleRefresh,
      );
    }

    if (!hasData) {
      return NoForecastDataView(
        stationName: widget.stationName,
        onRefresh: _handleRefresh,
      );
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: TabBarView(
        controller: _tabController,
        children: [
          // Hourly Tab (Short Range)
          _buildHourlyTab(forecastProvider, returnPeriodProvider),

          // Daily Tab (Medium Range)
          _buildDailyTab(forecastProvider, returnPeriodProvider),

          // Monthly Tab (Long Range)
          _buildMonthlyTab(forecastProvider, returnPeriodProvider),
        ],
      ),
    );
  }

  Widget _buildHourlyTab(
    ForecastProvider forecastProvider,
    ReturnPeriodProvider returnPeriodProvider,
  ) {
    final latestFlow = forecastProvider.getLatestFlowFor(widget.reachId);
    final returnPeriod = returnPeriodProvider.getCachedReturnPeriod(
      widget.reachId,
    );
    final shortRangeForecasts = forecastProvider.getForecastCollection(
      widget.reachId,
      ForecastType.shortRange,
    );

    if (shortRangeForecasts == null) {
      return Center(
        child: EmptyStateView(
          title: 'Short range forecast unavailable',
          message: 'We couldn\'t find hourly forecast data for this station',
          icon: Icons.waves_outlined,
          actionButton: OutlinedButton(
            onPressed: _handleRefresh,
            child: const Text('Refresh'),
          ),
        ),
      );
    }

    final forecasts = shortRangeForecasts.forecasts;

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

          // New Horizontal Flow Timeline Widget
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: HorizontalFlowTimeline(
                forecasts: forecasts,
                returnPeriod: returnPeriod,
                hoursToShow: 18,
                initialViewType: TimelineViewType.hourCards,
              ),
            ),
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
    ForecastProvider forecastProvider,
    ReturnPeriodProvider returnPeriodProvider,
  ) {
    final latestFlow = forecastProvider.getLatestFlowFor(widget.reachId);
    final returnPeriod = returnPeriodProvider.getCachedReturnPeriod(
      widget.reachId,
    );
    final mediumRangeForecasts = forecastProvider.getForecastCollection(
      widget.reachId,
      ForecastType.mediumRange,
    );
    final dailyData = forecastProvider.getDailyDataFor(widget.reachId);

    if (mediumRangeForecasts == null) {
      return Center(
        child: EmptyStateView(
          title: 'Medium range forecast unavailable',
          message: 'We couldn\'t find daily forecast data for this station',
          icon: Icons.calendar_today_outlined,
          actionButton: OutlinedButton(
            onPressed: _handleRefresh,
            child: const Text('Refresh'),
          ),
        ),
      );
    }

    final forecasts = mediumRangeForecasts.forecasts;

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
                        ? EmptyStateView(
                          title: 'No daily data',
                          icon: Icons.bar_chart,
                          iconSize: 40,
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
    ForecastProvider forecastProvider,
    ReturnPeriodProvider returnPeriodProvider,
  ) {
    final latestFlow = forecastProvider.getLatestFlowFor(widget.reachId);
    final returnPeriod = returnPeriodProvider.getCachedReturnPeriod(
      widget.reachId,
    );
    final longRangeForecasts = forecastProvider.getForecastCollection(
      widget.reachId,
      ForecastType.longRange,
    );
    final dailyData = forecastProvider.getDailyDataFor(widget.reachId);

    if (longRangeForecasts == null) {
      return Center(
        child: EmptyStateView(
          title: 'Long range forecast unavailable',
          message: 'We couldn\'t find monthly forecast data for this station',
          icon: Icons.date_range_outlined,
          actionButton: OutlinedButton(
            onPressed: _handleRefresh,
            child: const Text('Refresh'),
          ),
        ),
      );
    }

    final forecasts = longRangeForecasts.forecasts;

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
          forecasts.isEmpty
              ? EmptyStateView(
                title: 'No long-range data available',
                message:
                    'Long-range forecast data is not available for this station',
                icon: Icons.calendar_month_outlined,
              )
              : LongRangeCalendar(
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
}
