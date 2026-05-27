import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/widgets/press_scale.dart';
import 'package:chronyx/core/widgets/progress_ring.dart';
import 'package:chronyx/features/life_insights/domain/entities/today_focus.dart';
import 'package:chronyx/features/life_insights/presentation/providers/life_insights_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Dashboard Hero — picks one of five visual states from real data.
///
/// Replaces the previous `_HeroFocusCard`. Always renders something
/// inspiring: even brand-new users see the newcomer variant.
class TodayFocusHero extends ConsumerWidget {
  const TodayFocusHero({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focusAsync = ref.watch(todayFocusProvider);

    return focusAsync.when(
      loading: () => const _HeroSkeleton(),
      error: (_, _) => const _HeroSkeleton(),
      data: (focus) => _HeroCard(focus: focus),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.focus});
  final TodayFocus focus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PressScale(
      onTap: () => context.push(focus.ctaRoute),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
          boxShadow: [
            BoxShadow(
              color: focus.mood.accent.withValues(alpha: 0.34),
              blurRadius: 44,
              spreadRadius: -10,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.30),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(gradient: focus.mood.heroGradient),
                ),
              ),
              Positioned.fill(
                child: Container(color: scheme.surface.withValues(alpha: 0.62)),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: _HeroBody(focus: focus),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroBody extends StatelessWidget {
  const _HeroBody({required this.focus});
  final TodayFocus focus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: focus.mood.accent.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
              child: Text(
                _eyebrow(focus.kind),
                style: textTheme.labelSmall?.copyWith(
                  color: focus.mood.accent,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  fontSize: 10,
                ),
              ),
            ),
            if (focus.dayNumber != null && focus.totalDays != null) ...[
              const Spacer(),
              Text(
                'Day ${focus.dayNumber} / ${focus.totalDays}',
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (focus.hasProjectContext)
          _ProjectMission(focus: focus)
        else
          _StandaloneHeadline(focus: focus),
        const SizedBox(height: AppSpacing.lg),
        _HeroCta(focus: focus),
      ],
    );
  }

  String _eyebrow(TodayFocusKind kind) => switch (kind) {
    TodayFocusKind.newcomer => 'WELCOME',
    TodayFocusKind.noRoadmap => 'NEXT CHAPTER',
    TodayFocusKind.behind => 'GENTLE NUDGE',
    TodayFocusKind.flowing => 'IN FLOW',
    TodayFocusKind.active => 'TODAY\'S MISSION',
  };
}

class _ProjectMission extends StatelessWidget {
  const _ProjectMission({required this.focus});
  final TodayFocus focus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final ringProgress = focus.totalDays == 0
        ? 0.0
        : (focus.dayNumber ?? 0) / focus.totalDays!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ProgressRing(
          progress: ringProgress.clamp(0.0, 1.0),
          size: 80,
          strokeWidth: 6,
          gradient: focus.mood.heroGradient,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(ringProgress * 100).round()}%',
                style: textTheme.titleMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
              Text(
                'journey',
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
              if (focus.glyph != null)
                Row(
                  children: [
                    Text(focus.glyph!, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        focus.headline,
                        style: textTheme.titleLarge?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          height: 1.15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 4),
              Text(
                focus.subhead,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (focus.topTask != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _TopTaskRow(focus: focus),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TopTaskRow extends StatelessWidget {
  const _TopTaskRow({required this.focus});
  final TodayFocus focus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final task = focus.topTask!;
    final mins = focus.recommendedMinutes ?? task.estimatedMinutes ?? 30;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: focus.mood.accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: focus.mood.accent.withValues(alpha: 0.6),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              task.title,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${mins}m',
            style: textTheme.labelSmall?.copyWith(
              color: focus.mood.accent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StandaloneHeadline extends StatelessWidget {
  const _StandaloneHeadline({required this.focus});
  final TodayFocus focus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                focus.mood.accent.withValues(alpha: 0.45),
                focus.mood.accent.withValues(alpha: 0.0),
              ],
            ),
          ),
          child: Text(focus.glyph ?? '✨', style: const TextStyle(fontSize: 26)),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                focus.headline,
                style: textTheme.titleLarge?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  height: 1.15,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                focus.subhead,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroCta extends StatelessWidget {
  const _HeroCta({required this.focus});
  final TodayFocus focus;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      height: 50,
      decoration: BoxDecoration(
        gradient: focus.mood.heroGradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        boxShadow: [
          BoxShadow(
            color: focus.mood.accent.withValues(alpha: 0.45),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            focus.kind == TodayFocusKind.behind
                ? Icons.refresh_rounded
                : focus.kind == TodayFocusKind.newcomer ||
                      focus.kind == TodayFocusKind.noRoadmap
                ? Icons.auto_awesome_rounded
                : Icons.play_arrow_rounded,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            focus.ctaLabel,
            style: textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
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
