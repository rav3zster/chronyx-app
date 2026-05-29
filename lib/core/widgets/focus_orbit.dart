import 'dart:math' as math;

import 'package:chronyx/core/theme/design_tokens.dart';
import 'package:flutter/material.dart';

/// The signature Focus Orbit ring — inspired by the left reference image.
///
/// A large circular progress visualization with:
/// - Outer track ring (dim)
/// - Animated gradient arc showing focus %
/// - Subtle tick marks at 25% intervals
/// - Center content slot
/// - Soft glow on the arc tip
class FocusOrbit extends StatefulWidget {
  const FocusOrbit({
    super.key,
    required this.progress,
    required this.size,
    this.strokeWidth = 10,
    this.child,
    this.arcColor,
  });

  /// 0.0 – 1.0
  final double progress;
  final double size;
  final double strokeWidth;
  final Widget? child;
  final Color? arcColor;

  @override
  State<FocusOrbit> createState() => _FocusOrbitState();
}

class _FocusOrbitState extends State<FocusOrbit>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: DesignTokens.motionSlow,
  );
  late Animation<double> _anim = CurvedAnimation(
    parent: _ctrl,
    curve: DesignTokens.easeOut,
  );

  @override
  void initState() {
    super.initState();
    _anim = Tween<double>(
      begin: 0,
      end: widget.progress.clamp(0, 1),
    ).animate(CurvedAnimation(parent: _ctrl, curve: DesignTokens.easeOut));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant FocusOrbit old) {
    super.didUpdateWidget(old);
    if (old.progress != widget.progress) {
      _anim = Tween<double>(
        begin: _anim.value,
        end: widget.progress.clamp(0, 1),
      ).animate(CurvedAnimation(parent: _ctrl, curve: DesignTokens.easeOut));
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final arcColor = widget.arcColor ?? scheme.primary;

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _OrbitPainter(
              progress: _anim.value,
              strokeWidth: widget.strokeWidth,
              arcColor: arcColor,
              trackColor: scheme.outlineVariant.withValues(alpha: 0.18),
              tickColor: scheme.outlineVariant.withValues(alpha: 0.30),
            ),
            child: Center(child: widget.child),
          ),
        );
      },
    );
  }
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter({
    required this.progress,
    required this.strokeWidth,
    required this.arcColor,
    required this.trackColor,
    required this.tickColor,
  });

  final double progress;
  final double strokeWidth;
  final Color arcColor;
  final Color trackColor;
  final Color tickColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // ── Track ring ──────────────────────────────────────────────────────────
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // ── Tick marks at 0%, 25%, 50%, 75% ────────────────────────────────────
    final tickPaint = Paint()
      ..color = tickColor
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final angle = -math.pi / 2 + (i * math.pi / 2);
      final inner = radius - strokeWidth / 2 - 4;
      final outer = radius + strokeWidth / 2 + 4;
      canvas.drawLine(
        Offset(
          center.dx + inner * math.cos(angle),
          center.dy + inner * math.sin(angle),
        ),
        Offset(
          center.dx + outer * math.cos(angle),
          center.dy + outer * math.sin(angle),
        ),
        tickPaint,
      );
    }

    if (progress <= 0) return;

    // ── Progress arc ────────────────────────────────────────────────────────
    final sweepAngle = progress * 2 * math.pi;
    final gradient = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: -math.pi / 2 + sweepAngle,
      colors: [arcColor.withValues(alpha: 0.6), arcColor],
    );

    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweepAngle,
      false,
      Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    // ── Glow dot at arc tip ─────────────────────────────────────────────────
    final tipAngle = -math.pi / 2 + sweepAngle;
    final tipX = center.dx + radius * math.cos(tipAngle);
    final tipY = center.dy + radius * math.sin(tipAngle);

    // Outer glow
    canvas.drawCircle(
      Offset(tipX, tipY),
      strokeWidth * 0.9,
      Paint()
        ..color = arcColor.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    // Bright dot
    canvas.drawCircle(
      Offset(tipX, tipY),
      strokeWidth * 0.45,
      Paint()..color = Colors.white.withValues(alpha: 0.95),
    );
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter old) =>
      old.progress != progress || old.arcColor != arcColor;
}
