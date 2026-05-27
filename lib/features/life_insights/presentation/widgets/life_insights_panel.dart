import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/theme/design_tokens.dart';
import 'package:chronyx/core/widgets/scene_card.dart';
import 'package:chronyx/core/widgets/section_header.dart';
import 'package:chronyx/features/life_insights/domain/entities/focus_pattern.dart';
import 'package:chronyx/features/life_insights/domain/entities/life_snapshot.dart';
import 'package:chronyx/features/life_insights/domain/entities/time_allocation.dart';
import 'package:chronyx/features/life_insights/presentation/providers/life_insights_providers.dart';
import 'package:chronyx/features/life_insights/presentation/widgets/allocation_donut.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Premium "Life in Motion" insights panel for the dashboard.
///
/// Renders an allocation donut, dominant focus highlight, neglected area,
/// and a focus rhythm timeline — all driven by [lifeSnapshotProvider].
class LifeInsightsPanel extends ConsumerWidget {
  const LifeInsightsPanel({super.key, this.onTap});

  /// Tapping the panel opens the full insights screen (Phase 2).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(lifeSnapshotProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          eyebrow: 'Intelligence',
          title: 'Your life in motion',
        ),
        snapshotAsync.when(
          loading: () => const _LoadingPanel(),
          error: (_, _) => _EmptyPanel(onTap: onTap),
          data: (snapshot) {
            if (!snapshot.hasEnoughData) {
              return _EmptyPanel(onTap: onTap);
            }
            return _PanelBody(snapshot: snapshot, onTap: onTap);
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Body
// ─────────────────────────────────────────────────────────────────────────────

class _PanelBody extends StatelessWidget {
  const _PanelBody({required this.snapshot, this.onTap});

  final LifeSnapshot snapshot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SceneCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Headline + donut ─────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AllocationDonut(
                allocation: snapshot.allocation,
                size: 110,
                strokeWidth: 13,
                centerChild: _DonutCenter(allocation: snapshot.allocation),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'THIS WEEK',
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      snapshot.smartHeadline,
                      style: textTheme.titleMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _windowSummary(snapshot.allocation),
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Slice legend (compact, top 3) ────────────────────────────
          _Legend(allocation: snapshot.allocation),

          const SizedBox(height: AppSpacing.md),

          Divider(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
            height: 1,
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Focus rhythm timeline ────────────────────────────────────
          _RhythmTimeline(pattern: snapshot.focusPattern),

          // ── Neglected area (only if exists) ──────────────────────────
          if (snapshot.neglected != null) ...[
            const SizedBox(height: AppSpacing.md),
            _NeglectedRow(neglected: snapshot.neglected!),
          ],
        ],
      ),
    );
  }

  String _windowSummary(TimeAllocation a) {
    final hours = a.totalMinutes / 60;
    final hStr = hours >= 10
        ? hours.toStringAsFixed(0)
        : hours.toStringAsFixed(1);
    return 'Tracked ${hStr}h across ${a.windowDays} days';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Donut center: total hours
// ─────────────────────────────────────────────────────────────────────────────

class _DonutCenter extends StatelessWidget {
  const _DonutCenter({required this.allocation});
  final TimeAllocation allocation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hours = allocation.totalMinutes / 60;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          hours >= 10 ? hours.toStringAsFixed(0) : hours.toStringAsFixed(1),
          style: textTheme.titleLarge?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w800,
            height: 1.0,
            letterSpacing: -0.5,
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Legend: top 3 categories with colored dot + percent
// ─────────────────────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  const _Legend({required this.allocation});
  final TimeAllocation allocation;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final top = allocation.sorted.take(3).toList();
    if (top.isEmpty) return const SizedBox.shrink();

    return Row(
      children: top.map((slice) {
        final pct = (allocation.percentageOf(slice) * 100).round();
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: slice.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: slice.color.withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$pct%',
                        style: textTheme.labelLarge?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        slice.label,
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rhythm timeline: morning / afternoon / evening / night bars
// ─────────────────────────────────────────────────────────────────────────────

class _RhythmTimeline extends StatelessWidget {
  const _RhythmTimeline({required this.pattern});
  final FocusPattern pattern;

  @override
  Widget build(BuildContext context) {
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
        Row(
          children: [
            Icon(Icons.bolt_rounded, size: 14, color: DesignTokens.accentEmber),
            const SizedBox(width: 4),
            Text(
              'You focus best in the ${pattern.peakPeriod.label.toLowerCase()}',
              style: textTheme.labelMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: periods.map((period) {
            final mins = pattern.minutesByPeriod[period] ?? 0;
            final ratio = maxMinutes == 0 ? 0.0 : mins / maxMinutes;
            final isPeak = period == pattern.peakPeriod && mins > 0;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      height: 32,
                      alignment: Alignment.bottomCenter,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: ratio),
                        duration: DesignTokens.motionSlow,
                        curve: DesignTokens.easeOut,
                        builder: (context, value, _) {
                          return Container(
                            height: 4 + value * 28,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: isPeak
                                    ? [
                                        DesignTokens.accentEmber,
                                        DesignTokens.accentEmber.withValues(
                                          alpha: 0.5,
                                        ),
                                      ]
                                    : [
                                        scheme.primary.withValues(alpha: 0.7),
                                        scheme.primary.withValues(alpha: 0.25),
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      period.label,
                      style: textTheme.labelSmall?.copyWith(
                        color: isPeak
                            ? DesignTokens.accentEmber
                            : scheme.onSurfaceVariant,
                        fontSize: 9,
                        fontWeight: isPeak ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Neglected area: gentle nudge
// ─────────────────────────────────────────────────────────────────────────────

class _NeglectedRow extends StatelessWidget {
  const _NeglectedRow({required this.neglected});
  final NeglectedArea neglected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final color = DesignTokens.accentRose;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                children: [
                  const TextSpan(text: 'No activity on '),
                  TextSpan(
                    text: neglected.label,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text:
                        ' in ${neglected.daysSinceActivity} day${neglected.daysSinceActivity == 1 ? '' : 's'}.',
                  ),
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
// Loading + Empty states
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SceneCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      onTap: onTap,
      glow: scheme.primary,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  scheme.primary.withValues(alpha: 0.30),
                  scheme.primary.withValues(alpha: 0.0),
                ],
              ),
            ),
            child: Icon(
              Icons.auto_graph_rounded,
              size: 28,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your story starts here',
                  style: textTheme.titleSmall?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Track your first session to unlock life insights.',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right_rounded, color: scheme.primary, size: 24),
        ],
      ),
    );
  }
}
