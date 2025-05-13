// lib/core/widgets/empty_state.dart

import 'package:flutter/material.dart';
import 'dart:math' as math;

/// An enhanced empty state view for favorites,
/// fully themed for light & dark modes.
class EnhancedEmptyFavoritesView extends StatelessWidget {
  final VoidCallback? onExploreMap;

  const EnhancedEmptyFavoritesView({super.key, this.onExploreMap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

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
              _buildWaveAnimation(context, colors),

              const SizedBox(height: 32),

              // Title
              Text(
                'No Favorite Rivers Yet',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Descriptive message
              Text(
                'Add your favorite rivers to track their flow conditions and get forecasts at a glance.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
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
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  textStyle: textTheme.labelLarge?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  elevation: 4,
                  shadowColor: colors.primary.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Secondary text link
              TextButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Feature coming soon!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: Icon(
                  Icons.help_outline,
                  size: 18,
                  color: colors.secondary,
                ),
                label: Text(
                  'How to add favorites?',
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colors.secondary,
                  ),
                ),
                style: TextButton.styleFrom(foregroundColor: colors.secondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the wave animation header, using the current theme's brightness
  Widget _buildWaveAnimation(BuildContext context, ColorScheme colors) {
    final brightness = Theme.of(context).brightness;

    return SizedBox(
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // River icon
          Icon(
            Icons.water,
            size: 100,
            color: colors.primary.withValues(alpha: 0.8),
          ),

          // Animated waves
          Positioned.fill(
            child: _AnimatedWaves(
              color: colors.primaryContainer.withValues(alpha: 0.3),
            ),
          ),

          // Favorites icon overlay
          Positioned(
            top: 40,
            right: 60,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(
                      brightness == Brightness.light ? 0.1 : 0.4,
                    ),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.favorite, size: 24, color: colors.secondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// A simple animated waves effect beneath the river icon
class _AnimatedWaves extends StatefulWidget {
  final Color color;
  const _AnimatedWaves({required this.color});

  @override
  State<_AnimatedWaves> createState() => _AnimatedWavesState();
}

class _AnimatedWavesState extends State<_AnimatedWaves>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

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

/// Painter that draws wavy lines based on animationValue
class _WavePainter extends CustomPainter {
  final double animationValue;
  final Color color;
  const _WavePainter({required this.animationValue, required this.color});

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
    for (double i = 0; i <= width; i++) {
      final offset =
          math.sin((i / width * 4 * math.pi) + (animationValue * 2 * math.pi)) *
          amplitude;
      path.lineTo(i, centerY + offset);
    }
    path.lineTo(width, height);
    path.lineTo(0, height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
