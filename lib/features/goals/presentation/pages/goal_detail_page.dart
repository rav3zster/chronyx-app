import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/widgets/glass_card.dart';
import 'package:chronyx/features/goals/presentation/providers/goals_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class GoalDetailPage extends ConsumerWidget {
  const GoalDetailPage({required this.goalId, super.key});

  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(goalsProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Goal Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: state.when(
        data: (items) {
          final matches = items.where((g) => g.goal.id == goalId).toList();
          if (matches.isEmpty) {
            return const Center(child: Text('Goal not found.'));
          }
          final p = matches.first;
          final g = p.goal;
          final pct = p.percentCompleted.clamp(0.0, 100.0);
          final color = pct >= 80
              ? const Color(0xFF22D3A6)
              : pct >= 50
                  ? const Color(0xFF818CF8)
                  : pct >= 25
                      ? const Color(0xFFFBBC05)
                      : scheme.error;
          final daysLeft = g.endDate.difference(DateTime.now()).inDays;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xxxl,
            ),
            children: [
              // ── Header ───────────────────────────────────────────────
              GlassCard(
                useBlur: false,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            g.title,
                            style: textTheme.titleLarge?.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (g.isChallenge)
                          const Text('🔥',
                              style: TextStyle(fontSize: 20)),
                      ],
                    ),
                    if (g.description.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        g.description,
                        style: textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    // Big progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                      child: LinearProgressIndicator(
                        value: pct / 100,
                        backgroundColor: scheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 10,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${pct.toStringAsFixed(0)}% complete',
                          style: textTheme.labelMedium?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          daysLeft > 0
                              ? '$daysLeft days left'
                              : daysLeft == 0
                                  ? 'Last day!'
                                  : 'Ended',
                          style: textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // ── Stats Row ────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      icon: Icons.local_fire_department_rounded,
                      color: color,
                      label: 'Streak',
                      value: '${p.currentStreak}d',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _MiniStat(
                      icon: Icons.check_circle_outline_rounded,
                      color: const Color(0xFF22D3A6),
                      label: 'Days Done',
                      value: '${p.daysCompleted}',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _MiniStat(
                      icon: Icons.cancel_outlined,
                      color: scheme.error,
                      label: 'Days Missed',
                      value: '${p.daysMissed}',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),

              // ── Daily Target ─────────────────────────────────────────
              GlassCard(
                useBlur: false,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Icon(Icons.timer_rounded,
                        color: scheme.primary, size: AppSpacing.iconLg),
                    const SizedBox(width: AppSpacing.md),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Daily Target',
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            )),
                        Text(
                          '${g.dailyTargetMinutes} min/day',
                          style: textTheme.titleMedium?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Period',
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            )),
                        Text(
                          '${p.totalDays} days',
                          style: textTheme.titleSmall?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Delete ───────────────────────────────────────────────
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.error,
                  side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
                ),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete Goal'),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Goal?'),
                      content: Text(
                          'Are you sure you want to delete "${g.title}"? This cannot be undone.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel')),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: Text('Delete',
                              style: TextStyle(color: scheme.error)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await ref.read(goalsProvider.notifier).deleteGoal(g.id);
                    if (context.mounted) GoRouter.of(context).pop();
                  }
                },
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text(err.toString())),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
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
            style: textTheme.titleMedium?.copyWith(
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
