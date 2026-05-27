import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/errors/error_message_mapper.dart';
import 'package:chronyx/core/routing/app_routes.dart';
import 'package:chronyx/core/theme/design_tokens.dart';
import 'package:chronyx/core/widgets/metric_tile.dart';
import 'package:chronyx/core/widgets/progress_ring.dart';
import 'package:chronyx/core/widgets/scene_card.dart';
import 'package:chronyx/core/widgets/section_header.dart';
import 'package:chronyx/core/widgets/settings_icon_button.dart';
import 'package:chronyx/features/analytics/presentation/providers/analytics_providers.dart';
import 'package:chronyx/features/auth/presentation/providers/auth_provider.dart';
import 'package:chronyx/features/life_insights/presentation/providers/life_insights_providers.dart';
import 'package:chronyx/features/life_insights/presentation/widgets/life_insights_panel.dart';
import 'package:chronyx/features/project_planner/domain/entities/project_task.dart';
import 'package:chronyx/features/project_planner/presentation/providers/project_planner_providers.dart';
import 'package:chronyx/features/project_planner/presentation/providers/todays_roadmap_provider.dart';
import 'package:chronyx/features/time_tracking/presentation/providers/time_tracking_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    // No nested Scaffold — the shell (in app_router.dart) provides one.
    // Render content directly so the floating bottom nav stays visible.
    return Stack(
      children: [
        const Positioned.fill(child: _AmbientBackdrop()),
        SafeArea(
          bottom: false,
          child: authState.maybeWhen(
            loading: () => const _DashboardSkeleton(),
            error: (err, _) => _DashboardError(
              message: ErrorMessageMapper.fromError(err),
              onRetry: () => ref.read(authProvider.notifier).getCurrentUser(),
            ),
            // Fallback to content for any state (data, loading w/ value, etc.)
            // so we never get a blank screen.
            orElse: () => _DashboardContent(user: authState.valueOrNull),
          ),
        ),
      ],
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.user});
  final dynamic user;

  @override
  Widget build(BuildContext context) {
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
          sliver: SliverToBoxAdapter(child: _GreetingHeader(user: user)),
        ),
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
            0,
          ),
          sliver: SliverToBoxAdapter(child: _HeroFocusCard()),
        ),
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xl,
            AppSpacing.md,
            0,
          ),
          sliver: SliverToBoxAdapter(child: _TodaysMetrics()),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xl,
            AppSpacing.md,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: Builder(
              builder: (context) => LifeInsightsPanel(
                onTap: () => context.push(AppRoutes.lifeInsights),
              ),
            ),
          ),
        ),
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xl,
            AppSpacing.md,
            0,
          ),
          sliver: SliverToBoxAdapter(child: _TodaysRoadmap()),
        ),
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xl,
            AppSpacing.md,
            // Extra bottom padding so floating nav doesn't overlap content.
            120,
          ),
          sliver: SliverToBoxAdapter(child: _RecentProjects()),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ambient backdrop — soft brand-colored radial glow at top
// ─────────────────────────────────────────────────────────────────────────────

