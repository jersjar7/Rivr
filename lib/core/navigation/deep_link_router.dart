// // lib/core/navigation/deep_link_router.dart
// // Task 4.4: Deep Link Router updated to work with your existing app structure

// import 'package:flutter/material.dart';
// import 'app_router.dart';

// /// Deep link router for handling notification-based navigation
// ///
// /// Updated to work with your existing route structure:
// /// - rivr://reach/{reachId} -> /forecast page
// /// - rivr://alerts -> /notifications page
// /// - rivr://safety -> /safety-info page
// /// - rivr://settings/notifications -> /settings/notifications page
// class DeepLinkRouter {
//   static final DeepLinkRouter _instance = DeepLinkRouter._internal();
//   factory DeepLinkRouter() => _instance;
//   DeepLinkRouter._internal();

//   /// Parse and route deep link URL
//   Future<bool> routeDeepLink(
//     NavigatorState navigator,
//     String deepLink, {
//     Map<String, dynamic>? additionalData,
//   }) async {
//     try {
//       final uri = Uri.parse(deepLink);
//       debugPrint('🔗 Routing deep link: ${uri.toString()}');

//       // Validate scheme
//       if (uri.scheme != 'rivr') {
//         debugPrint('❌ Invalid deep link scheme: ${uri.scheme}');
//         return false;
//       }

//       // Route based on host
//       switch (uri.host) {
//         case 'reach':
//           return await _routeToReach(navigator, uri, additionalData);
//         case 'alerts':
//           return await _routeToAlerts(navigator, uri, additionalData);
//         case 'safety':
//           return await _routeToSafety(navigator, uri, additionalData);
//         case 'settings':
//           return await _routeToSettings(navigator, uri, additionalData);
//         case 'test':
//           return await _routeToNotificationTest(navigator, uri, additionalData);
//         default:
//           debugPrint('❌ Unknown deep link host: ${uri.host}');
//           return false;
//       }
//     } catch (e) {
//       debugPrint('❌ Deep link parsing error: $e');
//       return false;
//     }
//   }

//   /// Route to reach details using your existing /forecast route
//   Future<bool> _routeToReach(
//     NavigatorState navigator,
//     Uri uri,
//     Map<String, dynamic>? data,
//   ) async {
//     if (uri.pathSegments.isEmpty) {
//       debugPrint('❌ Reach deep link missing reachId');
//       return false;
//     }

//     final reachId = uri.pathSegments[0];
//     debugPrint('🌊 Routing to reach: $reachId');

//     // Extract query parameters
//     final queryParams = uri.queryParameters;
//     final highlightFlow = queryParams['highlight'] == 'true';
//     final showAlert = queryParams['alert'] == 'true';

//     try {
//       // Use your existing forecast route
//       await AppRouter.navigateToForecast(
//         navigator.context,
//         reachId,
//         fromNotification: true,
//         highlightFlow: highlightFlow,
//         notificationData: {
//           ...?data,
//           'showAlert': showAlert,
//           'deepLinkSource': 'notification',
//         },
//       );
//       return true;
//     } catch (e) {
//       debugPrint('❌ Failed to navigate to forecast: $e');
//       // Fallback: Navigate to favorites
//       AppRouter.navigateToFavorites(navigator.context);
//       return false;
//     }
//   }

//   /// Route to alerts/notifications using your existing structure
//   Future<bool> _routeToAlerts(
//     NavigatorState navigator,
//     Uri uri,
//     Map<String, dynamic>? data,
//   ) async {
//     debugPrint('🔔 Routing to alerts screen');

//     final queryParams = uri.queryParameters;
//     final alertType = queryParams['type'];
//     final alertId = queryParams['id'];

//     try {
//       await AppRouter.navigateToNotificationHistory(
//         navigator.context,
//         filterType: alertType,
//         additionalData: {
//           'fromNotification': true,
//           'alertId': alertId,
//           'notificationData': data,
//         },
//       );
//       return true;
//     } catch (e) {
//       debugPrint('❌ Failed to navigate to alerts: $e');
//       // Fallback: Show notification history dialog
//       _showNotificationHistoryDialog(navigator, data);
//       return true;
//     }
//   }

//   /// Route to safety information
//   Future<bool> _routeToSafety(
//     NavigatorState navigator,
//     Uri uri,
//     Map<String, dynamic>? data,
//   ) async {
//     debugPrint('⚠️ Routing to safety information');

//     final queryParams = uri.queryParameters;
//     final safetyLevel = queryParams['level'] ?? 'general';
//     final reachId = queryParams['reach'];

//     try {
//       await AppRouter.navigateToSafetyInfo(
//         navigator.context,
//         alertLevel: safetyLevel,
//         reachId: reachId,
//         alertData: data,
//       );
//       return true;
//     } catch (e) {
//       debugPrint('❌ Failed to navigate to safety info: $e');
//       // Fallback: Show safety dialog
//       _showSafetyDialog(navigator, data);
//       return true;
//     }
//   }

//   /// Route to settings screens
//   Future<bool> _routeToSettings(
//     NavigatorState navigator,
//     Uri uri,
//     Map<String, dynamic>? data,
//   ) async {
//     debugPrint('⚙️ Routing to settings');

//     // Check if it's notification settings specifically
//     if (uri.pathSegments.isNotEmpty && uri.pathSegments[0] == 'notifications') {
//       try {
//         await AppRouter.navigateToNotificationSettings(navigator.context);
//         return true;
//       } catch (e) {
//         debugPrint('❌ Failed to navigate to notification settings: $e');
//         return false;
//       }
//     }

