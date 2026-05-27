import 'dart:math' as math;

import 'package:chronyx/core/theme/design_tokens.dart';
import 'package:chronyx/features/life_insights/domain/entities/time_allocation.dart';
import 'package:flutter/material.dart';

/// A premium animated donut chart for time allocation.
///
/// Renders sliced segments with subtle gaps, rounded caps, and a
/// cinematic fill animation on first build.
class AllocationDonut extends StatefulWidget {
  const AllocationDonut({
    super.key,
    required this.allocation,
    this.size = 124,
    this.strokeWidth = 16,
    this.centerChild,
  });

  final TimeAllocation allocation;
  final double size;
  final double strokeWidth;
  final Widget? centerChild;

  @override
  State<AllocationDonut> createState() => _AllocationDonutState();
}

class _AllocationDonutState extends State<AllocationDonut>
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
  void didUpdateWidget(covariant AllocationDonut old) {
    super.didUpdateWidget(old);
    if (old.allocation.totalMinutes != widget.allocation.totalMinutes) {
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
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _DonutPainter(
              slices: widget.allocation.sorted,
              totalMinutes: widget.allocation.totalMinutes,
              strokeWidth: widget.strokeWidth,
              progress: _animation.value,
              trackColor: scheme.outlineVariant.withValues(alpha: 0.35),
            ),
            child: Center(child: widget.centerChild),
          ),
        );
      },
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.slices,
    required this.totalMinutes,
    required this.strokeWidth,
    required this.progress,
    required this.trackColor,
  });

  final List<AllocationSlice> slices;
  final int totalMinutes;
  final double strokeWidth;
  final double progress;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background ring (always visible).
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);

    if (totalMinutes == 0 || slices.isEmpty) return;

    const startBase = -math.pi / 2;
    const gapRadians = 0.04; // small visual gap between slices
    var cursor = startBase;

    for (var i = 0; i < slices.length; i++) {
      final slice = slices[i];
      if (slice.minutes <= 0) continue;
      final ratio = slice.minutes / totalMinutes;
      final fullSweep = ratio * 2 * math.pi;
      final visibleSweep = (fullSweep - gapRadians).clamp(0.01, 2 * math.pi);
      final animatedSweep = visibleSweep * progress;

      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, cursor, animatedSweep, false, paint);
      cursor += fullSweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.progress != progress ||
      old.totalMinutes != totalMinutes ||
      old.slices.length != slices.length;
}
