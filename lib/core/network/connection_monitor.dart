// lib/core/network/connection_monitor.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import 'package:rivr/core/network/network_info.dart';

class ConnectionStatus {
  final bool isConnected;
  final DateTime timestamp;
  final List<ConnectivityResult> connectivityResults;

  ConnectionStatus({
    required this.isConnected,
    required this.timestamp,
    required this.connectivityResults,
  });
}

class ConnectionMonitor extends ChangeNotifier {
  final NetworkInfo _networkInfo;
  final Connectivity _connectivity;

  ConnectionStatus _status = ConnectionStatus(
    isConnected: true,
    timestamp: DateTime.now(),
    connectivityResults: [ConnectivityResult.wifi], // Default value
  );
  StreamSubscription? _subscription;

  bool _isPermanentlyOffline = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  // New field to track if we've just gone from offline to online
  bool _justReconnected = false;

  ConnectionMonitor({
    required NetworkInfo networkInfo,
    Connectivity? connectivity,
  }) : _networkInfo = networkInfo,
       _connectivity = connectivity ?? Connectivity() {
    _initialize();
  }

  ConnectionStatus get status => _status;
  bool get isConnected => _status.isConnected;
  bool get isPermanentlyOffline => _isPermanentlyOffline;
  // New getter to check if we just reconnected
  bool get justReconnected => _justReconnected;

  void _initialize() async {
    // Check initial connection
    _checkConnection();

    // Listen for connectivity changes
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      // Handle result list
      _checkConnectionWithResults(results);
    });
  }

  Future<void> _checkConnection() async {
    final isConnected = await _networkInfo.isConnected;
    final connectivityResults = await _connectivity.checkConnectivity();

    final newStatus = ConnectionStatus(
      isConnected: isConnected,
      timestamp: DateTime.now(),
      connectivityResults: connectivityResults,
    );

    _updateStatus(newStatus);
  }

  void _checkConnectionWithResults(List<ConnectivityResult> results) async {
    // Consider connected if any result is not "none"
    final isConnected = results.any(
      (result) => result != ConnectivityResult.none,
    );

    final newStatus = ConnectionStatus(
      isConnected: isConnected,
      timestamp: DateTime.now(),
      connectivityResults: results,
    );

    _updateStatus(newStatus);
  }

  void _updateStatus(ConnectionStatus newStatus) {
    // Check if we're going from offline to online
    _justReconnected = !_status.isConnected && newStatus.isConnected;

    // Only notify if state changed
    if (newStatus.isConnected != _status.isConnected) {
      _status = newStatus;
      notifyListeners();

      if (newStatus.isConnected) {
        // Reset reconnect attempts when connection is restored
        _reconnectAttempts = 0;
        _isPermanentlyOffline = false;
        _reconnectTimer?.cancel();

        // Schedule resetting of the justReconnected flag after a short delay
        // This gives app components time to react to the reconnection
        Future.delayed(const Duration(seconds: 5), () {
          _justReconnected = false;
          notifyListeners();
        });
      } else {
        // Start reconnect timer
        _scheduleReconnect();
      }
    } else {
      // Update the status without notifying if only timestamp or results changed
      _status = newStatus;
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();

    // Exponential backoff for reconnect attempts
    final delaySeconds = _calculateBackoffDelay();

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      _reconnectAttempts++;
      _checkConnection();

      // After certain number of attempts, consider permanently offline
      if (_reconnectAttempts > 5) {
        _isPermanentlyOffline = true;
        notifyListeners();
      }
    });
  }

  int _calculateBackoffDelay() {
    // 2^n * base_delay (capped at maxDelay)
    const baseDelay = 5; // 5 seconds
    const maxDelay = 60; // 1 minute

    final delay = baseDelay * (1 << _reconnectAttempts);
    return delay > maxDelay ? maxDelay : delay;
  }

  Future<bool> testConnection() async {
    return await _networkInfo.isConnected;
  }

  void resetOfflineStatus() {
    _isPermanentlyOffline = false;
    _reconnectAttempts = 0;
    _checkConnection();
  }

  // Force a connection check and process callbacks if needed
  Future<void> checkConnectionAndProcess() async {
    await _checkConnection();
    return;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _reconnectTimer?.cancel();
    super.dispose();
  }
}

class ConnectionAwareWidget extends StatefulWidget {
  final Widget child;
  final Widget Function(BuildContext, ConnectionStatus)? offlineBuilder;
  final bool showOfflineBanner;
  final VoidCallback? onReconnect;

  const ConnectionAwareWidget({
    super.key,
    required this.child,
    this.offlineBuilder,
    this.showOfflineBanner = true,
    this.onReconnect,
  });

  @override
  State<ConnectionAwareWidget> createState() => _ConnectionAwareWidgetState();
}

class _ConnectionAwareWidgetState extends State<ConnectionAwareWidget> {
  @override
  void initState() {
    super.initState();
    // Listen for reconnection events
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final connectionMonitor = Provider.of<ConnectionMonitor>(
        context,
        listen: false,
      );
      if (connectionMonitor.justReconnected && widget.onReconnect != null) {
        widget.onReconnect!();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionMonitor>(
      builder: (context, monitor, _) {
        // If we've just reconnected and have a callback, execute it
        if (monitor.justReconnected && widget.onReconnect != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onReconnect!();
          });
        }

        if (monitor.isConnected) {
          return widget.child;
        }

        if (widget.offlineBuilder != null) {
          return widget.offlineBuilder!(context, monitor.status);
        }

        // Default offline UI
        return Column(
          children: [
            if (widget.showOfflineBanner)
              Container(
                width: double.infinity,
                color: Colors.red.shade800,
                padding: const EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        monitor.isPermanentlyOffline
                            ? 'No internet connection. Some data may be outdated.'
                            : 'Connection lost. Reconnecting...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (!monitor.isPermanentlyOffline)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(child: widget.child),
          ],
        );
      },
    );
  }
}

// This widget shows a persistent connection status in the app
class ConnectionStatusBanner extends StatelessWidget {
  const ConnectionStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionMonitor>(
      builder: (context, monitor, child) {
        if (monitor.isConnected) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          color: Colors.red.shade800,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  monitor.isPermanentlyOffline
                      ? 'No internet connection. Some data may be outdated.'
                      : 'Connection lost. Reconnecting...',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 4),
              if (!monitor.isPermanentlyOffline)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
