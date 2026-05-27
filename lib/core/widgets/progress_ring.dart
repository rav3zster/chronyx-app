import 'dart:math' as math;

import 'package:chronyx/core/theme/design_tokens.dart';
import 'package:flutter/material.dart';

/// A premium animated progress ring with gradient stroke.
///
/// Animates fill on first build (cinematic reveal) and on value change.
class ProgressRing extends StatefulWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 72,
    this.strokeWidth = 6,
    this.gradient,
    this.trackColor,
    this.child,
  });

  /// 0.0 to 1.0
  final double progress;
  final double size;
  final double strokeWidth;
  final Gradient? gradient;
  final Color? trackColor;
  final Widget? child;

  @override
  State<ProgressRing> createState() => _ProgressRingState();
}

class _ProgressRingState extends State<ProgressRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: DesignTokens.motionSlow,
    );
    _animation = Tween<double>(begin: 0, end: widget.progress.clamp(0, 1))
        .animate(
          CurvedAnimation(parent: _controller, curve: DesignTokens.easeOut),
        );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant ProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _animation =
          Tween<double>(
            begin: _animation.value,
            end: widget.progress.clamp(0, 1),
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
    final scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _RingPainter(
              progress: _animation.value,
              strokeWidth: widget.strokeWidth,
              gradient: widget.gradient ?? DesignTokens.auroraGradient,
              trackColor:
                  widget.trackColor ??
                  scheme.outlineVariant.withValues(alpha: 0.4),
            ),
            child: Center(child: widget.child),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.gradient,
    required this.trackColor,
  });

  final double progress;
  final double strokeWidth;
  final Gradient gradient;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    if (progress > 0) {
      final progressPaint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      const startAngle = -math.pi / 2;
      final sweepAngle = progress * 2 * math.pi;
      canvas.drawArc(rect, startAngle, sweepAngle, false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress ||
      old.strokeWidth != strokeWidth ||
      old.trackColor != trackColor;
}
