// lib/core/widgets/loading_indicator.dart
import 'package:flutter/material.dart';

/// A reusable loading indicator with consistent styling
class LoadingIndicator extends StatelessWidget {
  final Color? color;
  final double size;
  final String? message;
  final bool withBackground;

  const LoadingIndicator({
    super.key,
    this.color,
    this.size = 40.0,
    this.message,
    this.withBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    // Grab ThemeData and ColorScheme for auto light/dark support
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // Fallback to theme.primary / theme.onSurface if no override provided
    final indicatorColor = color ?? colors.primary;
    final messageColor = color ?? colors.onSurface;

    // Build the spinner + optional message
    final indicator = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
            strokeWidth: 3.0,
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 16),
          Text(
            message!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: messageColor,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );

    // Wrap in a card-like container if requested
    if (withBackground) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          // Use surface color for the “card” background
          color: colors.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              // soften shadow based on brightness
              color: Colors.black.withOpacity(
                theme.brightness == Brightness.light ? 0.1 : 0.4,
              ),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: indicator,
      );
    }

    return indicator;
  }
}

/// A skeleton loading placeholder for content
class SkeletonLoadingBox extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonLoadingBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: borderRadius ?? BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}

/// A skeleton loading animation wrapper
class ShimmerLoading extends StatefulWidget {
  final Widget child;

  const ShimmerLoading({super.key, required this.child});

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [Colors.grey, Colors.white, Colors.grey],
              stops: [
                _animation.value - 1,
                _animation.value,
                _animation.value + 1,
              ],
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

/// Skeleton loading for forecast card
class SkeletonForecastCard extends StatelessWidget {
  const SkeletonForecastCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SkeletonLoadingBox(width: 100, height: 24),
                  SkeletonLoadingBox(
                    width: 80,
                    height: 30,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  SkeletonLoadingBox(width: 120, height: 40),
                  const SizedBox(width: 8),
                  SkeletonLoadingBox(width: 40, height: 20),
                ],
              ),
              const SizedBox(height: 16),
              SkeletonLoadingBox(
                width: double.infinity,
                height: 30,
                borderRadius: BorderRadius.circular(15),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  SkeletonLoadingBox(
                    width: 20,
                    height: 20,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  const SizedBox(width: 8),
                  SkeletonLoadingBox(width: 150, height: 20),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  SkeletonLoadingBox(
                    width: 20,
                    height: 20,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  const SizedBox(width: 8),
                  SkeletonLoadingBox(width: 180, height: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton loading for hydrograph
class SkeletonHydrograph extends StatelessWidget {
  final double height;

  const SkeletonHydrograph({super.key, this.height = 300});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(16),
          height: height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonLoadingBox(width: 150, height: 24),
              const SizedBox(height: 16),
              Expanded(
                child: SkeletonLoadingBox(
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  5,
                  (index) => SkeletonLoadingBox(width: 50, height: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
