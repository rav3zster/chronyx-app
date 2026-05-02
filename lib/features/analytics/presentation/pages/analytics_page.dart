import 'dart:math' as math;
import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/errors/error_message_mapper.dart';
import 'package:chronyx/core/routing/app_routes.dart';
import 'package:chronyx/core/widgets/empty_state.dart';
import 'package:chronyx/core/widgets/error_card.dart';
import 'package:chronyx/core/widgets/glass_card.dart';
import 'package:chronyx/core/widgets/settings_icon_button.dart';
import 'package:chronyx/features/analytics/domain/entities/analytics_summary.dart';
import 'package:chronyx/features/analytics/presentation/providers/analytics_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(analyticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: const [SettingsIconButton(), SizedBox(width: AppSpacing.xs)],
      ),
      body: state.when(
        data: (summary) {
          if (summary == null) {
            return EmptyState(
              icon: Icons.analytics_outlined,
              title: 'No analytics yet',
              subtitle: 'Start tracking time to generate insights',
              ctaLabel: 'Track Time',
              onCta: () => context.go(AppRoutes.timeTracking),
            );
          }
          return _AnalyticsBody(summary: summary);
        },
        error: (err, _) => ErrorCard(
          message: ErrorMessageMapper.fromError(err),
          onRetry: () => ref.read(analyticsProvider.notifier).refresh(),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _AnalyticsBody extends StatelessWidget {
  const _AnalyticsBody({required this.summary});
  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xxxl + AppSpacing.lg,
      ),
      children: [
        // ── Productivity Score ───────────────────────────────────────────
        _ProductivityScoreCard(score: summary.productivityScore),
        const SizedBox(height: AppSpacing.md),

        // ── Stats Row ───────────────────────────────────────────────────
        _StatsRow(summary: summary),
        const SizedBox(height: AppSpacing.md),

        // ── Weekly Bar Chart ─────────────────────────────────────────────
        _SectionLabel(label: 'Last 7 Days'),
        const SizedBox(height: AppSpacing.sm),
        GlassCard(
          useBlur: false,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: _WeeklyBarChart(dailyMinutes: summary.dailyMinutes),
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Category Breakdown ───────────────────────────────────────────
        if (summary.categoryBreakdown.isNotEmpty) ...[
          _SectionLabel(label: 'Time by Category'),
          const SizedBox(height: AppSpacing.sm),
          GlassCard(
            useBlur: false,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: _CategoryBreakdown(breakdown: summary.categoryBreakdown),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        // ── Top Tasks ────────────────────────────────────────────────────
        if (summary.topTasks.isNotEmpty) ...[
          _SectionLabel(label: 'Top Tasks'),
          const SizedBox(height: AppSpacing.sm),
          GlassCard(
            useBlur: false,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: _TopTasksList(tasks: summary.topTasks),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        // ── Wrapped CTA ──────────────────────────────────────────────────
        _WrappedCta(),
      ],
    );
  }
}

// ── Productivity Score Card ───────────────────────────────────────────────────

class _ProductivityScoreCard extends StatelessWidget {
  const _ProductivityScoreCard({required this.score});
  final double score;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final color = score >= 70
        ? const Color(0xFF22D3A6)
        : score >= 40
            ? scheme.primary
            : scheme.error;
    final label = score >= 70
        ? 'Excellent'
        : score >= 40
            ? 'Good'
            : score > 0
                ? 'Needs Work'
                : 'No Data';

    return GlassCard(
      useBlur: false,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          // Ring gauge
          SizedBox(
            width: 72,
            height: 72,
            child: CustomPaint(
              painter: _ScoreRingPainter(score: score / 100, color: color),
              child: Center(
                child: Text(
                  score.toStringAsFixed(0),
                  style: textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Productivity Score',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: textTheme.titleLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Based on productive + learning time this week',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreRingPainter extends CustomPainter {
  const _ScoreRingPainter({required this.score, required this.color});
  final double score;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const sw = 6.0;
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - sw;

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = color.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw,
    );

    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * score,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ScoreRingPainter old) => old.score != score;
}

// ── Stats Row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.summary});
  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: _StatMini(
            icon: Icons.today_rounded,
            color: scheme.primary,
            label: 'Today',
            value:
                '${(summary.totalMinutesDaily / 60).toStringAsFixed(1)}h',
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatMini(
            icon: Icons.calendar_view_week_rounded,
            color: const Color(0xFF818CF8),
            label: 'This Week',
            value:
                '${(summary.totalMinutesWeekly / 60).toStringAsFixed(1)}h',
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatMini(
            icon: Icons.schedule_rounded,
            color: const Color(0xFFFBBC05),
            label: 'Peak Hour',
            value: '${summary.peakHour}:00',
          ),
        ),
      ],
    );
  }
}

class _StatMini extends StatelessWidget {
  const _StatMini({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GlassCard(
      useBlur: false,
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: AppSpacing.iconMd),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: textTheme.titleSmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Weekly Bar Chart ──────────────────────────────────────────────────────────

class _WeeklyBarChart extends StatelessWidget {
  const _WeeklyBarChart({required this.dailyMinutes});
  final Map<int, int> dailyMinutes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final maxMinutes =
        dailyMinutes.values.isEmpty ? 1 : dailyMinutes.values.reduce(math.max);
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final now = DateTime.now();

    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          final int dayOffset = 6 - i; // 6=oldest, 0=today
          final int minutes = dailyMinutes[dayOffset] ?? 0;
          final double ratio =
              maxMinutes == 0 ? 0.0 : minutes / maxMinutes;
          final bool isToday = dayOffset == 0;
          final dayName = days[(now.weekday - dayOffset - 1) % 7];

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (minutes > 0)
                    Text(
                      '${(minutes / 60).toStringAsFixed(1)}h',
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onSurface,
                        fontSize: 9,
                        fontWeight:
                            isToday ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      height: ratio * 72,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            scheme.primary,
                            scheme.secondary,
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dayName,
                    style: textTheme.labelSmall?.copyWith(
                      color: isToday
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                      fontSize: 9,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Category Breakdown ────────────────────────────────────────────────────────

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.breakdown});
  final Map<String, int> breakdown;

  static const Map<String, _CatMeta> _meta = {
    'productive': _CatMeta('🚀', 'Productive', Color(0xFF22D3A6)),
    'learning': _CatMeta('📚', 'Learning', Color(0xFF818CF8)),
    'break': _CatMeta('☕', 'Break', Color(0xFFFBBC05)),
    'distraction': _CatMeta('🌀', 'Distraction', Color(0xFFEA4335)),
    'other': _CatMeta('📌', 'Other', Color(0xFF94A3B8)),
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final total = breakdown.values.fold(0, (a, b) => a + b);

    return Column(
      children: breakdown.entries.map((e) {
        final meta = _meta[e.key] ??
            const _CatMeta('📌', 'Other', Color(0xFF94A3B8));
        final pct = total == 0 ? 0.0 : e.value / total;
        final mins = e.value;
        final hrs = (mins / 60).toStringAsFixed(1);

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(meta.emoji,
                      style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    meta.label,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${hrs}h · ${(pct * 100).toStringAsFixed(0)}%',
                    style: textTheme.labelSmall?.copyWith(
                      color: meta.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(AppSpacing.radiusFull),
                child: LinearProgressIndicator(
                  value: pct,
                  backgroundColor:
                      scheme.surfaceContainerHighest,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(meta.color),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _CatMeta {
  const _CatMeta(this.emoji, this.label, this.color);
  final String emoji;
  final String label;
  final Color color;
}

// ── Top Tasks ─────────────────────────────────────────────────────────────────

class _TopTasksList extends StatelessWidget {
  const _TopTasksList({required this.tasks});
  final List<MapEntry<String, int>> tasks;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final maxMins = tasks.first.value;

    return Column(
      children: tasks.take(5).toList().asMap().entries.map((e) {
        final rank = e.key + 1;
        final task = e.value;
        final ratio = maxMins == 0 ? 0.0 : task.value / maxMins;
        final hrs = (task.value / 60).toStringAsFixed(1);

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.15),
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Text(
                  '#$rank',
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.key,
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${hrs}h',
                          style: textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(
                          AppSpacing.radiusFull),
                      child: LinearProgressIndicator(
                        value: ratio,
                        backgroundColor:
                            scheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            scheme.primary),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Wrapped CTA ───────────────────────────────────────────────────────────────

class _WrappedCta extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GlassCard(
      useBlur: false,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        onTap: () => GoRouter.of(context).push(AppRoutes.wrapped),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [scheme.primary, scheme.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(Icons.auto_awesome_rounded,
                  color: scheme.onPrimary, size: AppSpacing.iconMd),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your Wrapped',
                      style: textTheme.titleSmall
                          ?.copyWith(color: scheme.onSurface)),
                  Text('Your productivity highlights',
                      style: textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// ── Section Label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: textTheme.labelSmall?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Divider(color: scheme.outlineVariant, height: 1)),
      ],
    );
  }
}
