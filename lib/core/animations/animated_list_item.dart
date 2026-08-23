import 'package:flutter/material.dart';
import 'animation_constants.dart';

class AnimatedListItem extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration? duration;
  final Duration? delay;
  final double slideOffset;

  const AnimatedListItem({
    super.key,
    required this.child,
    required this.index,
    this.duration,
    this.delay,
    this.slideOffset = 12.0,
  });

  @override
  State<AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<AnimatedListItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration ?? AppAnimation.listItemDuration,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: AppAnimation.standard,
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, widget.slideOffset),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AppAnimation.standard,
    ));

    final clampedIndex = widget.index.clamp(0, AppAnimation.staggerMaxIndex);
    final delay = widget.delay ??
        Duration(
          milliseconds:
              clampedIndex * AppAnimation.staggerDelay.inMilliseconds,
        );

    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppAnimation.shouldReduceMotion(context)) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: _slideAnimation.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
