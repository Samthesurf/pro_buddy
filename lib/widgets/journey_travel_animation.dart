import 'package:flutter/material.dart';

class JourneyTravelAnimation extends StatefulWidget {
  final Offset startOffset;
  final Offset endOffset;
  final VoidCallback onComplete;

  const JourneyTravelAnimation({
    super.key,
    required this.startOffset,
    required this.endOffset,
    required this.onComplete,
  });

  @override
  State<JourneyTravelAnimation> createState() => _JourneyTravelAnimationState();
}

class _JourneyTravelAnimationState extends State<JourneyTravelAnimation>
    with TickerProviderStateMixin {
  late AnimationController _travelController;
  late Animation<Offset> _positionAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _travelController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Simple vertical/linear travel for now since we are in a Column mostly
    // But we use Offset so it can be diagonal if needed
    _positionAnimation = Tween<Offset>(
      begin: widget.startOffset,
      end: widget.endOffset,
    ).animate(
      CurvedAnimation(
        parent: _travelController,
        curve: Curves.easeInOutCubic,
      ),
    );

    // Scale pulse during travel
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 25),
    ]).animate(_travelController);

    _travelController.forward().then((_) {
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _travelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _travelController,
      builder: (context, child) {
        return Positioned(
          left: _positionAnimation.value.dx,
          top: _positionAnimation.value.dy,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Colors.amber, Colors.orange, Colors.transparent],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.6),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(Icons.star, color: Colors.white, size: 24),
            ),
          ),
        );
      },
    );
  }
}
