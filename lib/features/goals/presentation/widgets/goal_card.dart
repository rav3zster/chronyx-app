import 'dart:math' as math;
import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/widgets/glass_card.dart';
import 'package:chronyx/features/goals/domain/entities/goal_progress.dart';
import 'package:flutter/material.dart';

class GoalCard extends StatelessWidget {
  const GoalCard({
    required this.progress,
    required this.onTap,
    super.key,
  });

  final GoalProgress progress;
  final VoidCallback onTap;

  Color _progressColor(double pct) {
    if (pct >= 80) return const Color(0xFF22D3A6);
    if (pct >= 50) return const Color(0xFF818CF8);
    if (pct >= 25) return const Color(0xFFFBBC05);
    return const Color(0xFFEA4335);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final pct = progress.percentCompleted.clamp(0.0, 100.0);
    final color = _progressColor(pct);
    final now = DateTime.now();
    final daysLeft = progress.goal.endDate.difference(now).inDays;
    final isExpired = daysLeft < 0;

    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        useBlur: false,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            // Progress ring
            SizedBox(
              width: 64,
              height: 64,
              child: CustomPaint(
                painter: _RingPainter(
                  progress: pct / 100,
                  color: color,
                  bgColor:
                      scheme.surfaceContainerHighest,
                ),
                child: Center(
                  child: Text(
                    '${pct.toStringAsFixed(0)}%',
                    style: textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          progress.goal.title,
                          style: textTheme.titleSmall?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (progress.goal.isChallenge)
                        Text('🔥',
                            style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  // Progress bar
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusFull),
                    child: LinearProgressIndicator(
                      value: pct / 100,
                      backgroundColor:
                          scheme.surfaceContainerHighest,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(color),
                      minHeight: 4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      _Pill(
                        icon: Icons.local_fire_department_rounded,
                        label: '${progress.currentStreak}d streak',
                        color: color,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      _Pill(
                        icon: isExpired
                            ? Icons.check_circle_outline_rounded
                            : Icons.hourglass_top_rounded,
                        label: isExpired
                            ? 'Ended'
                            : '${daysLeft}d left',
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: scheme.onSurfaceVariant,
              size: AppSpacing.iconMd,
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: color,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.bgColor,
  });

  final double progress;
  final Color color;
  final Color bgColor;

  @override
  void paint(Canvas canvas, Size size) {
    const double strokeWidth = 5.5;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (size.width / 2) - strokeWidth / 2;

    // Background ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = bgColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
