// lib/core/widgets/connection_status_banner.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../network/connection_monitor.dart';

class ConnectionStatusBanner extends StatefulWidget {
  const ConnectionStatusBanner({super.key});

  @override
  State<ConnectionStatusBanner> createState() => _ConnectionStatusBannerState();
}

class _ConnectionStatusBannerState extends State<ConnectionStatusBanner> {
  bool _wasConnected = true;
  bool _wasPermanentlyOffline = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionMonitor>(
      builder: (context, monitor, child) {
        final isConnected = monitor.isConnected;
        final isPermanentlyOffline = monitor.isPermanentlyOffline;

        // Only rebuild if relevant state actually changed
        if (isConnected != _wasConnected ||
            isPermanentlyOffline != _wasPermanentlyOffline) {
          _wasConnected = isConnected;
          _wasPermanentlyOffline = isPermanentlyOffline;
        }

        // Don't show anything when connected
        if (isConnected) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          color: Colors.red.shade800,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          child: SafeArea(
            bottom: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    isPermanentlyOffline
                        ? 'No internet connection. Some data may be outdated.'
                        : 'Connection lost. Reconnecting...',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 4),
                if (!isPermanentlyOffline)
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
          ),
        );
      },
    );
  }
}
