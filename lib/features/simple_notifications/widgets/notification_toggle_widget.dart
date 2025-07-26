// // lib/features/simple_notifications/widgets/notification_toggle_widget.dart

// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';

// import '../models/notification_preferences.dart';
// import '../../../../core/navigation/app_router.dart';

// /// Simple widget for favorites drawer to access notification settings
// /// Shows current notification status and provides quick access to setup
// class NotificationToggleWidget extends StatefulWidget {
//   /// Callback when user navigates to notification setup
//   final VoidCallback? onNavigateToSetup;

//   const NotificationToggleWidget({super.key, this.onNavigateToSetup});

//   @override
//   State<NotificationToggleWidget> createState() =>
//       _NotificationToggleWidgetState();
// }

// class _NotificationToggleWidgetState extends State<NotificationToggleWidget> {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;

//   bool _isLoading = true;
//   NotificationPreferences? _preferences;
//   String? _userId;
//   StreamSubscription<DocumentSnapshot>? _preferencesSubscription;

//   @override
//   void initState() {
//     super.initState();
//     _initializeWidget();
//   }

//   @override
//   void dispose() {
//     _preferencesSubscription?.cancel();
//     super.dispose();
//   }

//   Future<void> _initializeWidget() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) {
//       setState(() {
//         _isLoading = false;
//       });
//       return;
//     }

//     _userId = user.uid;
//     _listenToPreferences();
//   }

//   void _listenToPreferences() {
//     if (_userId == null) return;

//     _preferencesSubscription = _firestore
//         .collection('simpleNotificationPreferences')
//         .doc(_userId!)
//         .snapshots()
//         .listen(
//           (snapshot) {
//             if (mounted) {
//               setState(() {
//                 if (snapshot.exists) {
//                   _preferences = NotificationPreferences.fromFirestore(
//                     snapshot,
//                   );
//                 } else {
//                   _preferences = null;
//                 }
//                 _isLoading = false;
//               });
//             }
//           },
//           onError: (error) {
//             debugPrint('❌ Error listening to notification preferences: $error');
//             if (mounted) {
//               setState(() {
//                 _isLoading = false;
//               });
//             }
//           },
//         );
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_isLoading) {
//       return const _LoadingWidget();
//     }

//     if (_userId == null) {
//       return const _NotLoggedInWidget();
//     }

//     final isEnabled = _preferences?.enabled ?? false;
//     final monitoredCount = _preferences?.monitoredRiversCount ?? 0;
//     final isConfigured = _preferences?.isFullyConfigured ?? false;

//     return Card(
//       margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       child: InkWell(
//         onTap: _navigateToSetup,
//         borderRadius: BorderRadius.circular(12),
//         child: Padding(
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 children: [
//                   _buildStatusIcon(isEnabled, isConfigured),
//                   const SizedBox(width: 12),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         const Text(
//                           'Flow Notifications',
//                           style: TextStyle(
//                             fontSize: 16,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                         const SizedBox(height: 2),
//                         Text(
//                           _getStatusText(
//                             isEnabled,
//                             isConfigured,
//                             monitoredCount,
//                           ),
//                           style: TextStyle(
//                             fontSize: 12,
//                             color: Colors.grey.shade600,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   Icon(
//                     Icons.arrow_forward_ios,
//                     size: 16,
//                     color: Colors.grey.shade400,
//                   ),
//                 ],
//               ),
//               if (isEnabled && monitoredCount > 0) ...[
//                 const SizedBox(height: 8),
//                 _buildRiverCountChip(monitoredCount),
//               ],
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildStatusIcon(bool isEnabled, bool isConfigured) {
//     if (!isEnabled) {
//       return Container(
//         padding: const EdgeInsets.all(8),
//         decoration: BoxDecoration(
//           color: Colors.grey.shade100,
//           borderRadius: BorderRadius.circular(8),
//         ),
//         child: Icon(
//           Icons.notifications_off,
//           color: Colors.grey.shade600,
//           size: 24,
//         ),
//       );
//     }

//     if (!isConfigured) {
//       return Container(
//         padding: const EdgeInsets.all(8),
//         decoration: BoxDecoration(
//           color: Colors.orange.shade50,
//           borderRadius: BorderRadius.circular(8),
//         ),
//         child: Icon(
//           Icons.notification_important,
//           color: Colors.orange.shade600,
//           size: 24,
//         ),
//       );
//     }

//     return Container(
//       padding: const EdgeInsets.all(8),
//       decoration: BoxDecoration(
//         color: Colors.green.shade50,
//         borderRadius: BorderRadius.circular(8),
//       ),
//       child: Icon(
//         Icons.notifications_active,
//         color: Colors.green.shade600,
//         size: 24,
//       ),
//     );
//   }

//   String _getStatusText(bool isEnabled, bool isConfigured, int monitoredCount) {
//     if (!isEnabled) {
//       return 'Get notified when rivers reach return periods';
//     }

//     if (!isConfigured) {
//       return 'Setup required - select rivers to monitor';
//     }

//     if (monitoredCount == 1) {
//       return 'Monitoring 1 river for flow alerts';
//     }

//     return 'Monitoring $monitoredCount rivers for flow alerts';
//   }

//   Widget _buildRiverCountChip(int count) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//       decoration: BoxDecoration(
//         color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(Icons.water, size: 14, color: Theme.of(context).primaryColor),
//           const SizedBox(width: 4),
//           Text(
//             '$count river${count != 1 ? 's' : ''} monitored',
//             style: TextStyle(
//               fontSize: 11,
//               color: Theme.of(context).primaryColor,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   void _navigateToSetup() {
//     // Call callback if provided
//     widget.onNavigateToSetup?.call();

//     // Navigate to notification setup page using AppRouter
//     AppRouter.navigateToNotificationSetup(context);
//   }
// }

// /// Loading state widget
// class _LoadingWidget extends StatelessWidget {
//   const _LoadingWidget();

//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Row(
//           children: [
//             Container(
//               padding: const EdgeInsets.all(8),
//               decoration: BoxDecoration(
//                 color: Colors.grey.shade100,
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: const SizedBox(
//                 width: 24,
//                 height: 24,
//                 child: CircularProgressIndicator(strokeWidth: 2),
//               ),
//             ),
//             const SizedBox(width: 12),
//             const Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     'Flow Notifications',
//                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                   ),
//                   SizedBox(height: 2),
//                   Text(
//                     'Loading settings...',
//                     style: TextStyle(fontSize: 12, color: Colors.grey),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// /// Not logged in state widget
// class _NotLoggedInWidget extends StatelessWidget {
//   const _NotLoggedInWidget();

//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Row(
//           children: [
//             Container(
//               padding: const EdgeInsets.all(8),
//               decoration: BoxDecoration(
//                 color: Colors.grey.shade100,
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: Icon(
//                 Icons.notifications_off,
//                 color: Colors.grey.shade600,
//                 size: 24,
//               ),
//             ),
//             const SizedBox(width: 12),
//             const Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     'Flow Notifications',
//                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                   ),
//                   SizedBox(height: 2),
//                   Text(
//                     'Login required for notifications',
//                     style: TextStyle(fontSize: 12, color: Colors.grey),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
