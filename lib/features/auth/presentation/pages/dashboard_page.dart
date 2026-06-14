import 'dart:math' as math;

import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/errors/error_message_mapper.dart';
import 'package:chronyx/core/routing/app_routes.dart';
import 'package:chronyx/core/utils/responsive.dart';
import 'package:chronyx/core/widgets/animated_counter.dart';
import 'package:chronyx/features/analytics/presentation/providers/analytics_providers.dart';
import 'package:chronyx/features/auth/presentation/providers/auth_provider.dart';
import 'package:chronyx/features/life_insights/presentation/providers/life_insights_providers.dart';
import 'package:chronyx/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:chronyx/features/project_planner/presentation/providers/project_planner_providers.dart';
import 'package:chronyx/features/time_tracking/presentation/providers/time_tracking_providers.dart';
import 'package:chronyx/features/settings/presentation/providers/settings_provider.dart';
import 'package:chronyx/core/widgets/press_scale.dart';
import 'package:chronyx/core/services/permission_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Layout tokens (sizing only — all colors come from the active theme so the
// home screen reacts to theme switching like every other screen).
// ─────────────────────────────────────────────────────────────────────────────
const _kRadius = 20.0;
const _kPad = 20.0;

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(permissionServiceProvider).requestOnFirstLaunch(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: authState.maybeWhen(
          loading: () => const _Skeleton(),
          error: (err, _) => _ErrorView(
            message: ErrorMessageMapper.fromError(err),
            onRetry: () => ref.read(authProvider.notifier).getCurrentUser(),
          ),
          orElse: () => _Content(user: authState.valueOrNull),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main content
// ─────────────────────────────────────────────────────────────────────────────

class _Content extends ConsumerWidget {
  const _Content({required this.user});
  final dynamic user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final padMult = settings.compactDashboardMode ? 0.6 : 1.0;
    final padding = context.spacing(20 * padMult);

    final quotes = [
      "The only way to do great work is to love what you do. — Steve Jobs",
      "Focus is a muscle, and you build it by using it. — Unknown",
      "It is not that we have a short time to live, but that we waste a lot of it. — Seneca",
      "Productivity is being able to do things that you were never able to do before. — Franz Kafka",
      "Done is better than perfect. — Sheryl Sandberg",
      "Your mind is for having ideas, not holding them. — David Allen",
    ];
    final quoteIndex = DateTime.now().day % quotes.length;
    final quoteText = quotes[quoteIndex];

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ResponsiveCenter(
        maxWidth: context.responsiveValue(
          compact: Breakpoints.maxContent,
          medium: Breakpoints.maxContent,
          expanded: Breakpoints.maxDoubleContent,
        ),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Greeting
            SliverPadding(
              padding: EdgeInsets.fromLTRB(padding, context.spacing(20 * padMult), padding, 0),
              sliver: SliverToBoxAdapter(child: _Greeting(user: user)),
            ),

            // Quotes Card (if enabled)
            if (settings.showQuotes)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(padding, context.spacing(14 * padMult), padding, 0),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.format_quote_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            quoteText,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Hero card
            SliverPadding(
              padding: EdgeInsets.fromLTRB(padding, context.spacing(20 * padMult), padding, 0),
              sliver: SliverToBoxAdapter(child: const _HeroCard()),
            ),

            // Today's overview
            SliverPadding(
              padding: EdgeInsets.fromLTRB(padding, context.spacing(28 * padMult), padding, 0),
              sliver: SliverToBoxAdapter(child: const _TodayOverview()),
            ),

            // This week (Weekly Graph)
            if (settings.showWeeklyGraph)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(padding, context.spacing(28 * padMult), padding, context.spacing(120 * padMult)),
                sliver: SliverToBoxAdapter(child: const _ThisWeek()),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(padding, 0, padding, context.spacing(120 * padMult)),
                sliver: const SliverToBoxAdapter(child: SizedBox.shrink()),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Greeting
// ─────────────────────────────────────────────────────────────────────────────

class _Greeting extends ConsumerWidget {
  const _Greeting({required this.user});
  final dynamic user;

  String get _name {
    if (user?.email == null) return 'there';
    final local = (user.email as String).split('@').first;
    return local.isEmpty
        ? 'there'
        : local[0].toUpperCase() + local.substring(1);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final greeting = ref.watch(greetingProvider).valueOrNull;
    final salutation = greeting?.salutation ?? _salutation();
    final name = greeting?.name ?? _name;
    final message = greeting?.message ?? "Let's make today count.";

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const ProfileAvatar(),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$salutation, $name',
                style: textTheme.headlineMedium?.copyWith(
                  color: scheme.onSurface,
                  fontSize: context.scaleFont(26),
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontSize: context.scaleFont(14),
                  fontWeight: FontWeight.w400,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(Icons.check_box_outlined, color: scheme.primary, size: 28),
          tooltip: 'To-Dos',
          onPressed: () => context.push(AppRoutes.todos),
        ),
      ],
    );
  }

  String _salutation() {
    final h = DateTime.now().hour;
    if (h < 5) return 'Late night';
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    if (h < 22) return 'Good evening';
    return 'Late night';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero card — dark with gold CTA
// ─────────────────────────────────────────────────────────────────────────────

class _HeroCard extends ConsumerWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final projects = ref.watch(projectsProvider).valueOrNull ?? [];
    final hasProject = projects.isNotEmpty;

    return Container(
      padding: EdgeInsets.all(context.spacing(24)),
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(_kRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NEXT CHAPTER',
            style: textTheme.labelSmall?.copyWith(
              color: scheme.onInverseSurface.withValues(alpha: 0.55),
              fontSize: context.scaleFont(11),
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hasProject
                ? projects.first.title
                : 'Turn a goal into a daily\nroadmap — start here.',
            style: textTheme.titleLarge?.copyWith(
              color: scheme.onInverseSurface,
              fontSize: context.scaleFont(22),
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 20),
          PressScale(
            onTap: () => context.push(
              hasProject
                  ? '/project/${projects.first.id}'
                  : AppRoutes.blueprint,
            ),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: context.spacing(20),
                vertical: context.spacing(12),
              ),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '✦',
                    style: TextStyle(color: scheme.onPrimary, fontSize: context.scaleFont(13)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasProject ? 'Continue Roadmap' : 'Create Blueprint',
                    style: textTheme.labelLarge?.copyWith(
                      color: scheme.onPrimary,
                      fontSize: context.scaleFont(14),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
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
// Today's overview — 2×2 metric grid
// ─────────────────────────────────────────────────────────────────────────────

class _TodayOverview extends ConsumerWidget {
  const _TodayOverview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final analytics = ref.watch(analyticsProvider);
    final focusStats = ref.watch(focusStatsProvider);
    final timeEntries = ref.watch(timeEntriesProvider);

    final summary = analytics.valueOrNull;
    final focusHours = (summary?.totalMinutesDaily ?? 0) / 60;
    final consistency = (focusStats.focusRatio * 100).clamp(0.0, 100.0);
    final momentum = summary?.productivityScore ?? 0;

    final entries = timeEntries.valueOrNull ?? [];
    final sessionsToday = entries.where((e) {
      final now = DateTime.now();
      final s = e.startedAt.toLocal();
      return s.year == now.year && s.month == now.month && s.day == now.day;
    }).length;

    final isCompact = context.isCompact;

    final activeCards = <Widget>[
      _MetricCard(
        value: focusHours,
        unit: 'h',
        label: isCompact ? 'FOCUS\nHOURS' : 'FOCUS HOURS',
        fractionDigits: 1,
      ),
      if (settings.showStreakCard)
        _MetricCard(
          value: consistency,
          unit: '%',
          label: 'CONSISTENCY',
          fractionDigits: 0,
        ),
      _MetricCard(
        value: sessionsToday.toDouble(),
        unit: '',
        label: 'SESSIONS',
        fractionDigits: 0,
      ),
      if (settings.showMomentumCard)
        _MetricCard(
          value: momentum,
          unit: '%',
          label: 'MOMENTUM',
          fractionDigits: 0,
        ),
    ];

    if (activeCards.isEmpty) {
      return const SizedBox.shrink();
    }

    if (isCompact) {
      final List<Widget> rows = [];
      for (var i = 0; i < activeCards.length; i += 2) {
        final hasNext = i + 1 < activeCards.length;
        rows.add(
          Row(
            children: [
              Expanded(child: activeCards[i]),
              if (hasNext) ...[
                const SizedBox(width: 10),
                Expanded(child: activeCards[i + 1]),
              ] else
                const Expanded(child: SizedBox.shrink()),
            ],
          ),
        );
        if (i + 2 < activeCards.length) {
          rows.add(const SizedBox(height: 10));
        }
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel("TODAY'S OVERVIEW"),
          const SizedBox(height: 12),
          ...rows,
        ],
      );
    } else {
      final List<Widget> rowItems = [];
      for (var i = 0; i < activeCards.length; i++) {
        rowItems.add(Expanded(child: activeCards[i]));
        if (i < activeCards.length - 1) {
          rowItems.add(const SizedBox(width: 10));
        }
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel("TODAY'S OVERVIEW"),
          const SizedBox(height: 12),
          Row(children: rowItems),
        ],
      );
    }
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.value,
    required this.unit,
    required this.label,
    required this.fractionDigits,
  });

  final double value;
  final String unit;
  final String label;
  final int fractionDigits;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.all(context.spacing(16)),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(_kRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedCounter(
                value: value,
                fractionDigits: fractionDigits,
                style: textTheme.displaySmall?.copyWith(
                  color: scheme.onSurface,
                  fontSize: context.scaleFont(32),
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  height: 1.0,
                ),
              ),
              if (unit.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    unit,
                    style: textTheme.titleMedium?.copyWith(
                      color: scheme.onSurface,
                      fontSize: context.scaleFont(18),
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontSize: context.scaleFont(10),
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// This week — insight card with ring
// ─────────────────────────────────────────────────────────────────────────────

class _ThisWeek extends ConsumerWidget {
  const _ThisWeek();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final analytics = ref.watch(analyticsProvider);
    final snapshot = ref.watch(lifeSnapshotProvider).valueOrNull;

    final summary = analytics.valueOrNull;
    final weekHours = (summary?.totalMinutesWeekly ?? 0) / 60;
    final score = summary?.productivityScore ?? 0;
    final progress = (score / 100).clamp(0.0, 1.0);

    final headline =
        snapshot?.smartHeadline ?? 'Track sessions to unlock insights.';
    final topActivity = summary?.topTasks.isNotEmpty == true
        ? summary!.topTasks.first.key
        : null;
    final peakHour = summary?.peakHour;

    String insightText = '';
    if (weekHours > 0) {
      insightText = 'Tracked ${weekHours.toStringAsFixed(1)}h across 7 days.';
      if (peakHour != null) {
        insightText += ' You focus best in the ${_period(peakHour)}.';
      }
    } else {
      insightText = 'Start tracking to see your weekly insights.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('THIS WEEK'),
        const SizedBox(height: 12),
        PressScale(
          onTap: () => context.push(AppRoutes.lifeInsights),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(_kRadius),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Ring
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CustomPaint(
                    painter: _RingPainter(
                      progress: progress,
                      trackColor: scheme.outlineVariant,
                      arcColor: scheme.primary,
                    ),
                    child: Center(
                      child: Text(
                        '${weekHours.toStringAsFixed(1)}h',
                        style: textTheme.labelLarge?.copyWith(
                          color: scheme.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topActivity != null
                            ? '${(progress * 100).round()}% on $topActivity'
                            : headline,
                        style: textTheme.titleMedium?.copyWith(
                          color: scheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        insightText,
                        style: textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _period(int hour) {
    if (hour >= 5 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 17) return 'afternoon';
    if (hour >= 17 && hour < 21) return 'evening';
    return 'night';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ring painter — warm gold
// ─────────────────────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.arcColor,
  });
  final double progress;
  final Color trackColor;
  final Color arcColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    const sw = 4.0;

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw,
    );

    // Arc
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        progress * 2 * math.pi,
        false,
        Paint()
          ..color = arcColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress ||
      old.trackColor != trackColor ||
      old.arcColor != arcColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// Section label — small caps, muted
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.5,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading + Error
// ─────────────────────────────────────────────────────────────────────────────

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHighest;
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.all(_kPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 28,
            width: 200,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(_kRadius),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 90,
                  decoration: BoxDecoration(
                    color: base,
                    borderRadius: BorderRadius.circular(_kRadius),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 90,
                  decoration: BoxDecoration(
                    color: base,
                    borderRadius: BorderRadius.circular(_kRadius),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 40,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurface, fontSize: 14),
              ),
              const SizedBox(height: 16),
              PressScale(
                onTap: onRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: Text(
                    'Try again',
                    style: TextStyle(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