//     // For other settings, you might want to add additional routes
//     debugPrint('⚠️ General settings route not implemented');
//     return false;
//   }

//   /// Route to notification test page (your existing route)
//   Future<bool> _routeToNotificationTest(
//     NavigatorState navigator,
//     Uri uri,
//     Map<String, dynamic>? data,
//   ) async {
//     debugPrint('🧪 Routing to notification test');

//     try {
//       await AppRouter.navigateToNotificationTest(navigator.context);
//       return true;
//     } catch (e) {
//       debugPrint('❌ Failed to navigate to notification test: $e');
//       return false;
//     }
//   }

//   /// Generate deep link for given parameters
//   static String generateDeepLink({
//     required String host,
//     List<String>? pathSegments,
//     Map<String, String>? queryParameters,
//   }) {
//     final buffer = StringBuffer('rivr://$host');

//     if (pathSegments != null && pathSegments.isNotEmpty) {
//       buffer.write('/${pathSegments.join('/')}');
//     }

//     if (queryParameters != null && queryParameters.isNotEmpty) {
//       buffer.write('?');
//       final params = queryParameters.entries
//           .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
//           .join('&');
//       buffer.write(params);
//     }

//     return buffer.toString();
//   }

//   /// Generate reach deep link (routes to your /forecast page)
//   static String generateReachLink(
//     String reachId, {
//     bool highlight = false,
//     bool showAlert = false,
//   }) {
//     return generateDeepLink(
//       host: 'reach',
//       pathSegments: [reachId],
//       queryParameters: {
//         if (highlight) 'highlight': 'true',
//         if (showAlert) 'alert': 'true',
//       },
//     );
//   }

//   /// Generate alerts deep link
//   static String generateAlertsLink({String? type, String? id}) {
//     return generateDeepLink(
//       host: 'alerts',
//       queryParameters: {
//         if (type != null) 'type': type,
//         if (id != null) 'id': id,
//       },
//     );
//   }

//   /// Generate safety deep link
//   static String generateSafetyLink({
//     String level = 'general',
//     String? reachId,
//   }) {
//     return generateDeepLink(
//       host: 'safety',
//       queryParameters: {'level': level, if (reachId != null) 'reach': reachId},
//     );
//   }

//   /// Generate notification settings deep link
//   static String generateNotificationSettingsLink() {
//     return generateDeepLink(host: 'settings', pathSegments: ['notifications']);
//   }

//   /// Generate notification test deep link
//   static String generateNotificationTestLink() {
//     return generateDeepLink(host: 'test');
//   }

//   /// Fallback dialogs for when specific screens don't exist

//   void _showNotificationHistoryDialog(
//     NavigatorState navigator,
//     Map<String, dynamic>? data,
//   ) {
//     final context = navigator.context;
//     if (!context.mounted) return;

//     showDialog<void>(
//       context: context,
//       builder:
//           (context) => AlertDialog(
//             title: const Text('🔔 Recent Notifications'),
//             content: const Text(
//               'This would show your notification history and alert management.',
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.of(context).pop(),
//                 child: const Text('Close'),
//               ),
//               ElevatedButton(
//                 onPressed: () {
//                   Navigator.of(context).pop();
//                   AppRouter.navigateToNotificationHistory(context);
//                 },
//                 child: const Text('Open History'),
//               ),
//             ],
//           ),
//     );
//   }

//   void _showSafetyDialog(NavigatorState navigator, Map<String, dynamic>? data) {
//     final context = navigator.context;
//     if (!context.mounted) return;

//     final category = data?['category'] ?? 'Unknown';
//     final priority = data?['priority'] ?? 'information';

//     showDialog<void>(
//       context: context,
//       builder:
//           (context) => AlertDialog(
//             icon: Icon(
//               priority == 'safety' ? Icons.warning : Icons.info,
//               color: priority == 'safety' ? Colors.red : Colors.blue,
//               size: 48,
//             ),
//             title: const Text('⚠️ Safety Information'),
//             content: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text('Flow Category: $category'),
//                 const SizedBox(height: 8),
//                 const Text(
//                   'Always check current conditions before entering the water.',
//                 ),
//                 const SizedBox(height: 8),
//                 const Text(
//                   'Never rely solely on notifications for safety decisions.',
//                 ),
//               ],
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.of(context).pop(),
//                 child: const Text('Understood'),
//               ),
//             ],
//           ),
//     );
//   }

//   /// Validation methods

//   static bool isValidDeepLink(String link) {
//     try {
//       final uri = Uri.parse(link);
//       return uri.scheme == 'rivr' && uri.host.isNotEmpty;
//     } catch (e) {
//       return false;
//     }
//   }

//   static Map<String, dynamic> parseDeepLinkData(String link) {
//     try {
//       final uri = Uri.parse(link);
//       return {
//         'scheme': uri.scheme,
//         'host': uri.host,
//         'pathSegments': uri.pathSegments,
//         'queryParameters': uri.queryParameters,
//       };
//     } catch (e) {
//       return {};
//     }
//   }

//   /// Integration helper for your existing forecast page
//   static Map<String, dynamic> buildNotificationContextForForecast({
//     required String reachId,
//     String? stationName,
//     String? category,
//     String? priority,
//     bool highlightFlow = true,
//   }) {
//     return {
//       'reachId': reachId,
//       'stationName': stationName,
//       'fromNotification': true,
//       'highlightFlow': highlightFlow,
//       'notificationData': {
//         'category': category,
//         'priority': priority,
//         'timestamp': DateTime.now().toIso8601String(),
//       },
//     };
//   }
// }
