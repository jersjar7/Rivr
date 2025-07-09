// // Quick test widget you can add anywhere in your app to test notifications
// import 'package:flutter/material.dart';
// import 'package:rivr/core/services/notification_service.dart';

// class QuickNotificationTest extends StatelessWidget {
//   const QuickNotificationTest({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final notificationService = NotificationService();

//     return Card(
//       margin: const EdgeInsets.all(16),
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text(
//               '🧪 Quick Notification Test',
//               style: Theme.of(context).textTheme.titleMedium,
//             ),
//             const SizedBox(height: 12),

//             Text(
//               'Permissions: ${notificationService.permissionGranted ? '✅' : '❌'}',
//             ),
//             Text(
//               'FCM Token: ${notificationService.fcmToken != null ? '✅' : '❌'}',
//             ),

//             const SizedBox(height: 12),

//             ElevatedButton(
//               onPressed: () async {
//                 await notificationService.sendTestNotification(
//                   title: '🧪 Rivr Test Alert',
//                   body: 'Testing notification system (250 cfs)',
//                   category: 'Normal',
//                   priority: 'information',
//                 );

//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(content: Text('Test notification sent!')),
//                 );
//               },
//               child: const Text('Send Test Notification'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
