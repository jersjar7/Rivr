// lib/features/forecast/presentation/pages/forecast_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rivr/core/di/service_locator.dart';
import 'package:rivr/core/models/location_info.dart';
import 'package:rivr/core/network/connection_monitor.dart';
import 'package:rivr/core/services/geocoding_service.dart';
import 'package:rivr/core/widgets/loading_indicator.dart';
import 'package:rivr/core/widgets/empty_state.dart';
import 'package:rivr/features/auth/presentation/providers/auth_provider.dart';
import 'package:rivr/features/favorites/presentation/providers/favorites_provider.dart';
import 'package:rivr/features/forecast/domain/entities/forecast_types.dart';
import 'package:rivr/features/forecast/presentation/providers/forecast_provider.dart';
import 'package:rivr/features/forecast/presentation/providers/return_period_provider.dart';
import 'package:rivr/features/forecast/presentation/widgets/flow_status_card.dart';
import 'package:rivr/features/forecast/presentation/widgets/location_info_row.dart';
import 'package:rivr/features/forecast/presentation/widgets/medium_range/9_day_flow_forecast_widget/daily_flow_forecast_widget.dart';
import 'package:rivr/features/forecast/presentation/widgets/short_range/horizontal_flow_timeline.dart';
import 'package:rivr/features/forecast/presentation/widgets/hydrograph/hydrograph_factory.dart';
import 'package:rivr/features/forecast/presentation/widgets/long_range/calendar/long_range_calendar.dart';

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

  // Variables for location information
  LocationInfo? _locationInfo;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Load forecasts when the page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadForecasts();
      // Load location info after forecasts to ensure we have coordinates
      _tabController.addListener(_handleTabChange);
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
      // If we're on the Daily tab, ensure location info is loaded
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

  // Load location information for the river
  Future<void> _loadLocationInfo() async {
    if (!mounted) return;

    final forecastProvider = Provider.of<ForecastProvider>(
      context,
      listen: false,
    );

    // Get favoritesProvider to check if this station is a favorite
    final favoritesProvider = Provider.of<FavoritesProvider>(
      context,
      listen: false,
    );

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Check if this station is a favorite and has location info
    bool locationFromFavorite = false;
    if (authProvider.currentUser != null) {
      try {
        final userId = authProvider.currentUser!.uid;
        final favorites = favoritesProvider.favorites;

        // Use where instead of firstWhere to avoid the "orElse" problem
        final matchingFavorites =
            favorites
                .where(
                  (f) => f.stationId == widget.reachId && f.userId == userId,
                )
                .toList();

        // Check if we found a matching favorite
        if (matchingFavorites.isNotEmpty) {
          final favorite = matchingFavorites.first;

          // If we found a favorite with city and state, use that
          if (favorite.city != null && favorite.state != null) {
            setState(() {
              _locationInfo = LocationInfo(
                city: favorite.city!,
                state: favorite.state!,
                lat: favorite.lat ?? 0,
                lon: favorite.lon ?? 0,
              );
              _isLoadingLocation = false;
            });

            print(
              'Using location info from favorite: ${_locationInfo!.formattedLocation}',
            );
            locationFromFavorite = true;
          }
        }
      } catch (e) {
        print('Error while checking for favorite location data: $e');
        // Continue with geocoding service
      }
    }

    // If we didn't get location from favorites, continue with normal flow
    if (locationFromFavorite) return;

    // Get reach location from provider
    final reachLocation = forecastProvider.getReachLocationFor(widget.reachId);
    if (reachLocation == null) {
      print(
        "Location info not loaded: No coordinates available for reach ${widget.reachId}",
      );
      return;
    }

    setState(() {
      _isLoadingLocation = true;
    });

    try {
      print(
        "Loading location info for coordinates: ${reachLocation.lat}, ${reachLocation.lon}",
      );

      // Get geocoding service from service locator
      final geocodingService = sl<GeocodingService>();

      // Get location info from coordinates
      final locationInfo = await geocodingService.getLocationInfo(
        reachLocation.lat,
        reachLocation.lon,
      );

      if (locationInfo != null) {
        print(
          "Location info loaded successfully: ${locationInfo.formattedLocation}",
        );
      } else {
        print(
          "Location info request returned null - geocoding service may have failed",
        );
      }

      if (mounted) {
        setState(() {
          _locationInfo = locationInfo;
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      print('Error loading location info: $e');
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.stationName} Flow Forecast',
          maxLines: 2,
          softWrap: true,
          textAlign: TextAlign.center,
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor:
              theme.colorScheme.tertiary, // Will adapt to light/dark theme
          unselectedLabelColor: theme.colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.7),
          indicatorColor: theme.colorScheme.tertiary,
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

    // Get reach location for map
    final reachLocation = forecastProvider.getReachLocationFor(widget.reachId);

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
          // Add Location Info Row if we have coordinates
          if (reachLocation != null)
            LocationInfoRow(
              locationInfo: _locationInfo,
              lat: reachLocation.lat,
              lon: reachLocation.lon,
              riverName: widget.stationName,
              isLoading: _isLoadingLocation,
              onRefresh: _loadLocationInfo,
            ),

          // Current Flow Status Card
          FlowStatusCard(
            currentFlow: latestFlow,
            returnPeriod: returnPeriod,
            expanded: true,
            onTap: () {},
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
          // Current Flow Status Card (Smaller version)
          FlowStatusCard(
            currentFlow: latestFlow,
            returnPeriod: returnPeriod,
            expanded: true,
            onTap: () {},
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
          // Current Flow Status Card (Smallest version)
          FlowStatusCard(
            currentFlow: latestFlow,
            returnPeriod: returnPeriod,
            expanded: true,
            onTap: () {},
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
