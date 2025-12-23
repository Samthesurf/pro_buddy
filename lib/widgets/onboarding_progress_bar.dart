import 'package:flutter/material.dart';

/// Animated gradient progress bar for onboarding screens.
class OnboardingProgressBar extends StatelessWidget {
  const OnboardingProgressBar({
    super.key,
    required this.progress,
    this.height = 6,
    this.backgroundColor,
    this.gradientColors,
  });

  /// Progress value from 0.0 to 1.0
  final double progress;

  /// Height of the progress bar
  final double height;

  /// Background color for unfilled portion
  final Color? backgroundColor;

  /// Gradient colors for filled portion (start to end)
  final List<Color>? gradientColors;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? Colors.white.withValues(alpha: 0.2);
    final colors = gradientColors ??
        const [
          Color(0xFF00D4FF), // Cyan
          Color(0xFF1A4CFF), // Blue
        ];

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                width: constraints.maxWidth * progress.clamp(0.0, 1.0),
                height: height,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
