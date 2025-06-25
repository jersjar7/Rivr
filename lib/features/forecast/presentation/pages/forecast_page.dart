// lib/features/forecast/presentation/pages/forecast_page.dart
// Task 4.4: Updated with notification handling while preserving your existing implementation

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rivr/core/models/location_info.dart';
import 'package:rivr/core/network/connection_monitor.dart';
import 'package:rivr/core/widgets/loading_indicator.dart';
import 'package:rivr/core/widgets/empty_state.dart';
import 'package:rivr/features/forecast/domain/entities/forecast_types.dart';
import 'package:rivr/features/forecast/presentation/providers/forecast_provider.dart';
import 'package:rivr/features/forecast/presentation/providers/return_period_provider.dart';
import 'package:rivr/features/forecast/presentation/widgets/app_bar_unit_selector.dart';
import 'package:rivr/features/forecast/presentation/widgets/flow_status_card.dart';
import 'package:rivr/features/forecast/presentation/widgets/location_info_row.dart';
import 'package:rivr/features/forecast/presentation/widgets/medium_range/9_day_flow_forecast_widget/daily_flow_forecast_widget.dart';
import 'package:rivr/features/forecast/presentation/widgets/short_range/horizontal_flow_timeline.dart';
import 'package:rivr/features/forecast/presentation/widgets/hydrograph/hydrograph_factory.dart';
import 'package:rivr/features/forecast/presentation/widgets/long_range/calendar/long_range_calendar.dart';

class ForecastPage extends StatefulWidget {
  final String reachId;
  final String stationName;

  // Task 4.4: Add notification context parameters
  final bool fromNotification;
  final bool highlightFlow;
  final Map<String, dynamic>? notificationData;

  const ForecastPage({
    super.key,
    required this.reachId,
    required this.stationName,
    // Task 4.4: Default values for notification parameters
    this.fromNotification = false,
    this.highlightFlow = false,
    this.notificationData,
  });

  @override
  State<ForecastPage> createState() => _ForecastPageState();
}

