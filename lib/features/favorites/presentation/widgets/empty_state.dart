// lib/core/widgets/empty_state.dart
// Updating the EmptyFavoritesView class to be more visually appealing

import 'package:flutter/material.dart';
import 'package:rivr/core/theme/app_theme.dart';
import 'dart:math' as math;

class EnhancedEmptyFavoritesView extends StatelessWidget {
  final VoidCallback? onExploreMap;

  const EnhancedEmptyFavoritesView({super.key, this.onExploreMap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Animation for empty state
              _buildWaveAnimation(),

              const SizedBox(height: 32),

              // Title
              Text(
                'No Favorite Rivers Yet',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.titleColor,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Descriptive message
              Text(
                'Add your favorite rivers to track their flow conditions and get forecasts at a glance.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textColor,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Primary CTA button
              ElevatedButton.icon(
                onPressed: onExploreMap,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Explore Map'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  elevation: 4,
                  shadowColor: AppColors.primaryColor.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Secondary text link
              TextButton.icon(
                onPressed: () {
                  // Could navigate to help or tutorial page
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Feature coming soon!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.help_outline, size: 18),
                label: const Text('How to add favorites?'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.secondaryColor,
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaveAnimation() {
    return SizedBox(
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // River icon
          Icon(
            Icons.water,
            size: 100,
            color: AppColors.primaryColor.withOpacity(0.8),
          ),

          // Animated waves
          Positioned.fill(
            child: _AnimatedWaves(
              color: AppColors.primaryAccent.withOpacity(0.3),
            ),
          ),

          // Favorites icon
          Positioned(
            top: 40,
            right: 60,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.favorite,
                size: 24,
                color: AppColors.secondaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom animation for the waves effect
class _AnimatedWaves extends StatefulWidget {
  final Color color;

  const _AnimatedWaves({required this.color});

  @override
  State<_AnimatedWaves> createState() => _AnimatedWavesState();
}

class _AnimatedWavesState extends State<_AnimatedWaves>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _WavePainter(
            animationValue: _controller.value,
            color: widget.color,
          ),
          child: Container(),
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  final double animationValue;
  final Color color;

  _WavePainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;

    final path = Path();
    final width = size.width;
    final height = size.height;
    final centerY = height * 0.5;
    final amplitude = height * 0.1;

    path.moveTo(0, centerY);

    for (double i = 0; i < width; i++) {
      final x = i;
      final offset =
          math.sin((x / width * 4 * math.pi) + (animationValue * 2 * math.pi)) *
          amplitude;
      final y = centerY + offset;
      path.lineTo(x, y);
    }

    path.lineTo(width, height);
    path.lineTo(0, height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}
