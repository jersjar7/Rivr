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
  bool _justReconnected = false;

  // Debounce timer to prevent too frequent updates
  Timer? _debounceTimer;
  bool _processingConnectivityChange = false;

  // Flag to prevent multiple simultaneous connectivity checks
  bool _isCheckingConnection = false;

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
  bool get justReconnected => _justReconnected;

  void _initialize() async {
    // Check initial connection
    _checkConnection();

    // Listen for connectivity changes with throttling
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      // Only process if not already processing a change
      if (!_processingConnectivityChange) {
        _processingConnectivityChange = true;

        // Debounce rapid connectivity changes
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 300), () {
          _checkConnectionWithResults(results);
          _processingConnectivityChange = false;
        });
      }
    });
  }

  Future<void> _checkConnection() async {
    // Prevent multiple simultaneous connection checks
    if (_isCheckingConnection) return;

    _isCheckingConnection = true;

    try {
      final isConnected = await _networkInfo.isConnected;
      final connectivityResults = await _connectivity.checkConnectivity();

      final newStatus = ConnectionStatus(
        isConnected: isConnected,
        timestamp: DateTime.now(),
        connectivityResults: connectivityResults,
      );

      _updateStatus(newStatus);
    } finally {
      _isCheckingConnection = false;
    }
  }

  void _checkConnectionWithResults(List<ConnectivityResult> results) async {
    // Use a flag to prevent running multiple times simultaneously
    if (_isCheckingConnection) return;

    _isCheckingConnection = true;

    try {
      // Consider connected if any result is not "none"
      final hasConnectivity = results.any(
        (result) => result != ConnectivityResult.none,
      );

      // Always verify actual connectivity, don't just rely on the connectivity change event
      final actuallyConnected =
          hasConnectivity ? await _networkInfo.isConnected : false;

      final newStatus = ConnectionStatus(
        isConnected: actuallyConnected,
        timestamp: DateTime.now(),
        connectivityResults: results,
      );

      _updateStatus(newStatus);
    } finally {
      _isCheckingConnection = false;
    }
  }

  void _updateStatus(ConnectionStatus newStatus) {
    // Only update and notify if state actually changed
    if (newStatus.isConnected != _status.isConnected) {
      final wasConnected = _status.isConnected;
      _status = newStatus;

      // Update reconnection flags
      _justReconnected = !wasConnected && newStatus.isConnected;

      if (newStatus.isConnected) {
        // Reset reconnect attempts when connection is restored
        _reconnectAttempts = 0;
        _isPermanentlyOffline = false;
        _reconnectTimer?.cancel();

        // Schedule resetting of the justReconnected flag after a short delay
        Future.delayed(const Duration(seconds: 5), () {
          if (_justReconnected) {
            _justReconnected = false;
            notifyListeners();
          }
        });
      } else {
        // Start reconnect timer
        _scheduleReconnect();
      }

      // Notify listeners of the change
      notifyListeners();
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
      if (_reconnectAttempts > 5 && !_isPermanentlyOffline) {
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

  // Force a connection check, but don't unnecessarily trigger UI updates
  Future<void> checkConnectionAndProcess() async {
    // Only check if we're not already checking
    if (!_isCheckingConnection) {
      await _checkConnection();
    }
    return;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _reconnectTimer?.cancel();
    _debounceTimer?.cancel();
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
  bool _hasCalledReconnect = false;

  @override
  void initState() {
    super.initState();

    // Listen for reconnection events only once during init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final connectionMonitor = Provider.of<ConnectionMonitor>(
          context,
          listen: false,
        );
        if (connectionMonitor.justReconnected &&
            widget.onReconnect != null &&
            !_hasCalledReconnect) {
          _hasCalledReconnect = true;
          widget.onReconnect!();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionMonitor>(
      builder: (context, monitor, _) {
        // Only call reconnect callback once when needed
        if (monitor.justReconnected &&
            widget.onReconnect != null &&
            !_hasCalledReconnect) {
          _hasCalledReconnect = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              widget.onReconnect!();
            }
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
