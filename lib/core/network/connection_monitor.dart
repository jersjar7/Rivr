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
    // Only notify if state changed
    if (newStatus.isConnected != _status.isConnected) {
      _status = newStatus;
      notifyListeners();

      if (newStatus.isConnected) {
        // Reset reconnect attempts when connection is restored
        _reconnectAttempts = 0;
        _isPermanentlyOffline = false;
        _reconnectTimer?.cancel();
      } else {
        // Start reconnect timer
        _scheduleReconnect();
      }
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

  @override
  void dispose() {
    _subscription?.cancel();
    _reconnectTimer?.cancel();
    super.dispose();
  }
}

class ConnectionAwareWidget extends StatelessWidget {
  final Widget child;
  final Widget Function(BuildContext, ConnectionStatus)? offlineBuilder;
  final bool showOfflineBanner;

  const ConnectionAwareWidget({
    super.key,
    required this.child,
    this.offlineBuilder,
    this.showOfflineBanner = true,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionMonitor>(
      builder: (context, monitor, _) {
        if (monitor.isConnected) {
          return child;
        }

        if (offlineBuilder != null) {
          return offlineBuilder!(context, monitor.status);
        }

        // Default offline UI
        return Column(
          children: [
            if (showOfflineBanner)
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
            Expanded(child: child),
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
