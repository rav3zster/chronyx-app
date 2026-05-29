import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/errors/error_message_mapper.dart';
import 'package:chronyx/core/theme/design_tokens.dart';
import 'package:chronyx/core/theme/scheme_x.dart';
import 'package:chronyx/core/widgets/scene_card.dart';
import 'package:chronyx/core/widgets/section_header.dart';
import 'package:chronyx/core/widgets/state_view.dart';
import 'package:chronyx/features/life_insights/domain/entities/focus_pattern.dart';
import 'package:chronyx/features/life_insights/domain/entities/life_report.dart';
import 'package:chronyx/features/life_insights/domain/entities/mood.dart';
import 'package:chronyx/features/life_insights/presentation/providers/life_insights_providers.dart';
import 'package:chronyx/features/life_insights/presentation/widgets/allocation_donut.dart';
import 'package:chronyx/features/life_insights/presentation/widgets/balance_section.dart';
import 'package:chronyx/features/life_insights/presentation/widgets/fade_slide_in.dart';
import 'package:chronyx/features/life_insights/presentation/widgets/micro_wrapped.dart';
import 'package:chronyx/features/life_insights/presentation/widgets/weekly_wins.dart';
import 'package:chronyx/features/life_insights/presentation/widgets/window_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LifeInsightsPage extends ConsumerWidget {
  const LifeInsightsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(lifeReportProvider);
    final scheme = Theme.of(context).colorScheme;
    final mood = reportAsync.valueOrNull?.mood ?? InsightMood.steady;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
          Positioned.fill(child: _Backdrop(mood: mood)),
          SafeArea(
            child: reportAsync.when(
              loading: () => const _LoadingView(),
              error: (err, _) => StateView.error(
                message: ErrorMessageMapper.fromError(err),
                onRetry: () => ref.invalidate(lifeReportProvider),
              ),
              data: (report) => _ReportContent(report: report),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mood-driven ambient backdrop
// ─────────────────────────────────────────────────────────────────────────────

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.mood});
  final InsightMood mood;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -1.1),
            radius: 1.4,
            colors: [
              scheme.primary.withValues(alpha: 0.22),
              scheme.secondary.withValues(alpha: 0.10),
              Colors.transparent,
            ],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Report content
// ─────────────────────────────────────────────────────────────────────────────

