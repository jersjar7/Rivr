// lib/core/widgets/offline_aware_content.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/offline_manager_service.dart';
import '../network/network_info.dart';

/// A widget that shows different content based on network/offline status
class OfflineAwareContent extends StatefulWidget {
  /// Builder for online content
  final Widget Function(BuildContext context) onlineBuilder;

  /// Builder for offline content
  final Widget Function(BuildContext context)? offlineBuilder;

  /// Builder for no data/no cache content
  final Widget Function(BuildContext context)? noDataBuilder;

  /// Callback when connection is restored
  final VoidCallback? onReconnect;

  /// Whether to show a banner when offline
  final bool showOfflineBanner;

  /// Whether to attempt loading cached data first
  final bool tryOfflineFirst;

  /// Whether to automatically retry connection periodically
  final bool autoRetryConnection;

  /// Future that resolves to whether cached data is available
  final Future<bool> Function()? checkCachedData;

  const OfflineAwareContent({
    super.key,
    required this.onlineBuilder,
    this.offlineBuilder,
    this.noDataBuilder,
    this.onReconnect,
    this.showOfflineBanner = true,
    this.tryOfflineFirst = false,
    this.autoRetryConnection = true,
    this.checkCachedData,
  });

  @override
  State<OfflineAwareContent> createState() => _OfflineAwareContentState();
}

class _OfflineAwareContentState extends State<OfflineAwareContent> {
  bool _isLoading = true;
  bool _hasCachedData = false;
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    _checkConnectionAndCache();
  }

  Future<void> _checkConnectionAndCache() async {
    setState(() {
      _isLoading = true;
    });

    final networkInfo = Provider.of<NetworkInfo>(context, listen: false);
    final offlineManager = Provider.of<OfflineManagerService>(
      context,
      listen: false,
    );

    // Check if we're in forced offline mode
    final forcedOffline = offlineManager.offlineModeEnabled;

    // Check network connection
    final isConnected = await networkInfo.isConnected;

    // Check for cached data if needed
    bool hasCachedData = false;
    if (!isConnected || forcedOffline || widget.tryOfflineFirst) {
      if (widget.checkCachedData != null) {
        hasCachedData = await widget.checkCachedData!();
      }
    }

    if (mounted) {
      setState(() {
        _isConnected = isConnected && !forcedOffline;
        _hasCachedData = hasCachedData;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading state while checking
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Consumer2<NetworkInfo, OfflineManagerService>(
      builder: (context, networkInfo, offlineManager, child) {
        // Listen for changes in connectivity or offline mode
        final isOfflineMode = offlineManager.offlineModeEnabled;

        if (_isConnected && !isOfflineMode) {
          // We're online - show online content
          return widget.onlineBuilder(context);
        } else if (_hasCachedData) {
          // We're offline but have cached data
          if (widget.offlineBuilder != null) {
            // Use custom offline builder if provided
            return widget.offlineBuilder!(context);
          } else {
            // Otherwise, use online builder but with a stale data indicator
            return Column(
              children: [
                if (widget.showOfflineBanner)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 16,
                    ),
                    color: Colors.amber[700],
                    width: double.infinity,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.offline_bolt,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Viewing cached data',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                        TextButton(
                          onPressed: _checkConnectionAndCache,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.black26,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 0,
                            ),
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                          child: const Text('Refresh'),
                        ),
                      ],
                    ),
                  ),
                Expanded(child: widget.onlineBuilder(context)),
              ],
            );
          }
        } else {
          // We're offline and have no cached data
          return widget.noDataBuilder != null
              ? widget.noDataBuilder!(context)
              : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off, size: 56, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'No connection and no cached data',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _checkConnectionAndCache,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                    ),
                  ],
                ),
              );
        }
      },
    );
  }
}

/// Extension methods for OfflineAwareContent
extension OfflineAwareContentExtensions on Widget {
  /// Wrap a widget with offline awareness
  Widget withOfflineAwareness({
    required BuildContext context,
    Widget Function(BuildContext)? offlineBuilder,
    Widget Function(BuildContext)? noDataBuilder,
    VoidCallback? onReconnect,
    bool showOfflineBanner = true,
    bool tryOfflineFirst = false,
    Future<bool> Function()? checkCachedData,
  }) {
    return OfflineAwareContent(
      onlineBuilder: (_) => this,
      offlineBuilder: offlineBuilder,
      noDataBuilder: noDataBuilder,
      onReconnect: onReconnect,
      showOfflineBanner: showOfflineBanner,
      tryOfflineFirst: tryOfflineFirst,
      checkCachedData: checkCachedData,
    );
  }
}
