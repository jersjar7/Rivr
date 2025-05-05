// lib/core/navigation/offline_routes.dart

import 'package:flutter/material.dart';
import '../pages/offline_manager_page.dart';
import '../pages/download_current_region_page.dart';

/// Helper class to register offline-related routes
class OfflineRoutes {
  /// Register all offline-related routes with the router
  static Map<String, Widget Function(BuildContext)> getRoutes() {
    return {
      '/offline_manager': (context) => const OfflineManagerPage(),
      '/offline/download-current-region':
          (context) => const DownloadCurrentRegionPage(),
      // Additional routes can be added here as needed
    };
  }

  /// Add offline routes to an existing routes map
  static void addRoutesToMap(
    Map<String, Widget Function(BuildContext)> routes,
  ) {
    routes.addAll(getRoutes());
  }
}