class _AmbientBackdrop extends StatelessWidget {
  const _AmbientBackdrop();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.3, -1.1),
            radius: 1.2,
            colors: [
              scheme.primary.withValues(alpha: 0.18),
              scheme.secondary.withValues(alpha: 0.08),
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
// Greeting header
// ─────────────────────────────────────────────────────────────────────────────

class _GreetingHeader extends ConsumerWidget {
  const _GreetingHeader({required this.user});
  final dynamic user;

  String get _fallbackName {
    if (user?.email == null) return 'there';
    final email = user.email as String;
    final local = email.split('@').first;
    return local.isEmpty
        ? 'there'
        : local[0].toUpperCase() + local.substring(1);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final greetingAsync = ref.watch(greetingProvider);

    final greeting = greetingAsync.valueOrNull;
    final salutation = greeting?.salutation ?? _fallbackSalutation();
    final name = greeting?.name ?? _fallbackName;
    final message = greeting?.message ?? "Let's make today count.";
    final glyph = greeting?.glyph ?? '✨';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$salutation, $name',
                  style: textTheme.headlineSmall?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, anim) =>
                      FadeTransition(opacity: anim, child: child),
                  child: Row(
                    key: ValueKey(message),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(glyph, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          message,
                          style: textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SettingsIconButton(),
        ],
      ),
    );
  }

  String _fallbackSalutation() {
    final h = DateTime.now().hour;
    if (h < 5) return 'Late night';
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    if (h < 22) return 'Good evening';
    return 'Late night';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero focus card — today's most important roadmap
// ─────────────────────────────────────────────────────────────────────────────

class _HeroFocusCard extends ConsumerWidget {
  const _HeroFocusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roadmapAsync = ref.watch(todaysRoadmapProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return roadmapAsync.when(
      loading: () => const _HeroSkeleton(),
      error: (_, _) => const SizedBox.shrink(),
      data: (roadmap) {
        if (roadmap == null || roadmap.tasks.isEmpty) {
          return _HeroEmpty();
        }

        // Resolve project for additional metadata
        final projectsAsync = ref.watch(projectsProvider);
        final project = projectsAsync.valueOrNull
            ?.where((p) => p.id == roadmap.projectId)
            .firstOrNull;

        final daysElapsed = project == null
            ? roadmap.tasks.first.dayNumber
            : DateTime.now().difference(project.createdAt).inDays + 1;
        final totalDays = project?.durationDays ?? 0;
        final dayProgress = totalDays > 0 ? daysElapsed / totalDays : 0.0;
        final taskProgress = roadmap.totalCount == 0
            ? 0.0
            : roadmap.completedCount / roadmap.totalCount;

        // Pick the next pending task (or first if all done)
        final nextTask = roadmap.tasks.firstWhere(
          (t) => t.status != ProjectTaskStatus.completed,
          orElse: () => roadmap.tasks.first,
        );

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
            boxShadow: DesignTokens.glow(scheme.primary),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
            child: Stack(
              children: [
                // Aurora gradient backdrop
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          scheme.primary.withValues(alpha: 0.30),
                          scheme.secondary.withValues(alpha: 0.20),
                          scheme.tertiary.withValues(alpha: 0.10),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
                // Glass overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.60),
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
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
                              color: scheme.primary.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusFull,
                              ),
                            ),
                            child: Text(
                              'TODAY\'S FOCUS',
                              style: textTheme.labelSmall?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (totalDays > 0)
                            Text(
                              'Day $daysElapsed / $totalDays',
                              style: textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ProgressRing(
                            progress: totalDays > 0
                                ? dayProgress
                                : taskProgress,
                            size: 84,
                            strokeWidth: 7,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${((totalDays > 0 ? dayProgress : taskProgress) * 100).round()}%',
                                  style: textTheme.titleMedium?.copyWith(
                                    color: scheme.onSurface,
                                    fontWeight: FontWeight.w800,
                                    height: 1.0,
                                  ),
                                ),
                                Text(
                                  'complete',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  roadmap.projectTitle,
                                  style: textTheme.titleLarge?.copyWith(
                                    color: scheme.onSurface,
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  'NEXT UP',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    letterSpacing: 1.2,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  nextTask.title,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurface,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _StartFocusButton(
                        onTap: () =>
                            context.push('/project/${roadmap.projectId}'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeroEmpty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SceneCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      glow: scheme.primary,
      onTap: () => context.push(AppRoutes.blueprint),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: DesignTokens.brandGradient,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              boxShadow: DesignTokens.glow(scheme.primary),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create your first roadmap',
                  style: textTheme.titleMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'AI-generated daily plans for your goals.',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: scheme.primary, size: 24),
        ],
      ),
    );
  }
}

class _StartFocusButton extends StatefulWidget {
  const _StartFocusButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_StartFocusButton> createState() => _StartFocusButtonState();
}

class _StartFocusButtonState extends State<_StartFocusButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: DesignTokens.motionFast,
    lowerBound: 0,
    upperBound: 0.04,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 1.0,
    end: 0.96,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) => _ctrl.reverse(),
      onTapCancel: () => _ctrl.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            gradient: DesignTokens.brandGradient,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.40),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Start Focus Session',
                style: textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Today's metrics — 4 premium tiles
// ─────────────────────────────────────────────────────────────────────────────

class _TodaysMetrics extends ConsumerWidget {
  const _TodaysMetrics();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(analyticsProvider);
    final focusStats = ref.watch(focusStatsProvider);
    final timeEntries = ref.watch(timeEntriesProvider);

    final summary = analytics.valueOrNull;
    final focusHours = (summary?.totalMinutesDaily ?? 0) / 60;
    final productivityScore = summary?.productivityScore ?? 0;
    final focusRatio = (focusStats.focusRatio * 100).clamp(0.0, 100.0);

    // Tasks completed today (approximate via projects provider)
    final projects = ref.watch(projectsProvider).valueOrNull ?? [];
    final tasksCompletedHint = projects.length;

    final entries = timeEntries.valueOrNull ?? [];
    final sessionsToday = entries.where((e) {
      final now = DateTime.now();
      final s = e.startedAt.toLocal();
      return s.year == now.year && s.month == now.month && s.day == now.day;
    }).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(eyebrow: 'Today', title: 'Your overview'),
        Row(
          children: [
            Expanded(
              child: MetricTile(
                label: 'FOCUS HOURS',
                value: focusHours,
                fractionDigits: 1,
                suffix: 'h',
                icon: Icons.access_time_rounded,
                accentColor: DesignTokens.accentSky,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: MetricTile(
                label: 'CONSISTENCY',
                value: focusRatio,
                suffix: '%',
                icon: Icons.center_focus_strong_rounded,
                accentColor: DesignTokens.accentMint,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: MetricTile(
                label: 'SESSIONS',
                value: sessionsToday,
                icon: Icons.bolt_rounded,
                accentColor: DesignTokens.accentEmber,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: MetricTile(
                label: 'MOMENTUM',
                value: productivityScore,
                suffix: '%',
                icon: Icons.trending_up_rounded,
                accentColor: DesignTokens.accentRose,
                trendLabel: tasksCompletedHint > 0 ? 'active' : null,
                trendUp: tasksCompletedHint > 0,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Today's roadmap — timeline of today's tasks
// ─────────────────────────────────────────────────────────────────────────────

class _TodaysRoadmap extends ConsumerWidget {
  const _TodaysRoadmap();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roadmapAsync = ref.watch(todaysRoadmapProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return roadmapAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (roadmap) {
        if (roadmap == null || roadmap.tasks.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              eyebrow: 'Mission',
              title: 'Today\'s roadmap',
              actionLabel: 'View all',
              onAction: () => context.push('/project/${roadmap.projectId}'),
            ),
            SceneCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < roadmap.tasks.length && i < 5; i++)
                    _TimelineRow(
                      task: roadmap.tasks[i],
                      isLast: i == roadmap.tasks.length - 1 || i == 4,
                      onTap: () =>
                          context.push('/project/${roadmap.projectId}'),
                    ),
                  if (roadmap.tasks.length > 5)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      child: Text(
                        '+${roadmap.tasks.length - 5} more tasks',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.task,
    required this.isLast,
    required this.onTap,
  });

  final ProjectTask task;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final done = task.status == ProjectTaskStatus.completed;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline dot + connector
            Column(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done
                        ? scheme.primary
                        : scheme.surfaceContainerHighest,
                    border: Border.all(
                      color: done ? scheme.primary : scheme.outlineVariant,
                      width: 2,
                    ),
                  ),
                  child: done
                      ? Icon(
                          Icons.check_rounded,
                          size: 12,
                          color: scheme.onPrimary,
                        )
                      : null,
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 28,
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
              ],
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: textTheme.bodyMedium?.copyWith(
                        color: done
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface,
                        fontWeight: FontWeight.w500,
                        decoration: done ? TextDecoration.lineThrough : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (task.estimatedMinutes != null)
                      Text(
                        '${task.estimatedMinutes} min',
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
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

// ─────────────────────────────────────────────────────────────────────────────
// Recent projects
// ─────────────────────────────────────────────────────────────────────────────

class _RecentProjects extends ConsumerWidget {
  const _RecentProjects();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return projectsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (projects) {
        if (projects.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(eyebrow: 'Library', title: 'Roadmaps'),
              SceneCard(
                glow: scheme.primary,
                onTap: () => context.push(AppRoutes.blueprint),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: DesignTokens.brandGradient,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                      ),
                      child: const Icon(Icons.add_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No roadmaps yet',
                            style: textTheme.titleSmall?.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Generate a blueprint with AI',
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
            ],
          );
        }

        final recent = projects.take(3).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              eyebrow: 'Library',
              title: 'Roadmaps',
              actionLabel: '${projects.length} total',
              onAction: () {},
            ),
            for (final project in recent)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: SceneCard(
                  onTap: () => context.push('/project/${project.id}'),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusMd,
                          ),
                        ),
                        child: Icon(
                          Icons.map_rounded,
                          color: scheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              project.title,
                              style: textTheme.titleSmall?.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${project.durationDays} days · ${project.difficulty.label}',
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
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading + Error states
// ─────────────────────────────────────────────────────────────────────────────

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHighest.withValues(alpha: 0.4);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Container(
          height: 24,
          width: 200,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

// End of file
