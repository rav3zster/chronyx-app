import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/errors/error_message_mapper.dart';
import 'package:chronyx/features/analytics/presentation/providers/analytics_providers.dart';
import 'package:chronyx/core/widgets/glass_card.dart';
import 'package:chronyx/core/widgets/error_card.dart';
import 'package:chronyx/core/widgets/empty_state.dart';
import 'package:chronyx/core/widgets/settings_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:chronyx/core/routing/app_routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(analyticsProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: const [
          SettingsIconButton(),
          SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: state.when(
          data: (summary) {
            if (summary == null) {
              return EmptyState(
                icon: Icons.analytics_outlined,
                title: 'No analytics yet',
                subtitle: 'Start tracking time to generate insights',
                ctaLabel: 'Open Time Tracking',
                onCta: () => context.go(AppRoutes.timeTracking),
              );
            }
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: ListView(
                key: const ValueKey('analytics_list'),
                padding: const EdgeInsets.only(
                  bottom: AppSpacing.xxxl + AppSpacing.lg,
                ),
                children: <Widget>[
                  _StatCard(
                    icon: Icons.today_rounded,
                    iconColor: scheme.primary,
                    title: 'Total Today',
                    value:
                        '${(summary.totalMinutesDaily / 60).toStringAsFixed(1)} hrs',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _StatCard(
                    icon: Icons.workspace_premium_rounded,
                    iconColor: scheme.secondary,
                    title: 'Top Task',
                    value: summary.topTasks.isEmpty
                        ? '—'
                        : '${summary.topTasks.first.key} • ${(summary.topTasks.first.value / 60).toStringAsFixed(1)} hrs',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _StatCard(
                    icon: Icons.calendar_today_rounded,
                    iconColor: scheme.tertiary,
                    title: 'Most Active Day',
                    value: summary.mostActiveDay,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  GlassCard(
                    useBlur: false,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    child: InkWell(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusLg),
                      onTap: () => context.push(AppRoutes.wrapped),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding:
                                  const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    scheme.primary,
                                    scheme.secondary,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusSm),
                              ),
                              child: Icon(
                                Icons.auto_awesome_rounded,
                                color: scheme.onPrimary,
                                size: AppSpacing.iconMd,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Open Wrapped',
                                    style: textTheme.titleSmall?.copyWith(
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                  Text(
                                    'Your productivity highlights',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: scheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          error: (err, _) => ErrorCard(
            message: ErrorMessageMapper.fromError(err),
            onRetry: () => ref.read(analyticsProvider.notifier).refresh(),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GlassCard(
      useBlur: false,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(icon, color: iconColor, size: AppSpacing.iconLg),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: textTheme.titleMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
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
