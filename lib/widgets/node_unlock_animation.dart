import 'package:flutter/material.dart';

class NodeUnlockAnimation extends StatefulWidget {
  final Widget child;
  final bool isUnlocked;

  const NodeUnlockAnimation({
    super.key,
    required this.child,
    required this.isUnlocked,
  });

  @override
  State<NodeUnlockAnimation> createState() => _NodeUnlockAnimationState();
}

class _NodeUnlockAnimationState extends State<NodeUnlockAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 70),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.1), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 0.1, end: -0.1), weight: 10),
      TweenSequenceItem(tween: Tween(begin: -0.1, end: 0.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.0), weight: 70),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.isUnlocked) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(NodeUnlockAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isUnlocked && !oldWidget.isUnlocked) {
      _controller.forward(from: 0.0);
    }
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
        return Transform.rotate(
          angle: _shakeAnimation.value,
          child: Transform.scale(scale: _scaleAnimation.value, child: child),
        );
      },
      child: widget.child,
    );
  }
}
