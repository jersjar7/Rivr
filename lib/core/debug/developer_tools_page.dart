// // lib/core/debug/developer_tools_page.dart
// // Developer tools for testing notification integration

// import 'package:flutter/material.dart';
// import 'package:flutter/foundation.dart';
// import '../services/notification_service.dart';
// import '../navigation/app_router.dart';
// import '../navigation/deep_link_router.dart';

// /// Developer tools page for testing notification functionality
// /// Only available in debug builds
// class DeveloperToolsPage extends StatefulWidget {
//   const DeveloperToolsPage({super.key});

//   @override
//   State<DeveloperToolsPage> createState() => _DeveloperToolsPageState();
// }

// class _DeveloperToolsPageState extends State<DeveloperToolsPage> {
//   final NotificationService _notificationService = NotificationService();
//   final DeepLinkRouter _deepLinkRouter = DeepLinkRouter();

//   String _selectedCategory = 'Normal';
//   String _selectedPriority = 'activity';
//   String _testReachId = 'green-river-001';
//   String _customTitle = '';
//   String _customBody = '';
//   String _deepLinkUrl = '';

//   @override
//   Widget build(BuildContext context) {
//     // Only show in debug mode
//     if (kReleaseMode) {
//       return Scaffold(
//         appBar: AppBar(title: const Text('Not Available')),
//         body: const Center(
//           child: Text('Developer tools not available in release builds'),
//         ),
//       );
//     }

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('🛠️ Developer Tools'),
//         backgroundColor: Colors.orange.shade100,
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             _buildServiceStatusSection(),
//             const SizedBox(height: 24),
//             _buildNotificationTestSection(),
//             const SizedBox(height: 24),
//             _buildDeepLinkTestSection(),
//             const SizedBox(height: 24),
//             _buildNavigationTestSection(),
//             const SizedBox(height: 24),
//             _buildQuickActionsSection(),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildServiceStatusSection() {
//     return Card(
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               '📊 Service Status',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 16),
//             _buildStatusRow(
//               'Notifications Enabled',
//               _notificationService.permissionGranted,
//             ),
//             _buildStatusRow(
//               'FCM Token Available',
//               _notificationService.fcmToken != null,
//             ),
//             const SizedBox(height: 16),
//             if (_notificationService.fcmToken != null) ...[
//               const Text(
//                 'FCM Token:',
//                 style: TextStyle(fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 4),
//               Container(
//                 padding: const EdgeInsets.all(8),
//                 decoration: BoxDecoration(
//                   color: Colors.grey.shade100,
//                   borderRadius: BorderRadius.circular(4),
//                 ),
//                 child: Text(
//                   _notificationService.fcmToken!,
//                   style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
//                 ),
//               ),
//             ],
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildStatusRow(String label, bool status) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4),
//       child: Row(
//         children: [
//           Icon(
//             status ? Icons.check_circle : Icons.error,
//             color: status ? Colors.green : Colors.red,
//             size: 16,
//           ),
//           const SizedBox(width: 8),
//           Text(label),
//           const Spacer(),
//           Text(
//             status ? 'OK' : 'FAIL',
//             style: TextStyle(
//               color: status ? Colors.green : Colors.red,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildNotificationTestSection() {
//     return Card(
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               '🧪 Notification Testing',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 16),

//             // Category selection
//             const Text(
//               'Flow Category:',
//               style: TextStyle(fontWeight: FontWeight.bold),
//             ),
//             DropdownButton<String>(
//               value: _selectedCategory,
//               isExpanded: true,
//               items:
//                   [
//                         'Low',
//                         'Normal',
//                         'Moderate',
//                         'Elevated',
//                         'High',
//                         'Very High',
//                         'Extreme',
//                       ]
//                       .map(
//                         (category) => DropdownMenuItem(
//                           value: category,
//                           child: Text(category),
//                         ),
//                       )
//                       .toList(),
//               onChanged: (value) => setState(() => _selectedCategory = value!),
//             ),
//             const SizedBox(height: 16),

//             // Priority selection
//             const Text(
//               'Priority:',
//               style: TextStyle(fontWeight: FontWeight.bold),
//             ),
//             DropdownButton<String>(
//               value: _selectedPriority,
//               isExpanded: true,
//               items:
//                   ['information', 'activity', 'safety', 'demonstration']
//                       .map(
//                         (priority) => DropdownMenuItem(
//                           value: priority,
//                           child: Text(priority),
//                         ),
//                       )
//                       .toList(),
//               onChanged: (value) => setState(() => _selectedPriority = value!),
//             ),
//             const SizedBox(height: 16),