class _ReportContent extends ConsumerWidget {
  const _ReportContent({required this.report});
  final LifeReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Build section list as widgets so we can apply staggered fade-ins
    // and reorder without rewriting sliver wiring.
    final sections = <Widget>[
      _HeroInsight(report: report),
      _WinsBlock(report: report),
      _Distribution(report: report),
      _BalanceBlock(report: report),
      _LifeBreakdown(report: report),
      _MicroWrappedBlock(report: report),
      _BehaviorSection(report: report),
      _DailyTimeline(report: report),
      _WeeklyReflection(report: report),
      _Predictions(report: report),
    ];

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            0,
          ),
          sliver: SliverToBoxAdapter(child: _TopBar()),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: WindowSwitcher(
              value: report.window,
              onChanged: (w) => ref.read(lifeWindowProvider.notifier).state = w,
            ),
          ),
        ),
        for (var i = 0; i < sections.length; i++)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              i == 0 ? AppSpacing.lg : AppSpacing.xl,
              AppSpacing.md,
              i == sections.length - 1 ? AppSpacing.xxl : 0,
            ),
            sliver: SliverToBoxAdapter(
              child: FadeSlideIn(
                delay: Duration(milliseconds: 60 * i),
                child: sections[i],
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Wrapper blocks for sections that should disappear entirely when empty
// ─────────────────────────────────────────────────────────────────────────────

class _WinsBlock extends StatelessWidget {
  const _WinsBlock({required this.report});
  final LifeReport report;

  @override
  Widget build(BuildContext context) {
    if (report.wins.isEmpty) return const SizedBox.shrink();
    return WeeklyWinsRow(wins: report.wins);
  }
}

class _BalanceBlock extends StatelessWidget {
  const _BalanceBlock({required this.report});
  final LifeReport report;

  @override
  Widget build(BuildContext context) {
    if (!report.hasEnoughData) return const SizedBox.shrink();
    return BalanceSection(balance: report.balance);
  }
}

class _MicroWrappedBlock extends StatelessWidget {
  const _MicroWrappedBlock({required this.report});
  final LifeReport report;

  @override
  Widget build(BuildContext context) {
    if (!report.hasEnoughData) return const SizedBox.shrink();
    return MicroWrapped(report: report);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top bar
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
          color: scheme.onSurface,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'INTELLIGENCE',
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  fontSize: 10,
                ),
              ),
              Text(
                'Your life in motion',
                style: textTheme.titleLarge?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION 1 — Hero Insight
// ─────────────────────────────────────────────────────────────────────────────

class _HeroInsight extends StatelessWidget {
  const _HeroInsight({required this.report});
  final LifeReport report;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hours = report.allocation.totalMinutes / 60;
    final hoursStr = hours >= 10
        ? hours.toStringAsFixed(0)
        : hours.toStringAsFixed(1);
    final consistency = report.reflection.consistencyPercent.round();
    final momentum = report.reflection.momentum;
    final mood = report.mood;

    // Accent derives from the active theme so the card matches whatever
    // palette is selected (gold in Warm, indigo in Cosmic Dark, …).
    final accent = scheme.primary;

    final momentumColor = switch (momentum) {
      TrendDirection.up => DesignTokens.accentMint,
      TrendDirection.down => scheme.error,
      TrendDirection.flat => scheme.onSurfaceVariant,
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(
                  'THIS ${report.window.label.toUpperCase()}',
                  style: textTheme.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    fontSize: 10,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Text(mood.glyph, style: const TextStyle(fontSize: 18)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Emotional headline — the WOW line.
          Text(
            report.heroEmotion,
            style: textTheme.headlineSmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              height: 1.12,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            report.snapshot.smartHeadline,
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Stats row with subtle dividers
          Row(
            children: [
              Expanded(
                child: _HeroStat(
                  label: 'TRACKED',
                  value: '${hoursStr}h',
                  accent: accent,
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
              Expanded(
                child: _HeroStat(
                  label: 'CONSISTENCY',
                  value: '$consistency%',
                  accent: DesignTokens.accentMint,
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
              Expanded(
                child: _HeroStat(
                  label: 'MOMENTUM',
                  value: momentum.arrow,
                  accent: momentumColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: textTheme.titleLarge?.copyWith(
            color: accent,
            fontWeight: FontWeight.w800,
            height: 1.0,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            letterSpacing: 1.2,
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION 2 — Time Distribution (donut + legend)
// ─────────────────────────────────────────────────────────────────────────────

class _Distribution extends StatelessWidget {
  const _Distribution({required this.report});
  final LifeReport report;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final allocation = report.allocation;

    if (!report.hasEnoughData) {
      return const _EmptySection(
        eyebrow: 'Distribution',
        title: 'Time distribution',
        message: 'Track sessions to see how your time is spent.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          eyebrow: 'Distribution',
          title: 'Time distribution',
        ),
        SceneCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AllocationDonut(
                    allocation: allocation,
                    size: 130,
                    strokeWidth: 14,
                    centerChild: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          (allocation.totalMinutes / 60).toStringAsFixed(1),
                          style: textTheme.headlineSmall?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            height: 1.0,
                          ),
                        ),
                        Text(
                          'hours',
                          style: textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: allocation.sorted.take(5).map((slice) {
                        final pct = (allocation.percentageOf(slice) * 100)
                            .round();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: slice.color,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: slice.color.withValues(alpha: 0.6),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  slice.label,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurface,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '$pct%',
                                style: textTheme.labelMedium?.copyWith(
                                  color: slice.color,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION 3 — Life Breakdown (top items + neglected)
// ─────────────────────────────────────────────────────────────────────────────

class _LifeBreakdown extends StatelessWidget {
  const _LifeBreakdown({required this.report});
  final LifeReport report;

  @override
  Widget build(BuildContext context) {
    final items = report.topItems;
    final neglected = report.snapshot.neglected;
    if (items.isEmpty && neglected == null) {
      return const _EmptySection(
        eyebrow: 'Life',
        title: 'Where time went',
        message: 'No tracked items in this window yet.',
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final maxMinutes = items.isEmpty ? 1 : items.first.minutes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(eyebrow: 'Life', title: 'Where time went'),
        SceneCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in items) ...[
                _BreakdownRow(item: item, ratio: item.minutes / maxMinutes),
                if (item != items.last) const SizedBox(height: 10),
              ],
              if (neglected != null) ...[
                const SizedBox(height: AppSpacing.md),
                Divider(
                  color: scheme.outlineVariant.withValues(alpha: 0.4),
                  height: 1,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: DesignTokens.accentRose.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.priority_high_rounded,
                        size: 16,
                        color: DesignTokens.accentRose,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Neglected: ${neglected.label}',
                            style: textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'No activity in ${neglected.daysSinceActivity} day${neglected.daysSinceActivity == 1 ? '' : 's'}.',
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.item, required this.ratio});
  final TopItem item;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hours = item.hours;
    final minutes = item.minutes;
    final timeStr = hours >= 1 ? '${hours.toStringAsFixed(1)}h' : '${minutes}m';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (item.subtitle != null) ...[
              Text(item.subtitle!, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                item.label,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              timeStr,
              style: textTheme.labelMedium?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: ratio.clamp(0.0, 1.0)),
            duration: DesignTokens.motionSlow,
            curve: DesignTokens.easeOut,
            builder: (context, value, _) {
              return LinearProgressIndicator(
                value: value,
                minHeight: 5,
                backgroundColor: scheme.surfaceContainerHighest.withValues(
                  alpha: 0.6,
                ),
                valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION 4 — Behavior patterns
// ─────────────────────────────────────────────────────────────────────────────

class _BehaviorSection extends StatelessWidget {
  const _BehaviorSection({required this.report});
  final LifeReport report;

  @override
  Widget build(BuildContext context) {
    final behaviors = report.behaviors;
    if (behaviors.isEmpty) {
      return const _EmptySection(
        eyebrow: 'Patterns',
        title: 'How you work',
        message: 'Behavioral patterns appear after a few sessions.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(eyebrow: 'Patterns', title: 'How you work'),
        for (final insight in behaviors) ...[
          _InsightCard(
            title: insight.title,
            detail: insight.detail,
            tone: insight.tone,
            icon: switch (insight.id) {
              'peak_period' => Icons.bolt_rounded,
              'strongest_day' => Icons.calendar_today_rounded,
              'session_length' => Icons.access_time_rounded,
              'momentum' => Icons.trending_up_rounded,
              'consistency' => Icons.show_chart_rounded,
              _ => Icons.lightbulb_outline_rounded,
            },
          ),
          if (insight != behaviors.last) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION 5 — Daily timeline (period bars)
// ─────────────────────────────────────────────────────────────────────────────

class _DailyTimeline extends StatelessWidget {
  const _DailyTimeline({required this.report});
  final LifeReport report;

  @override
  Widget build(BuildContext context) {
    final pattern = report.focusPattern;
    if (pattern.totalMinutes == 0) {
      return const _EmptySection(
        eyebrow: 'Rhythm',
        title: 'Daily timeline',
        message: 'Your daily rhythm appears as you track sessions.',
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final periods = LifePeriod.values;
    final maxMinutes = pattern.minutesByPeriod.values.fold<int>(
      0,
      (m, v) => v > m ? v : m,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(eyebrow: 'Rhythm', title: 'Daily timeline'),
        SceneCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final period in periods)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PeriodBar(
                    period: period,
                    minutes: pattern.minutesByPeriod[period] ?? 0,
                    ratio: maxMinutes == 0
                        ? 0
                        : (pattern.minutesByPeriod[period] ?? 0) / maxMinutes,
                    isPeak: period == pattern.peakPeriod,
                  ),
                ),
              const SizedBox(height: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm + 2,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Peak hour: ${_formatHour(pattern.peakHour)}',
                      style: textTheme.labelMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatHour(int hour) {
    final suffix = hour < 12 ? 'AM' : 'PM';
    final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$h:00 $suffix';
  }
}

class _PeriodBar extends StatelessWidget {
  const _PeriodBar({
    required this.period,
    required this.minutes,
    required this.ratio,
    required this.isPeak,
  });

  final LifePeriod period;
  final int minutes;
  final double ratio;
  final bool isPeak;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final accent = isPeak ? DesignTokens.accentEmber : scheme.primary;

    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                period.label,
                style: textTheme.bodySmall?.copyWith(
                  color: isPeak ? accent : scheme.onSurface,
                  fontWeight: isPeak ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              Text(
                period.range,
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: ratio.clamp(0.0, 1.0)),
                duration: DesignTokens.motionSlow,
                curve: DesignTokens.easeOut,
                builder: (context, value, _) {
                  return FractionallySizedBox(
                    widthFactor: value,
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            accent.withValues(alpha: 0.9),
                            accent.withValues(alpha: 0.55),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusFull,
                        ),
                        boxShadow: isPeak
                            ? [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 44,
          child: Text(
            '${(minutes / 60).toStringAsFixed(1)}h',
            textAlign: TextAlign.right,
            style: textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION 6 — Weekly Reflection (Wrapped feel)
// ─────────────────────────────────────────────────────────────────────────────

class _WeeklyReflection extends StatelessWidget {
  const _WeeklyReflection({required this.report});
  final LifeReport report;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final r = report.reflection;

    if (!report.hasEnoughData) {
      return const _EmptySection(
        eyebrow: 'Reflection',
        title: 'Your ${''} story',
        message: 'A summary appears once you start tracking.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          eyebrow: 'Reflection',
          title: '${report.window.label} in review',
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
            gradient: LinearGradient(
              colors: [
                scheme.secondary.withValues(alpha: 0.18),
                scheme.tertiary.withValues(alpha: 0.10),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ReflectionRow(
                label: 'Focused',
                value: r.focusedFormatted,
                icon: Icons.timer_outlined,
              ),
              _ReflectionRow(
                label: 'Top activity',
                value: r.topActivityLabel,
                icon: Icons.local_fire_department_outlined,
              ),
              _ReflectionRow(
                label: 'Peak hour',
                value: _formatHour(r.peakHour),
                icon: Icons.bolt_outlined,
              ),
              _ReflectionRow(
                label: 'Consistency',
                value: '${r.consistencyPercent.round()}%',
                icon: Icons.insights_outlined,
              ),
              _ReflectionRow(
                label: 'Momentum',
                value: switch (r.momentum) {
                  TrendDirection.up => 'Improving',
                  TrendDirection.down => 'Slowing',
                  TrendDirection.flat => 'Steady',
                },
                icon: switch (r.momentum) {
                  TrendDirection.up => Icons.trending_up_rounded,
                  TrendDirection.down => Icons.trending_down_rounded,
                  TrendDirection.flat => Icons.trending_flat_rounded,
                },
                isLast: true,
              ),
              const SizedBox(height: AppSpacing.md),
              _MiniSparkline(points: r.dailyMinutes),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Daily focus across ${report.window.days} days',
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatHour(int hour) {
    final suffix = hour < 12 ? 'AM' : 'PM';
    final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$h:00 $suffix';
  }
}

class _ReflectionRow extends StatelessWidget {
  const _ReflectionRow({
    required this.label,
    required this.value,
    required this.icon,
    this.isLast = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: textTheme.titleSmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniSparkline extends StatelessWidget {
  const _MiniSparkline({required this.points});
  final List<TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    if (points.isEmpty) return const SizedBox.shrink();
    final maxValue = points
        .map((p) => p.value)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final showLabels = points.length <= 14;

    return SizedBox(
      height: 56,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < points.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin: 0,
                        end: maxValue == 0 ? 0 : points[i].value / maxValue,
                      ),
                      duration: DesignTokens.motionSlow,
                      curve: DesignTokens.easeOut,
                      builder: (context, value, _) {
                        return Container(
                          height: 4 + value * 36,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [scheme.primary, scheme.secondary],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                              bottom: Radius.circular(2),
                            ),
                          ),
                        );
                      },
                    ),
                    if (showLabels) ...[
                      const SizedBox(height: 4),
                      Text(
                        points[i].label[0],
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION 7 — Predictions
// ─────────────────────────────────────────────────────────────────────────────

class _Predictions extends StatelessWidget {
  const _Predictions({required this.report});
  final LifeReport report;

  @override
  Widget build(BuildContext context) {
    if (report.predictions.isEmpty) {
      return const _EmptySection(
        eyebrow: 'Forecast',
        title: 'Predictions',
        message:
            'Complete more tasks and track sessions to unlock predictions.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(eyebrow: 'Forecast', title: 'Predictions'),
        for (final p in report.predictions) ...[
          _InsightCard(
            title: p.text,
            tone: p.tone,
            icon: switch (p.tone) {
              InsightTone.positive => Icons.auto_awesome_rounded,
              InsightTone.warning => Icons.warning_amber_rounded,
              InsightTone.neutral => Icons.insights_rounded,
            },
          ),
          if (p != report.predictions.last)
            const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable insight card
// ─────────────────────────────────────────────────────────────────────────────

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.title,
    required this.tone,
    required this.icon,
    this.detail,
  });

  final String title;
  final String? detail;
  final InsightTone tone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final accent = switch (tone) {
      InsightTone.positive => DesignTokens.accentMint,
      InsightTone.warning => DesignTokens.accentEmber,
      InsightTone.neutral => scheme.primary,
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    detail!,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty section + loading
// ─────────────────────────────────────────────────────────────────────────────

class _EmptySection extends StatelessWidget {
  const _EmptySection({
    required this.eyebrow,
    required this.title,
    required this.message,
  });

  final String eyebrow;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(eyebrow: eyebrow, title: title),
        SceneCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(
                Icons.bubble_chart_rounded,
                size: 22,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Text(
                  message,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHighest.withValues(alpha: 0.4);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Container(height: 22, width: 200, color: base),
        const SizedBox(height: AppSpacing.lg),
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          ),
        ),
      ],
    );
  }
}
