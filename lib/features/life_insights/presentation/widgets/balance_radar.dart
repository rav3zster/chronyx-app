import 'dart:math' as math;

import 'package:chronyx/core/theme/design_tokens.dart';
import 'package:chronyx/features/life_insights/domain/entities/life_balance.dart';
import 'package:flutter/material.dart';

/// Hexagonal life-balance radar.
///
/// Shows 6 axes (Learning, Career, Health, Focus, Social, Rest) with
/// the user's score on each. Animated fill on first build.
class BalanceRadar extends StatefulWidget {
  const BalanceRadar({super.key, required this.balance, this.size = 220});

  final LifeBalance balance;
  final double size;

  @override
  State<BalanceRadar> createState() => _BalanceRadarState();
}

class _BalanceRadarState extends State<BalanceRadar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: DesignTokens.motionSlow,
  );
  late final Animation<double> _animation = CurvedAnimation(
    parent: _controller,
    curve: DesignTokens.easeOut,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant BalanceRadar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.balance != widget.balance) {
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
            painter: _RadarPainter(
              axes: widget.balance.axes,
              progress: _animation.value,
              gridColor: scheme.outlineVariant.withValues(alpha: 0.35),
              fillStartColor: scheme.primary.withValues(alpha: 0.30),
              fillEndColor: scheme.secondary.withValues(alpha: 0.10),
              strokeColor: scheme.primary,
              labelColor: scheme.onSurfaceVariant,
              accentLabelColor: scheme.onSurface,
            ),
          ),
        );
      },
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.axes,
    required this.progress,
    required this.gridColor,
    required this.fillStartColor,
    required this.fillEndColor,
    required this.strokeColor,
    required this.labelColor,
    required this.accentLabelColor,
  });

  final List<BalanceAxis> axes;
  final double progress;
  final Color gridColor;
  final Color fillStartColor;
  final Color fillEndColor;
  final Color strokeColor;
  final Color labelColor;
  final Color accentLabelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 28; // padding for labels
    final n = axes.length;
    if (n == 0) return;

    // ── Grid: 4 concentric polygons ─────────────────────────────────
    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var ring = 1; ring <= 4; ring++) {
      final r = radius * (ring / 4);
      final path = Path();
      for (var i = 0; i < n; i++) {
        final angle = -math.pi / 2 + (i * 2 * math.pi / n);
        final x = center.dx + r * math.cos(angle);
        final y = center.dy + r * math.sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // ── Spokes ──────────────────────────────────────────────────────
    final spokePaint = Paint()
      ..color = gridColor.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (var i = 0; i < n; i++) {
      final angle = -math.pi / 2 + (i * 2 * math.pi / n);
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      canvas.drawLine(center, Offset(x, y), spokePaint);
    }

    // ── User score polygon ──────────────────────────────────────────
    final scorePath = Path();
    for (var i = 0; i < n; i++) {
      final angle = -math.pi / 2 + (i * 2 * math.pi / n);
      final r = radius * axes[i].score * progress;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        scorePath.moveTo(x, y);
      } else {
        scorePath.lineTo(x, y);
      }
    }
    scorePath.close();

    // Gradient fill
    final fillPaint = Paint()
      ..shader = RadialGradient(
        colors: [fillStartColor, fillEndColor],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawPath(scorePath, fillPaint);

    // Stroke
    final strokePaint = Paint()
      ..color = strokeColor.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(scorePath, strokePaint);

    // ── Vertex dots ────────────────────────────────────────────────
    for (var i = 0; i < n; i++) {
      final angle = -math.pi / 2 + (i * 2 * math.pi / n);
      final r = radius * axes[i].score * progress;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);

      final dotPaint = Paint()..color = axes[i].area.color;
      canvas.drawCircle(Offset(x, y), 4, dotPaint);

      final ringPaint = Paint()
        ..color = axes[i].area.color.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(Offset(x, y), 7, ringPaint);
    }

    // ── Axis labels (positioned outside) ───────────────────────────
    for (var i = 0; i < n; i++) {
      final angle = -math.pi / 2 + (i * 2 * math.pi / n);
      final labelRadius = radius + 20;
      final lx = center.dx + labelRadius * math.cos(angle);
      final ly = center.dy + labelRadius * math.sin(angle);
      final isHighlighted = axes[i].score > 0.65 || axes[i].score < 0.15;
      final tp = TextPainter(
        text: TextSpan(
          text: axes[i].area.label,
          style: TextStyle(
            color: isHighlighted ? accentLabelColor : labelColor,
            fontSize: 11,
            fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(lx - tp.width / 2, ly - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) => old.progress != progress;
}
