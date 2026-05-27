import 'package:chronyx/core/theme/design_tokens.dart';
import 'package:flutter/material.dart';

/// Premium press feedback: subtle scale + light haptic.
///
/// Wrap any tappable surface that should feel responsive. Use this
/// instead of bare GestureDetector on cards, tiles, and pill buttons.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    required this.onTap,
    this.scaleTo = 0.97,
    this.duration = DesignTokens.motionFast,
    this.haptics = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scaleTo;
  final Duration duration;
  final bool haptics;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 1.0,
    end: widget.scaleTo,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _down(_) {
    if (widget.onTap == null) return;
    _ctrl.forward();
  }

  void _up(_) => _ctrl.reverse();
  void _cancel() => _ctrl.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: _down,
      onTapUp: _up,
      onTapCancel: _cancel,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
