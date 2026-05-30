import 'dart:math' as math;

import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/routing/app_routes.dart';
import 'package:chronyx/core/theme/scheme_x.dart';
import 'package:chronyx/features/analytics/domain/entities/analytics_summary.dart';
import 'package:chronyx/features/project_planner/domain/entities/momentum_score.dart';
import 'package:chronyx/features/project_planner/domain/entities/project.dart';
import 'package:chronyx/features/project_planner/domain/entities/project_health.dart';
import 'package:chronyx/features/project_planner/domain/entities/project_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Premium execution dashboard for an active/paused/draft project with tasks.
/// Information hierarchy: Hero → Today's Focus → Momentum → Timeline.
class ProjectDashboardView extends StatelessWidget {
  const ProjectDashboardView({
    super.key,
    required this.project,
    required this.tasks,
    required this.analytics,
    required this.onToggleTask,
    required this.onStartSession,
    required this.onRegenerateDay,
  });

  final Project project;
  final List<ProjectTask> tasks;
  final AnalyticsSummary? analytics;
  final void Function(ProjectTask task) onToggleTask;
  final VoidCallback onStartSession;
  final VoidCallback onRegenerateDay;

  @override
  Widget build(BuildContext context) {
    final today = project.currentDayNumber;
    final todayTasks = tasks.where((t) => t.dayNumber == today).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 48),
      children: [
        _HeroSection(project: project, tasks: tasks),
        const SizedBox(height: 12),
        _TodaysFocus(
          dayNumber: today,
          tasks: todayTasks,
          onToggleTask: onToggleTask,
          onStartSession: onStartSession,
          onRegenerateDay: onRegenerateDay,
        ),
        const SizedBox(height: 12),
        _MomentumStrip(analytics: analytics, tasks: tasks),
        const SizedBox(height: 12),
        _TimelineSection(project: project, tasks: tasks),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. HERO — ring + dense stats
// ─────────────────────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.project, required this.tasks});
  final Project project;
  final List<ProjectTask> tasks;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final total = tasks.length;
    final completed = tasks
        .where((t) => t.status == ProjectTaskStatus.completed)
        .length;
    final pct = total == 0 ? 0.0 : completed / total;

    final health = ProjectHealth.calculate(
      createdAt: project.effectiveStartDate,
      durationDays: project.durationDays,
      completedTasks: completed,
      totalTasks: total,
    );
    final healthColor = _healthColor(health.status, scheme);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: scheme.elevatedCard,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          // Compact, refined ring with eased fill animation.
          SizedBox(
            width: 76,
            height: 76,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => CustomPaint(
                painter: _RingPainter(
                  progress: value,
                  track: scheme.onSurface.withValues(alpha: 0.07),
                  arc: scheme.primary,
                ),
                child: Center(
                  child: Text(
                    '${(value * 100).round()}',
                    style: textTheme.titleLarge?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          // Typography-driven stats — big numbers dominate, tiny labels.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${(pct * 100).round()}%',
                      style: textTheme.headlineMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        'DONE',
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Day X / N · M left — one tight typographic line.
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Day ${project.currentDayNumber}',
                        style: textTheme.titleMedium?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: ' / ${project.durationDays}',
                        style: textTheme.titleMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(
                        text: '   ·   ${project.remainingDays} left',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Pill(
                      icon: Icons.local_fire_department_rounded,
                      label: '${project.streakDays}',
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 7),
                    _Pill(
                      icon: null,
                      label: '${health.status.emoji} ${health.status.label}',
                      color: healthColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.color});
  final IconData? icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.fromLTRB(icon != null ? 7 : 10, 5, 10, 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.track,
    required this.arc,
  });
  final double progress;
  final Color track;
  final Color arc;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    const sw = 5.0;
    final r = size.width / 2 - sw;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw,
    );
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        progress.clamp(0.0, 1.0) * 2 * math.pi,
        false,
        Paint()
          ..color = arc
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.arc != arc || old.track != track;
}

Color _healthColor(ProjectHealthStatus s, ColorScheme scheme) => switch (s) {
  ProjectHealthStatus.ahead => scheme.primary,
  ProjectHealthStatus.onTrack => const Color(0xFF22D3A6),
  ProjectHealthStatus.slightlyBehind => const Color(0xFFF59E0B),
  ProjectHealthStatus.behind => scheme.error,
};

// ─────────────────────────────────────────────────────────────────────────────
// 2. TODAY'S FOCUS — the primary CTA
// ─────────────────────────────────────────────────────────────────────────────

class _TodaysFocus extends StatelessWidget {
  const _TodaysFocus({
    required this.dayNumber,
    required this.tasks,
    required this.onToggleTask,
    required this.onStartSession,
    required this.onRegenerateDay,
  });

  final int dayNumber;
  final List<ProjectTask> tasks;
  final void Function(ProjectTask task) onToggleTask;
  final VoidCallback onStartSession;
  final VoidCallback onRegenerateDay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final completed = tasks
        .where((t) => t.status == ProjectTaskStatus.completed)
        .length;
    final totalMinutes = tasks.fold<int>(
      0,
      (s, t) => s + (t.estimatedMinutes ?? 0),
    );
    final pct = tasks.isEmpty ? 0 : (completed / tasks.length * 100).round();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.elevatedCard,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "TODAY'S FOCUS",
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                ),
              ),
              const Spacer(),
              if (tasks.isNotEmpty)
                Text(
                  '$completed/${tasks.length} · $pct%',
                  style: textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (tasks.isEmpty)
            _EmptyToday(onRegenerateDay: onRegenerateDay)
          else ...[
            Row(
              children: [
                Icon(
                  Icons.event_available_rounded,
                  size: 15,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'Day $dayNumber · ${tasks.length} task${tasks.length == 1 ? '' : 's'} · ~${totalMinutes}m',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Up to 3 task previews
            ...tasks
                .take(3)
                .map(
                  (t) =>
                      _TodayTaskRow(task: t, onToggle: () => onToggleTask(t)),
                ),
            if (tasks.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 30),
                child: Text(
                  '+${tasks.length - 3} more today',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: 14),
            _PrimaryCta(
              label: 'Start Focus Session',
              icon: Icons.play_arrow_rounded,
              onTap: onStartSession,
            ),
          ],
        ],
      ),
    );
  }
}

class _TodayTaskRow extends StatelessWidget {
  const _TodayTaskRow({required this.task, required this.onToggle});
  final ProjectTask task;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final done = task.status == ProjectTaskStatus.completed;

    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                done
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                key: ValueKey(done),
                size: 22,
                color: done ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: textTheme.bodyMedium!.copyWith(
                  color: done ? scheme.onSurfaceVariant : scheme.onSurface,
                  fontWeight: FontWeight.w600,
                  decoration: done ? TextDecoration.lineThrough : null,
                ),
                child: Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (task.estimatedMinutes != null) ...[
              const SizedBox(width: 8),
              Text(
                '${task.estimatedMinutes}m',
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyToday extends StatelessWidget {
  const _EmptyToday({required this.onRegenerateDay});
  final VoidCallback onRegenerateDay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nothing scheduled today.',
          style: textTheme.titleSmall?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Take a rest, jump ahead, or reshape today.',
          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SecondaryCta(
                label: 'Regenerate Day',
                icon: Icons.auto_mode_rounded,
                onTap: onRegenerateDay,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PrimaryCta extends StatelessWidget {
  const _PrimaryCta({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: scheme.primary,
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        onTap: onTap,
        child: Container(
          height: 50,
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: scheme.onPrimary),
              const SizedBox(width: 8),
              Text(
                label,
                style: textTheme.titleSmall?.copyWith(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryCta extends StatelessWidget {
  const _SecondaryCta({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        onTap: onTap,
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: scheme.onSurface),
              const SizedBox(width: 8),
              Text(
                label,
                style: textTheme.labelLarge?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. MOMENTUM — compact intelligence layer (taps to full analytics)
// ─────────────────────────────────────────────────────────────────────────────

class _MomentumStrip extends StatelessWidget {
  const _MomentumStrip({required this.analytics, required this.tasks});
  final AnalyticsSummary? analytics;
  final List<ProjectTask> tasks;

  String _topCategory(AnalyticsSummary a) {
    if (a.categoryBreakdown.isEmpty) return '—';
    final top = a.categoryBreakdown.entries.reduce(
      (x, y) => x.value >= y.value ? x : y,
    );
    final label = top.key.isEmpty
        ? '—'
        : top.key[0].toUpperCase() + top.key.substring(1);
    return label;
  }

  /// A tiny interpretation of the week so the strip feels alive.
  /// Returns (icon, message, color-positive?).
  (IconData, String, bool) _insight(AnalyticsSummary a, ColorScheme scheme) {
    // First half vs second half of the 7-day window.
    var first = 0, second = 0, inactive = 0;
    for (var i = 0; i < 7; i++) {
      final v = a.dailyMinutes[i] ?? 0;
      if (v == 0) inactive++;
      if (i >= 4) {
        first += v; // older days (offset 4,5,6)
      } else {
        second += v; // recent days (offset 0..3)
      }
    }

    if (first == 0 && second == 0) {
      return (Icons.bolt_outlined, 'Track a session to build momentum', false);
    }
    if (inactive >= 3) {
      return (
        Icons.trending_down_rounded,
        'Consistency dipped · $inactive inactive day${inactive == 1 ? '' : 's'}',
        false,
      );
    }
    if (first == 0) {
      return (Icons.trending_up_rounded, "You're picking up speed", true);
    }
    final delta = ((second - first) / first * 100).round();
    if (delta >= 8) {
      return (Icons.trending_up_rounded, 'Momentum +$delta% · improving', true);
    }
    if (delta <= -8) {
      return (
        Icons.trending_down_rounded,
        'Momentum $delta% · easing off',
        false,
      );
    }
    return (Icons.show_chart_rounded, 'Steady rhythm this week', true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final a = analytics;

    final weekHours = a == null
        ? '0.0'
        : (a.totalMinutesWeekly / 60).toStringAsFixed(1);

    // Real momentum score (0–100) blended from consistency, effort,
    // roadmap progress, and weekly trend.
    int momentum = 0;
    if (a != null) {
      var activeDays = 0;
      var first = 0, second = 0;
      for (var i = 0; i < 7; i++) {
        final v = a.dailyMinutes[i] ?? 0;
        if (v > 0) activeDays++;
        if (i >= 4) {
          first += v;
        } else {
          second += v;
        }
      }
      final ratio = first == 0 ? (second > 0 ? 2.0 : 1.0) : second / first;
      final completed = tasks
          .where((t) => t.status == ProjectTaskStatus.completed)
          .length;
      momentum = MomentumScore.compute(
        activeDaysThisWeek: activeDays,
        minutesThisWeek: a.totalMinutesWeekly,
        completedTasks: completed,
        totalTasks: tasks.length,
        recentVsEarlierRatio: ratio,
      ).score;
    }
    final topCat = a == null ? '—' : _topCategory(a);

    // 7-day spark data, oldest → newest
    final spark = <double>[];
    if (a != null) {
      for (var i = 6; i >= 0; i--) {
        spark.add((a.dailyMinutes[i] ?? 0).toDouble());
      }
    }

    final (insightIcon, insightText, positive) = a == null
        ? (Icons.bolt_outlined, 'Track a session to build momentum', false)
        : _insight(a, scheme);
    final insightColor = positive
        ? const Color(0xFF22D3A6)
        : scheme.onSurfaceVariant;

    return Material(
      color: scheme.elevatedCard,
      borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
        onTap: () => context.push(AppRoutes.analytics),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(insightIcon, size: 14, color: insightColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      insightText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelMedium?.copyWith(
                        color: insightColor,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 15,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _Metric(value: '${weekHours}h', label: 'This week'),
                  _divider(scheme),
                  _Metric(value: '$momentum', label: 'Momentum'),
                  _divider(scheme),
                  _Metric(value: topCat, label: 'Top focus'),
                  const Spacer(),
                  // Tiny sparkline
                  if (spark.any((v) => v > 0))
                    SizedBox(
                      width: 54,
                      height: 28,
                      child: CustomPaint(
                        painter: _SparkPainter(
                          points: spark,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider(ColorScheme scheme) => Container(
    width: 1,
    height: 26,
    margin: const EdgeInsets.symmetric(horizontal: 14),
    color: scheme.onSurface.withValues(alpha: 0.08),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: textTheme.titleMedium?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontSize: 9,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _SparkPainter extends CustomPainter {
  const _SparkPainter({required this.points, required this.color});
  final List<double> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final maxV = points.reduce(math.max);
    if (maxV <= 0) return;
    final dx = size.width / (points.length - 1);
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = dx * i;
      final y = size.height - (points[i] / maxV) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    // last-point dot
    final lastX = dx * (points.length - 1);
    final lastY = size.height - (points.last / maxV) * size.height;
    canvas.drawCircle(Offset(lastX, lastY), 2.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.points != points;
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. TIMELINE — collapsible by week, lazy
// ─────────────────────────────────────────────────────────────────────────────

enum _DayState { completed, inProgress, locked }

class _TimelineSection extends StatelessWidget {
  const _TimelineSection({required this.project, required this.tasks});
  final Project project;
  final List<ProjectTask> tasks;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final today = project.currentDayNumber;

    final byDay = <int, List<ProjectTask>>{};
    for (final t in tasks) {
      byDay.putIfAbsent(t.dayNumber, () => []).add(t);
    }
    final days = byDay.keys.toList()..sort();
    if (days.isEmpty) return const SizedBox.shrink();

    final weeks = <int, List<int>>{};
    for (final d in days) {
      final w = ((d - 1) ~/ 7) + 1;
      weeks.putIfAbsent(w, () => []).add(d);
    }

    _DayState stateFor(int day) {
      final dayTasks = byDay[day] ?? const [];
      final allDone =
          dayTasks.isNotEmpty &&
          dayTasks.every((t) => t.status == ProjectTaskStatus.completed);
      if (allDone) return _DayState.completed;
      if (day <= today) return _DayState.inProgress;
      return _DayState.locked;
    }

    return Container(
      decoration: BoxDecoration(
        color: scheme.elevatedCard,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: Row(
              children: [
                Text(
                  'ROADMAP',
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                  ),
                ),
                const Spacer(),
                Text(
                  '${days.where((d) => stateFor(d) == _DayState.completed).length} of ${days.length} days',
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          ...weeks.entries.map(
            (entry) => _WeekGroup(
              week: entry.key,
              days: entry.value,
              today: today,
              stateFor: stateFor,
              byDay: byDay,
              initiallyExpanded: entry.value.contains(today),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Collapsible week with smooth size+fade expand and a journey rail.
class _WeekGroup extends StatefulWidget {
  const _WeekGroup({
    required this.week,
    required this.days,
    required this.today,
    required this.stateFor,
    required this.byDay,
    required this.initiallyExpanded,
  });

  final int week;
  final List<int> days;
  final int today;
  final _DayState Function(int day) stateFor;
  final Map<int, List<ProjectTask>> byDay;
  final bool initiallyExpanded;

  @override
  State<_WeekGroup> createState() => _WeekGroupState();
}

class _WeekGroupState extends State<_WeekGroup> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final doneCount = widget.days
        .where((d) => widget.stateFor(d) == _DayState.completed)
        .length;
    final hasToday = widget.days.contains(widget.today);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _expanded = !_expanded);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                Text(
                  'Week ${widget.week}',
                  style: textTheme.titleSmall?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (hasToday) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  '$doneCount/${widget.days.length}',
                  style: textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: _expanded ? 1 : 0,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  children: [
                    for (var i = 0; i < widget.days.length; i++)
                      _TimelineDayRow(
                        day: widget.days[i],
                        state: widget.stateFor(widget.days[i]),
                        isToday: widget.days[i] == widget.today,
                        taskCount: widget.byDay[widget.days[i]]?.length ?? 0,
                        isFirst: i == 0,
                        isLast: i == widget.days.length - 1,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One day on the journey rail: connector + node + label.
class _TimelineDayRow extends StatelessWidget {
  const _TimelineDayRow({
    required this.day,
    required this.state,
    required this.isToday,
    required this.taskCount,
    required this.isFirst,
    required this.isLast,
  });

  final int day;
  final _DayState state;
  final bool isToday;
  final int taskCount;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    const mint = Color(0xFF22D3A6);

    final label = switch (state) {
      _DayState.completed => 'Completed',
      _DayState.inProgress => 'In progress',
      _DayState.locked => 'Locked',
    };
    final nodeColor = switch (state) {
      _DayState.completed => mint,
      _DayState.inProgress => scheme.primary,
      _DayState.locked => scheme.onSurfaceVariant.withValues(alpha: 0.45),
    };
    final railColor = scheme.onSurface.withValues(alpha: 0.10);

    return IntrinsicHeight(
      child: Container(
        color: isToday ? scheme.primary.withValues(alpha: 0.06) : null,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 24,
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 2,
                        color: isFirst ? Colors.transparent : railColor,
                      ),
                    ),
                  ),
                  _Node(state: state, color: nodeColor, isToday: isToday),
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 2,
                        color: isLast ? Colors.transparent : railColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Text(
                      'Day $day',
                      style: textTheme.bodyMedium?.copyWith(
                        color: state == _DayState.locked
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface,
                        fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusFull,
                          ),
                        ),
                        child: Text(
                          'TODAY',
                          style: textTheme.labelSmall?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 8,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      taskCount == 0
                          ? label
                          : '$taskCount task${taskCount == 1 ? '' : 's'}',
                      style: textTheme.labelSmall?.copyWith(
                        color: state == _DayState.completed
                            ? mint
                            : scheme.onSurfaceVariant,
                        fontWeight: state == _DayState.completed
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Journey node: filled+glow for completed, ringed for in-progress,
/// hollow for locked.
class _Node extends StatelessWidget {
  const _Node({
    required this.state,
    required this.color,
    required this.isToday,
  });
  final _DayState state;
  final Color color;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    switch (state) {
      case _DayState.completed:
        return Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 7),
            ],
          ),
          child: Icon(Icons.check_rounded, size: 11, color: scheme.surface),
        );
      case _DayState.inProgress:
        return Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: scheme.elevatedCard,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: isToday ? 3 : 2),
            boxShadow: isToday
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 7,
                    ),
                  ]
                : null,
          ),
        );
      case _DayState.locked:
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: scheme.onSurface.withValues(alpha: 0.10),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
        );
    }
  }
}