//             // Reach ID
//             TextField(
//               decoration: const InputDecoration(
//                 labelText: 'Reach ID',
//                 border: OutlineInputBorder(),
//               ),
//               onChanged: (value) => _testReachId = value,
//               controller: TextEditingController(text: _testReachId),
//             ),
//             const SizedBox(height: 16),

//             // Custom title
//             TextField(
//               decoration: const InputDecoration(
//                 labelText: 'Custom Title (optional)',
//                 border: OutlineInputBorder(),
//               ),
//               onChanged: (value) => _customTitle = value,
//             ),
//             const SizedBox(height: 16),

//             // Custom body
//             TextField(
//               decoration: const InputDecoration(
//                 labelText: 'Custom Body (optional)',
//                 border: OutlineInputBorder(),
//               ),
//               onChanged: (value) => _customBody = value,
//               maxLines: 2,
//             ),
//             const SizedBox(height: 16),

//             // Test buttons
//             Wrap(
//               spacing: 8,
//               runSpacing: 8,
//               children: [
//                 ElevatedButton.icon(
//                   onPressed: () => _sendTestNotification(false),
//                   icon: const Icon(Icons.notifications),
//                   label: const Text('Send Test'),
//                   style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
//                 ),
//                 ElevatedButton.icon(
//                   onPressed: () => _sendTestNotification(true),
//                   icon: const Icon(Icons.warning),
//                   label: const Text('Send Safety Alert'),
//                   style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//                 ),
//                 OutlinedButton.icon(
//                   onPressed: _sendQuickTests,
//                   icon: const Icon(Icons.speed),
//                   label: const Text('Quick Test Suite'),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildDeepLinkTestSection() {
//     return Card(
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               '🔗 Deep Link Testing',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 16),
//             TextField(
//               decoration: const InputDecoration(
//                 labelText: 'Deep Link URL',
//                 border: OutlineInputBorder(),
//                 hintText: 'rivr://reach/green-river-001',
//               ),
//               onChanged: (value) => _deepLinkUrl = value,
//             ),
//             const SizedBox(height: 16),
//             Wrap(
//               spacing: 8,
//               runSpacing: 8,
//               children: [
//                 ElevatedButton(
//                   onPressed: () => _testDeepLink(_deepLinkUrl),
//                   child: const Text('Test Deep Link'),
//                 ),
//                 OutlinedButton(
//                   onPressed:
//                       () => _testDeepLink(
//                         'rivr://reach/$_testReachId?highlight=true',
//                       ),
//                   child: const Text('Test Reach Link'),
//                 ),
//                 OutlinedButton(
//                   onPressed: () => _testDeepLink('rivr://alerts?type=safety'),
//                   child: const Text('Test Alerts Link'),
//                 ),
//                 OutlinedButton(
//                   onPressed:
//                       () => _testDeepLink('rivr://settings/notifications'),
//                   child: const Text('Test Settings Link'),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildNavigationTestSection() {
//     return Card(
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               '🧭 Navigation Testing',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 16),
//             Wrap(
//               spacing: 8,
//               runSpacing: 8,
//               children: [
//                 ElevatedButton(
//                   onPressed:
//                       () => AppRouter.navigateToNotificationSettings(context),
//                   child: const Text('Settings'),
//                 ),
//                 ElevatedButton(
//                   onPressed:
//                       () => AppRouter.navigateToNotificationHistory(context),
//                   child: const Text('History'),
//                 ),
//                 ElevatedButton(
//                   onPressed:
//                       () => AppRouter.navigateToForecast(
//                         context,
//                         _testReachId,
//                         fromNotification: true,
//                         highlightFlow: true,
//                         notificationData: {
//                           'category': _selectedCategory,
//                           'priority': _selectedPriority,
//                           'timestamp': DateTime.now().toIso8601String(),
//                         },
//                       ),
//                   child: const Text('Test Forecast'),
//                 ),
//                 ElevatedButton(
//                   onPressed:
//                       () => AppRouter.navigateToSafetyInfo(
//                         context,
//                         alertLevel: _selectedCategory,
//                         reachId: _testReachId,
//                         alertData: {
//                           'category': _selectedCategory,
//                           'priority': _selectedPriority,
//                         },
//                       ),
//                   child: const Text('Safety Info'),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildQuickActionsSection() {
//     return Card(
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               '⚡ Quick Actions',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 16),
//             Wrap(
//               spacing: 8,
//               runSpacing: 8,
//               children: [
//                 OutlinedButton.icon(
//                   onPressed: () async {
//                     final token = await _notificationService.getCurrentToken();
//                     _showInfoDialog('FCM Token', token ?? 'No token available');
//                   },
//                   icon: const Icon(Icons.token),
//                   label: const Text('Show FCM Token'),
//                 ),
//                 OutlinedButton.icon(
//                   onPressed: () async {
//                     final granted =
//                         await _notificationService.requestPermissions();
//                     _showInfoDialog(
//                       'Permissions',
//                       granted ? 'Permissions granted' : 'Permissions denied',
//                     );
//                   },
//                   icon: const Icon(Icons.security),
//                   label: const Text('Request Permissions'),
//                 ),
//                 OutlinedButton.icon(
//                   onPressed: _clearNotificationHistory,
//                   icon: const Icon(Icons.clear_all),
//                   label: const Text('Clear History'),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Future<void> _sendTestNotification(bool isSafety) async {
//     try {
//       final title =
//           _customTitle.isNotEmpty
//               ? _customTitle
//               : isSafety
//               ? '⚠️ Safety Alert: $_selectedCategory'
//               : '🌊 Flow Update: $_selectedCategory';

