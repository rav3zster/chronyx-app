import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/constants/app_strings.dart';
import 'package:chronyx/core/routing/app_routes.dart';
import 'package:chronyx/core/widgets/glass_card.dart';
import 'package:chronyx/core/widgets/error_card.dart';
import 'package:chronyx/core/widgets/settings_icon_button.dart';
import 'package:chronyx/features/analytics/presentation/providers/analytics_providers.dart';
import 'package:chronyx/features/auth/presentation/providers/auth_provider.dart';
import 'package:chronyx/features/time_tracking/presentation/providers/time_tracking_providers.dart';
import 'package:chronyx/features/time_tracking/domain/entities/time_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final timeState = ref.watch(timeEntriesProvider);
    final analyticsState = ref.watch(analyticsProvider);
    final focusStats = ref.watch(focusStatsProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.dashboardTitle),
        actions: [
          const SettingsIconButton(),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: authState.when(
        data: (user) {
          return ListView(
            padding: EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.md,
              top: AppSpacing.sm,
              // Extra bottom padding so content isn't hidden behind nav bar
              bottom: AppSpacing.xxxl + AppSpacing.lg,
            ),
            children: <Widget>[
              // ── Greeting Card ───────────────────────────────────────────
              GlassCard(
                useBlur: false,
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [scheme.primary, scheme.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        color: scheme.onPrimary,
                        size: AppSpacing.iconLg,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.dashboardGreeting,
                            style: textTheme.titleMedium?.copyWith(
                              color: scheme.onSurface,
                            ),
                          ),
                          if (user?.email != null)
                            Text(
                              user!.email!,
                              style: textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── Active Session ─────────────────────────────────────────
              _SectionLabel(label: 'Active Session'),
              const SizedBox(height: AppSpacing.sm),
              timeState.when(
                data: (entries) {
                  TimeEntry? active;
                  for (final e in entries) {
                    if (e.isActive) {
                      active = e;
                      break;
                    }
                  }
                  if (active != null) {
                    final activeId = active.id;
                    return GlassCard(
                      useBlur: false,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.15),
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusSm),
                            ),
                            child: Icon(
                              Icons.timer_rounded,
                              color: scheme.primary,
                              size: AppSpacing.iconLg,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  active.taskName.isEmpty
                                      ? 'Unnamed session'
                                      : active.taskName,
                                  style: textTheme.titleSmall?.copyWith(
                                    color: scheme.onSurface,
                                  ),
                                ),
                                Text(
                                  'Started ${_formatTime(active.startedAt)}',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xs,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: timeState.isLoading
                                ? null
                                : () => ref
                                    .read(timeEntriesProvider.notifier)
                                    .stopSession(sessionId: activeId),
                            child: const Text('Stop'),
                          ),
                        ],
                      ),
                    );
                  }
                  return GlassCard(
                    useBlur: false,
                    child: Column(
                      children: [
                        Icon(
                          Icons.timer_off_outlined,
                          size: AppSpacing.iconXl,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'No active session',
                          style: textTheme.titleSmall?.copyWith(
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Start tracking time to see insights',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => ErrorCard(
                  message: err.toString(),
                  onRetry: () =>
                      ref.read(timeEntriesProvider.notifier).refreshEntries(),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── Today's Stats ─────────────────────────────────────────────
              _SectionLabel(label: "Today's Overview"),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: GlassCard(
                      useBlur: false,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.sm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.today_rounded,
                              color: scheme.primary, size: AppSpacing.iconSm),
                          const SizedBox(height: 4),
                          Text(
                            analyticsState.valueOrNull != null
                                ? '${(analyticsState.valueOrNull!.totalMinutesDaily / 60).toStringAsFixed(1)}h'
                                : '—',
                            style: textTheme.titleSmall?.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text('Today',
                              style: textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: GlassCard(
                      useBlur: false,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.sm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.insights_rounded,
                              color: const Color(0xFF818CF8),
                              size: AppSpacing.iconSm),
                          const SizedBox(height: 4),
                          Text(
                            analyticsState.valueOrNull != null
                                ? '${analyticsState.valueOrNull!.productivityScore.toStringAsFixed(0)}%'
                                : '—',
                            style: textTheme.titleSmall?.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text('Score',
                              style: textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: GlassCard(
                      useBlur: false,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.sm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.center_focus_strong_rounded,
                              color: const Color(0xFF22D3A6),
                              size: AppSpacing.iconSm),
                          const SizedBox(height: 4),
                          Text(
                            '${(focusStats.focusRatio * 100).toStringAsFixed(0)}%',
                            style: textTheme.titleSmall?.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text('Focus',
                              style: textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── Quick Actions ──────────────────────────────────────────
              _SectionLabel(label: 'Quick Actions'),
              const SizedBox(height: AppSpacing.sm),
              _QuickActionGrid(
                actions: [
                  _QuickAction(
                    icon: Icons.timer_outlined,
                    label: 'Time Tracking',
                    color: scheme.primary,
                    onTap: () => context.go(AppRoutes.timeTracking),
                  ),
                  _QuickAction(
                    icon: Icons.insights_rounded,
                    label: 'Analytics',
                    color: scheme.secondary,
                    onTap: () => context.go(AppRoutes.analytics),
                  ),
                  _QuickAction(
                    icon: Icons.flag_rounded,
                    label: 'Goals',
                    color: scheme.tertiary,
                    onTap: () => context.go(AppRoutes.goals),
                  ),
                  _QuickAction(
                    icon: Icons.smart_toy_rounded,
                    label: 'AI Coach',
                    color: const Color(0xFF22D3A6),
                    onTap: () => context.go(AppRoutes.aiCoach),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Sign Out ──────────────────────────────────────────────
              OutlinedButton.icon(
                onPressed: authState.isLoading
                    ? null
                    : () => ref.read(authProvider.notifier).signOut(),
                icon: const Icon(Icons.logout_rounded, size: AppSpacing.iconMd),
                label: const Text(AppStrings.signOut),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorCard(
          message: err.toString(),
          onRetry: () => ref.read(authProvider.notifier).getCurrentUser(),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ── Supporting Widgets ────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _QuickAction {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

class _QuickActionGrid extends StatelessWidget {
  const _QuickActionGrid({required this.actions});
  final List<_QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisExtent: 90,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final a = actions[index];
        return _QuickActionCard(action: a);
      },
    );
  }
}

class _QuickActionCard extends StatefulWidget {
  const _QuickActionCard({required this.action});
  final _QuickAction action;

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1, end: 0.95).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final a = widget.action;

    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        a.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: scheme.outlineVariant, width: 1),
          ),
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: a.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(a.icon, color: a.color, size: AppSpacing.iconMd),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                a.label,
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
