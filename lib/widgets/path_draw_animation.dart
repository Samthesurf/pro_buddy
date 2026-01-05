import 'package:flutter/material.dart';

class PathDrawAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final bool isVertical;

  const PathDrawAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1000),
    this.delay = Duration.zero,
    this.isVertical = true,
  });

  @override
  State<PathDrawAnimation> createState() => _PathDrawAnimationState();
}

class _PathDrawAnimationState extends State<PathDrawAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
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
      animation: _animation,
      builder: (context, child) {
        return ClipRect(
          child: Align(
            alignment: widget.isVertical
                ? Alignment.topCenter
                : Alignment.centerLeft,
            heightFactor: widget.isVertical ? _animation.value : 1.0,
            widthFactor: widget.isVertical ? 1.0 : _animation.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
