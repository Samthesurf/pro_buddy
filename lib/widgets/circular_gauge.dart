import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A circular gauge widget with tick marks that fills based on a percentage value.
/// Used in the onboarding quiz to display hours/duration/ratings.
class CircularGaugeWidget extends StatelessWidget {
  const CircularGaugeWidget({
    super.key,
    required this.value,
    required this.maxValue,
    required this.label,
    this.size = 220,
    this.tickCount = 40,
    this.activeColor,
    this.inactiveColor,
  });

  /// Current value (e.g., 4 hours)
  final double value;

  /// Maximum value (e.g., 12 hours)
  final double maxValue;

  /// Label to show (e.g., "4hr" or "2h 30m")
  final String label;

  /// Size of the gauge
  final double size;

  /// Number of tick marks around the arc
  final int tickCount;

  /// Color for active/filled ticks
  final Color? activeColor;

  /// Color for inactive ticks
  final Color? inactiveColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = activeColor ?? Colors.white;
    final inactive = inactiveColor ?? Colors.white.withValues(alpha: 0.25);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _GaugeTickPainter(
              percentage: (value / maxValue).clamp(0.0, 1.0),
              tickCount: tickCount,
              activeColor: active,
              inactiveColor: inactive,
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            builder: (context, animValue, child) {
              return Opacity(
                opacity: animValue,
                child: Transform.scale(
                  scale: 0.8 + (0.2 * animValue),
                  child: child,
                ),
              );
            },
            child: Text(
              label,
              style: theme.textTheme.displayMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugeTickPainter extends CustomPainter {
  _GaugeTickPainter({
    required this.percentage,
    required this.tickCount,
    required this.activeColor,
    required this.inactiveColor,
  });

  final double percentage;
  final int tickCount;
  final Color activeColor;
  final Color inactiveColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // Arc spans from -225 degrees to +45 degrees (270 degree arc, bottom-left to bottom-right)
    const startAngle = -225 * (math.pi / 180);
    const sweepAngle = 270 * (math.pi / 180);

    final tickLength = size.width * 0.06;
    final tickWidth = size.width * 0.025;

    final activeTicks = (percentage * tickCount).round();

    for (int i = 0; i < tickCount; i++) {
      final tickAngle = startAngle + (sweepAngle * i / (tickCount - 1));
      final isActive = i < activeTicks;

      final innerRadius = radius - tickLength;
      final outerRadius = radius;

      final innerPoint = Offset(
        center.dx + innerRadius * math.cos(tickAngle),
        center.dy + innerRadius * math.sin(tickAngle),
      );
      final outerPoint = Offset(
        center.dx + outerRadius * math.cos(tickAngle),
        center.dy + outerRadius * math.sin(tickAngle),
      );

      final paint = Paint()
        ..color = isActive ? activeColor : inactiveColor
        ..strokeWidth = tickWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(innerPoint, outerPoint, paint);
    }
  }

  @override
  bool shouldRepaint(_GaugeTickPainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.tickCount != tickCount ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}