//       final body =
//           _customBody.isNotEmpty
//               ? _customBody
//               : isSafety
//               ? 'Dangerous conditions detected on $_testReachId - avoid area'
//               : 'Flow conditions have changed to $_selectedCategory on $_testReachId';

//       await _notificationService.sendTestNotification(
//         title: title,
//         body: body,
//         category: _selectedCategory,
//         priority: isSafety ? 'safety' : _selectedPriority,
//         reachId: _testReachId,
//       );

//       _showSuccessSnackBar('Test notification sent successfully');
//     } catch (e) {
//       _showErrorSnackBar('Failed to send notification: $e');
//     }
//   }

//   Future<void> _sendQuickTests() async {
//     final testScenarios = [
//       {
//         'title': '🟢 Normal Flow',
//         'category': 'Normal',
//         'priority': 'information',
//       },
//       {
//         'title': '🟡 Moderate Conditions',
//         'category': 'Moderate',
//         'priority': 'activity',
//       },
//       {'title': '🔴 High Flow Alert', 'category': 'High', 'priority': 'safety'},
//     ];

//     for (final scenario in testScenarios) {
//       await Future.delayed(const Duration(seconds: 1));
//       await _notificationService.sendTestNotification(
//         title: scenario['title'] as String,
//         body: 'Test notification for ${scenario['category']} conditions',
//         category: scenario['category'] as String,
//         priority: scenario['priority'] as String,
//         reachId: _testReachId,
//       );
//     }

//     _showSuccessSnackBar('Quick test suite completed');
//   }

//   Future<void> _testDeepLink(String deepLink) async {
//     if (deepLink.isEmpty) {
//       _showErrorSnackBar('Please enter a deep link URL');
//       return;
//     }

//     try {
//       final navigator = Navigator.of(context);
//       final success = await _deepLinkRouter.routeDeepLink(
//         navigator,
//         deepLink,
//         additionalData: {
//           'testMode': true,
//           'timestamp': DateTime.now().toIso8601String(),
//         },
//       );

//       if (success) {
//         _showSuccessSnackBar('Deep link navigation successful');
//       } else {
//         _showErrorSnackBar('Deep link navigation failed');
//       }
//     } catch (e) {
//       _showErrorSnackBar('Deep link error: $e');
//     }
//   }

//   void _clearNotificationHistory() {
//     // This would clear notification history in production
//     _showSuccessSnackBar('Notification history cleared (simulated)');
//   }

//   void _showInfoDialog(String title, String content) {
//     showDialog(
//       context: context,
//       builder:
//           (context) => AlertDialog(
//             title: Text(title),
//             content: SelectableText(content),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.of(context).pop(),
//                 child: const Text('Close'),
//               ),
//             ],
//           ),
//     );
//   }

//   void _showSuccessSnackBar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: Colors.green,
//         behavior: SnackBarBehavior.floating,
//       ),
//     );
//   }

//   void _showErrorSnackBar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: Colors.red,
//         behavior: SnackBarBehavior.floating,
//       ),
//     );
//   }
// }
