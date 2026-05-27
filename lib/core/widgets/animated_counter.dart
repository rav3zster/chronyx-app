import 'package:chronyx/core/theme/design_tokens.dart';
import 'package:flutter/material.dart';

/// A counter that animates from 0 (or previous value) to [value] on build.
class AnimatedCounter extends StatefulWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.suffix,
    this.fractionDigits = 0,
    this.duration = DesignTokens.motionSlow,
  });

  final num value;
  final TextStyle? style;
  final String? suffix;
  final int fractionDigits;
  final Duration duration;

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(begin: 0, end: widget.value.toDouble()).animate(
      CurvedAnimation(parent: _controller, curve: DesignTokens.easeOut),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation =
          Tween<double>(
            begin: _animation.value,
            end: widget.value.toDouble(),
          ).animate(
            CurvedAnimation(parent: _controller, curve: DesignTokens.easeOut),
          );
      _controller
        ..reset()
        ..forward();
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
      builder: (context, _) {
        final v = _animation.value;
        final formatted = widget.fractionDigits == 0
            ? v.round().toString()
            : v.toStringAsFixed(widget.fractionDigits);
        return Text('$formatted${widget.suffix ?? ''}', style: widget.style);
      },
    );
  }
}
