// // lib/features/favorites/presentation/widgets/empty_state.dart

// import 'package:flutter/material.dart';

// /// An enhanced empty state view for favorites,
// /// fully themed for light & dark modes.
// class EmptyFavoritesView extends StatelessWidget {
//   const EmptyFavoritesView({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     final colors = theme.colorScheme;
//     final textTheme = theme.textTheme;
//     final brightness = theme.brightness;

//     // Determine if we're in dark mode
//     final isDarkMode = brightness == Brightness.dark;

//     return Center(
//       child: SingleChildScrollView(
//         physics: const BouncingScrollPhysics(),
//         child: Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 32.0),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             crossAxisAlignment: CrossAxisAlignment.center,
//             children: [
//               // Heart icon with proper color for both modes
//               Icon(
//                 Icons.favorite,
//                 size: 100,
//                 color:
//                     isDarkMode
//                         ? Colors.lightBlue.withValues(alpha: 0.8)
//                         : colors.primary.withValues(alpha: 0.8),
//               ),

//               const SizedBox(height: 32),

//               // Title with proper contrast in both modes
//               Text(
//                 'No Favorite Rivers Yet',
//                 style: textTheme.headlineMedium!.copyWith(
//                   fontWeight: FontWeight.bold,
//                   color: colors.onSurface,
//                 ),
//                 textAlign: TextAlign.center,
//               ),

//               const SizedBox(height: 16),

//               // Descriptive message with proper contrast in both modes
//               Text(
//                 'Add your favorite rivers to track their flow conditions and get forecasts at a glance.',
//                 style: textTheme.bodyMedium?.copyWith(
//                   // Slightly translucent white in dark mode for secondary text
//                   color:
//                       isDarkMode
//                           ? Colors.white.withValues(alpha: 0.7)
//                           : colors.onSurfaceVariant,
//                   height: 1.4,
//                 ),
//                 textAlign: TextAlign.center,
//               ),

//               const SizedBox(height: 32),

//               const SizedBox(height: 10),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