class _ForecastPageState extends State<ForecastPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isRefreshing = false;

  // Variables for location information
  LocationInfo? _locationInfo;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Load forecasts and location data when the page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Start loading both forecasts and location info right away
      _loadForecasts();
      _loadLocationInfo();

      // Add tab change listener
      _tabController.addListener(_handleTabChange);

      // Task 4.4: Log notification context if present
      if (widget.fromNotification) {
        debugPrint(
          '🔔 ForecastPage opened from notification for reach: ${widget.reachId}',
        );
        if (widget.notificationData != null) {
          debugPrint('📊 Notification data: ${widget.notificationData}');
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  // Handle tab changes to load location when needed
  void _handleTabChange() {
    if (_tabController.index == 0) {
      // If we're on the Hourly tab and location info isn't loaded, try again
      if (_locationInfo == null && !_isLoadingLocation) {
        _loadLocationInfo();
      }
    }
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

        // Always load location info, not just for the Daily tab
        _loadLocationInfo();
      }
    }
  }

  // Load location information for the river with improved logic and error handling
  Future<void> _loadLocationInfo() async {
    if (!mounted || _isLoadingLocation) return;

    setState(() {
      _isLoadingLocation = true;
    });

    try {
      print(
        "ForecastPage: Starting location info loading for reach: ${widget.reachId}",
      );

      final forecastProvider = Provider.of<ForecastProvider>(
        context,
        listen: false,
      );

      // Use the improved getReachLocationFor method which now actively
      // attempts to find location data if it's not already available
      final reachLocation = await forecastProvider.getReachLocationFor(
        widget.reachId,
      );

      if (reachLocation == null) {
        print(
          "ForecastPage: No location information available for reach ${widget.reachId}",
        );
        if (mounted) {
          setState(() {
            _isLoadingLocation = false;
          });
        }
        return;
      }

      print(
        "ForecastPage: Retrieved coordinates: lat=${reachLocation.lat}, lon=${reachLocation.lon}",
      );

      // Set the location info if we have valid data
      if (mounted) {
        setState(() {
          _locationInfo = LocationInfo(
            city: reachLocation.city ?? "Unknown",
            state: reachLocation.state ?? "Unknown",
            lat: reachLocation.lat,
            lon: reachLocation.lon,
          );
          _isLoadingLocation = false;
        });
      }

      if (reachLocation.city != null && reachLocation.state != null) {
        print(
          "ForecastPage: Location info set: ${reachLocation.city}, ${reachLocation.state}",
        );
      } else {
        print("ForecastPage: Set coordinates but city/state unavailable");
      }
    } catch (e) {
      print('ForecastPage: Error loading location info: $e');
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
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

  Future<void> _refreshShortRangeForecast() async {
    final forecastProvider = Provider.of<ForecastProvider>(
      context,
      listen: false,
    );

    setState(() {
      _isRefreshing = true;
    });

    await forecastProvider.loadShortRangeForecast(
      widget.reachId,
      forceRefresh: true,
    );

    setState(() {
      _isRefreshing = false;
    });
  }

  Future<void> _refreshMediumRangeForecast() async {
    final forecastProvider = Provider.of<ForecastProvider>(
      context,
      listen: false,
    );

    setState(() {
      _isRefreshing = true;
    });

    await forecastProvider.loadMediumRangeForecast(
      widget.reachId,
      forceRefresh: true,
    );

    setState(() {
      _isRefreshing = false;
    });
  }

  Future<void> _refreshLongRangeForecast() async {
    final forecastProvider = Provider.of<ForecastProvider>(
      context,
      listen: false,
    );

    setState(() {
      _isRefreshing = true;
    });

    await forecastProvider.loadLongRangeForecast(
      widget.reachId,
      forceRefresh: true,
    );

    setState(() {
      _isRefreshing = false;
    });
  }

  // Task 4.4: Build notification banner when opened from notification
  Widget _buildNotificationBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.blue.shade200, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications, color: Colors.blue.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Opened from notification',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Show notification category if available
          if (widget.notificationData?['category'] != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getNotificationCategoryColor(),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.notificationData!['category'],
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Task 4.4: Get color based on notification category
  Color _getNotificationCategoryColor() {
    final category =
        widget.notificationData?['category']?.toString().toLowerCase();
    switch (category) {
      case 'extreme':
        return Colors.purple;
      case 'very high':
      case 'high':
        return Colors.red;
      case 'elevated':
        return Colors.orange;
      case 'moderate':
        return Colors.yellow.shade700;
      case 'normal':
        return Colors.green;
      case 'low':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  // Task 4.4: Wrap widget with highlight if needed
  Widget _wrapWithHighlight(Widget child, {bool isCard = false}) {
    if (!widget.highlightFlow) return child;

    return Container(
      decoration: BoxDecoration(
        color: Colors.yellow.shade100,
        border: Border.all(color: Colors.yellow.shade400, width: 2),
        borderRadius: BorderRadius.circular(isCard ? 12 : 8),
      ),
      child: Column(
        children: [
          // Highlight indicator
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.yellow.shade200,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(isCard ? 10 : 6),
                topRight: Radius.circular(isCard ? 10 : 6),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.star, color: Colors.yellow.shade800, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Flow highlighted from notification',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.yellow.shade800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Original widget with padding
          Padding(padding: const EdgeInsets.all(8), child: child),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.stationName,
          maxLines: 3,
          softWrap: true,
          textAlign: TextAlign.center,
        ),
        // Task 4.4: Visual indicator in app bar when opened from notification
        backgroundColor: widget.fromNotification ? Colors.blue.shade50 : null,
        actions: [
          AppBarUnitSelector(
            onUnitChanged: (unit) {
              // Optional: handle unit change, like showing a snackbar or refreshing
              // For example:
              setState(() {}); // To refresh the UI with new units
            },
          ),
          // Task 4.4: Show notification icon in app bar if from notification
          if (widget.fromNotification)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                Icons.notifications,
                color: Colors.blue.shade700,
                size: 20,
              ),
            ),
          // Add a small padding at the end
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor:
              theme.colorScheme.tertiary, // Will adapt to light/dark theme
          unselectedLabelColor:
              theme.brightness == Brightness.dark
                  ? Colors
                      .white70 // Lighter color for dark theme
                  : theme.colorScheme.surface.withValues(
                    alpha: 0.7,
                  ), // Darker color for light theme
          indicatorColor: theme.colorScheme.tertiary,
          tabs: const [
            Tab(text: 'Hourly'),
            Tab(text: 'Daily'),
            Tab(text: 'Month'),
          ],
        ),
      ),
      body: ConnectionAwareWidget(
        offlineBuilder:
            (context, status) => Column(
              children: [
                const ConnectionStatusBanner(),
                // Task 4.4: Add notification banner if from notification
                if (widget.fromNotification) _buildNotificationBanner(),
                Expanded(child: _buildPageContent()),
              ],
            ),
        child: Column(
          children: [
            // Task 4.4: Add notification banner if from notification
            if (widget.fromNotification) _buildNotificationBanner(),
            Expanded(child: _buildPageContent()),
          ],
        ),
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
      color: Theme.of(context).colorScheme.primary, // Will adapt to theme
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
    final theme = Theme.of(context);
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
          // Location Info Row - Use the pre-loaded _locationInfo or show loading state
          // This data is managed by _loadLocationInfo()
          LocationInfoRow(
            locationInfo: _locationInfo,
            lat: _locationInfo?.lat ?? 0,
            lon: _locationInfo?.lon ?? 0,
            riverName: widget.stationName,
            isLoading: _isLoadingLocation,
            onRefresh: _loadLocationInfo,
          ),

          // Task 4.4: Current Flow Status Card with optional highlighting
          _wrapWithHighlight(
            FlowStatusCard(
              currentFlow: latestFlow,
              returnPeriod: returnPeriod,
              expanded: true,
              onTap: () {},
            ),
            isCard: true,
          ),

          const SizedBox(height: 12),

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

          const SizedBox(height: 12),

          // Use expandable hydrograph
          HydrographFactory.createExpandableHydrograph(
            reachId: widget.reachId,
            forecastType: ForecastType.shortRange,
            forecasts: forecasts,
            returnPeriod: returnPeriod,
          ),

          const SizedBox(height: 24),

          // Refresh Short Range Forecast Button
          Center(
            child: ElevatedButton.icon(
              onPressed: _refreshShortRangeForecast,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Hourly Forecast'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Last Updated Info
          Text(
            'Last updated: ${DateTime.now().toString().substring(0, 16)}',
            style: theme.textTheme.bodySmall,
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
    final theme = Theme.of(context);
    final latestFlow = forecastProvider.getLatestFlowFor(widget.reachId);
    final returnPeriod = returnPeriodProvider.getCachedReturnPeriod(
      widget.reachId,
    );
    final mediumRangeForecasts = forecastProvider.getForecastCollection(
      widget.reachId,
      ForecastType.mediumRange,
    );

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
          // Task 4.4: Current Flow Status Card with optional highlighting
          _wrapWithHighlight(
            FlowStatusCard(
              currentFlow: latestFlow,
              returnPeriod: returnPeriod,
              expanded: true,
              onTap: () {},
            ),
            isCard: true,
          ),

          const SizedBox(height: 12),

          // Daily Flow Forecast widget (using our new weather-app style widget)
          DailyFlowForecastWidgetWithHourly(
            forecastCollection: mediumRangeForecasts,
            returnPeriod: returnPeriod,
            onRefresh: _handleRefresh,
            flowFormatter: NumberFormat('#,##0'),
          ),

          const SizedBox(height: 12),

          // Add expandable hydrograph for daily forecasts
          HydrographFactory.createExpandableHydrograph(
            reachId: widget.reachId,
            forecastType: ForecastType.mediumRange,
            forecasts: forecasts,
            returnPeriod: returnPeriod,
            dailyStats: forecastProvider.getDailyDataFor(widget.reachId),
          ),

          const SizedBox(height: 24),

          // Refresh Medium Range Forecast Button
          Center(
            child: ElevatedButton.icon(
              onPressed: _refreshMediumRangeForecast,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Daily Forecast'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Last Updated Info
          Text(
            'Last updated: ${DateTime.now().toString().substring(0, 16)}',
            style: theme.textTheme.bodySmall,
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
    final theme = Theme.of(context);
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
          // Task 4.4: Current Flow Status Card with optional highlighting
          _wrapWithHighlight(
            FlowStatusCard(
              currentFlow: latestFlow,
              returnPeriod: returnPeriod,
              expanded: true,
              onTap: () {},
            ),
            isCard: true,
          ),

          const SizedBox(height: 12),

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

          const SizedBox(height: 12),

          // Add expandable hydrograph for monthly forecasts
          HydrographFactory.createExpandableHydrograph(
            reachId: widget.reachId,
            forecastType: ForecastType.longRange,
            forecasts: forecasts,
            returnPeriod: returnPeriod,
          ),

          const SizedBox(height: 24),

          // Refresh Long Range Forecast Button
          Center(
            child: ElevatedButton.icon(
              onPressed: _refreshLongRangeForecast,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Monthly Forecast'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Last Updated Info
          Text(
            'Last updated: ${DateTime.now().toString().substring(0, 16)}',
            style: theme.textTheme.bodySmall,
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
