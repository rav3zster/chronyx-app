import 'package:chronyx/core/services/haptic_service.dart';
import 'package:chronyx/core/services/sound_service.dart';
import 'package:chronyx/core/theme/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Premium press feedback: subtle scale + haptic (respects settings).
///
/// Wrap any tappable surface that should feel responsive. Use this
/// instead of bare GestureDetector on cards, tiles, and pill buttons.
class PressScale extends ConsumerStatefulWidget {
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
  ConsumerState<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends ConsumerState<PressScale>
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

  void _up(_) {
    _ctrl.reverse();
    if (widget.onTap != null) {
      if (widget.haptics) {
        ref.read(hapticServiceProvider).selectionClick();
      }
      ref.read(soundServiceProvider).buttonPress();
    }
  }

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
