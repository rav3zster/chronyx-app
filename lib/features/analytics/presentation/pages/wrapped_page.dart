import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/widgets/glass_card.dart';
import 'package:chronyx/features/analytics/presentation/providers/analytics_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WrappedPage extends ConsumerWidget {
  const WrappedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(analyticsProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Your Wrapped')),
      body: state.when(
        data: (s) {
          if (s == null) {
            return const Center(child: Text('No data yet.'));
          }

          final topTask = s.topTasks.isNotEmpty ? s.topTasks.first.key : '—';
          final totalWeekHrs = (s.totalMinutesWeekly / 60);
          final totalMonthHrs = (s.totalMinutesMonthly / 60);
          final score = s.productivityScore;
          final scoreColor = score >= 70
              ? const Color(0xFF22D3A6)
              : score >= 40
                  ? scheme.primary
                  : scheme.error;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xxxl,
            ),
            children: [
              // Hero banner
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      scheme.primary.withValues(alpha: 0.8),
                      scheme.secondary.withValues(alpha: 0.6),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusXxl),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('✨', style: TextStyle(fontSize: 36)),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Your Productivity\nHighlights',
                      style: textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Keep pushing your limits.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Big numbers
              Row(
                children: [
                  Expanded(
                    child: _BigStat(
                      value: totalWeekHrs.toStringAsFixed(1),
                      unit: 'hrs',
                      label: 'This Week',
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _BigStat(
                      value: totalMonthHrs.toStringAsFixed(1),
                      unit: 'hrs',
                      label: 'This Month',
                      color: const Color(0xFF818CF8),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.sm),

              Row(
                children: [
                  Expanded(
                    child: _BigStat(
                      value: score.toStringAsFixed(0),
                      unit: '%',
                      label: 'Productivity Score',
                      color: scoreColor,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _BigStat(
                      value: s.peakHour.toString(),
                      unit: ':00',
                      label: 'Peak Hour',
                      color: const Color(0xFFFBBC05),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // Top task highlight
              GlassCard(
                useBlur: false,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOP TASK THIS WEEK',
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      topTask,
                      style: textTheme.titleLarge?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (s.topTasks.isNotEmpty)
                      Text(
                        '${(s.topTasks.first.value / 60).toStringAsFixed(1)}h tracked',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Category breakdown
              if (s.categoryBreakdown.isNotEmpty) ...[
                GlassCard(
                  useBlur: false,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TIME DISTRIBUTION',
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _CategoryPieRow(breakdown: s.categoryBreakdown),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Most active day
              GlassCard(
                useBlur: false,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBBC05).withValues(alpha: 0.15),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: const Icon(
                        Icons.local_fire_department_rounded,
                        color: Color(0xFFFBBC05),
                        size: AppSpacing.iconLg,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Most Active Day',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          s.mostActiveDay,
                          style: textTheme.titleMedium?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Goal success
              if (s.goalPerformance['total'] as int > 0)
                GlassCard(
                  useBlur: false,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22D3A6).withValues(alpha: 0.15),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                        child: const Icon(
                          Icons.emoji_events_rounded,
                          color: Color(0xFF22D3A6),
                          size: AppSpacing.iconLg,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Goal Success Rate',
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '${(s.goalPerformance['successRate'] as double).toStringAsFixed(0)}% · ${s.goalPerformance['succeeded']}/${s.goalPerformance['total']} goals',
                            style: textTheme.titleMedium?.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
        error: (err, _) => Center(child: Text(err.toString())),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({
    required this.value,
    required this.unit,
    required this.label,
    required this.color,
  });
  final String value;
  final String unit;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GlassCard(
      useBlur: false,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: textTheme.headlineMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                unit,
                style: textTheme.titleSmall?.copyWith(
                  color: color.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPieRow extends StatelessWidget {
  const _CategoryPieRow({required this.breakdown});
  final Map<String, int> breakdown;

  static const Map<String, Color> _colors = {
    'productive': Color(0xFF22D3A6),
    'learning': Color(0xFF818CF8),
    'break': Color(0xFFFBBC05),
    'distraction': Color(0xFFEA4335),
    'other': Color(0xFF94A3B8),
  };

  static const Map<String, String> _labels = {
    'productive': '🚀 Productive',
    'learning': '📚 Learning',
    'break': '☕ Break',
    'distraction': '🌀 Distraction',
    'other': '📌 Other',
  };

  @override
  Widget build(BuildContext context) {
    final total = breakdown.values.fold(0, (a, b) => a + b);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: breakdown.entries.map((e) {
        final color = _colors[e.key] ?? const Color(0xFF94A3B8);
        final label = _labels[e.key] ?? e.key;
        final pct = total == 0 ? 0.0 : e.value / total;

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  label,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusFull),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: scheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${(pct * 100).toStringAsFixed(0)}%',
                style: textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
