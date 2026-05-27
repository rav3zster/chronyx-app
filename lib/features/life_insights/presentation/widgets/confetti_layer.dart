import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Subtle, non-childish celebration confetti that drifts upward and fades.
///
/// Plays once on first build. Designed for celebration moments —
/// premium, soft, no animal noises.
class ConfettiLayer extends StatefulWidget {
  const ConfettiLayer({
    super.key,
    this.particleCount = 24,
    this.colors,
    this.duration = const Duration(milliseconds: 2400),
  });

  final int particleCount;
  final List<Color>? colors;
  final Duration duration;

  @override
  State<ConfettiLayer> createState() => _ConfettiLayerState();
}

class _ConfettiLayerState extends State<ConfettiLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(42);
    final palette =
        widget.colors ??
        const [
          Color(0xFF22D3A6),
          Color(0xFF06B6D4),
          Color(0xFF818CF8),
          Color(0xFF8B5CF6),
          Color(0xFFF59E0B),
          Color(0xFFFF6B9C),
        ];
    _particles = List.generate(widget.particleCount, (_) {
      return _Particle(
        startX: rng.nextDouble(),
        endX: rng.nextDouble(),
        startY: 0.6 + rng.nextDouble() * 0.3,
        endY: -0.05 - rng.nextDouble() * 0.1,
        size: 4 + rng.nextDouble() * 6,
        color: palette[rng.nextInt(palette.length)],
        rotation: rng.nextDouble() * math.pi * 2,
        rotationSpeed: (rng.nextDouble() - 0.5) * 4,
        delay: rng.nextDouble() * 0.4,
      );
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            size: Size.infinite,
            painter: _ConfettiPainter(
              particles: _particles,
              progress: _controller.value,
            ),
          );
        },
      ),
    );
  }
}

class _Particle {
  _Particle({
    required this.startX,
    required this.endX,
    required this.startY,
    required this.endY,
    required this.size,
    required this.color,
    required this.rotation,
    required this.rotationSpeed,
    required this.delay,
  });

  final double startX;
  final double endX;
  final double startY;
  final double endY;
  final double size;
  final Color color;
  final double rotation;
  final double rotationSpeed;
  final double delay;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.particles, required this.progress});

  final List<_Particle> particles;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t = ((progress - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final eased = Curves.easeOutCubic.transform(t);
      final x = (p.startX + (p.endX - p.startX) * eased) * size.width;
      final y = (p.startY + (p.endY - p.startY) * eased) * size.height;
      final opacity = 1 - Curves.easeIn.transform(t);
      final paint = Paint()..color = p.color.withValues(alpha: opacity * 0.85);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + p.rotationSpeed * eased);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.4,
          ),
          const Radius.circular(1),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) =>
      old.progress != progress;
}
