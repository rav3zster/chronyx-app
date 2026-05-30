import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/theme/scheme_x.dart';
import 'package:chronyx/features/project_planner/domain/entities/completion_report.dart';
import 'package:chronyx/features/project_planner/domain/entities/project.dart';
import 'package:flutter/material.dart';

/// Formats a date like "Jan 5, 2024" without pulling in intl (keeps the
/// web hot-restart graph stable).
String _formatDate(DateTime d) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

/// Premium, reflective completion experience. Typography-driven, dense,
/// subtle ambient motion — no confetti, no badges, no XP.
class ProjectCompletionView extends StatelessWidget {
  const ProjectCompletionView({
    super.key,
    required this.project,
    required this.report,
    required this.onCreateNew,
    required this.onRegenerateSimilar,
    required this.onDuplicate,
    required this.onArchive,
    required this.onViewAnalytics,
  });

  final Project project;
  final CompletionReport report;
  final VoidCallback onCreateNew;
  final VoidCallback onRegenerateSimilar;
  final VoidCallback onDuplicate;
  final VoidCallback onArchive;
  final VoidCallback onViewAnalytics;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
      children: [
        _Hero(project: project, report: report),
        const SizedBox(height: 28),
        _StatsBlock(report: report),
        if (report.insights.isNotEmpty) ...[
          const SizedBox(height: 28),
          _Section(label: 'REFLECTION'),
          const SizedBox(height: 12),
          _Insights(insights: report.insights),
        ],
        if (report.timeline.isNotEmpty) ...[
          const SizedBox(height: 28),
          _Section(label: 'THE JOURNEY'),
          const SizedBox(height: 12),
          _JourneyBeats(beats: report.timeline),
        ],
        const SizedBox(height: 32),
        _WhatNext(
          onCreateNew: onCreateNew,
          onRegenerateSimilar: onRegenerateSimilar,
          onDuplicate: onDuplicate,
          onArchive: onArchive,
          onViewAnalytics: onViewAnalytics,
        ),
      ],
    );
  }
}

// ── Hero ──────────────────────────────────────────────────────────────────

class _Hero extends StatefulWidget {
  const _Hero({required this.project, required this.report});
  final Project project;
  final CompletionReport report;

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> with SingleTickerProviderStateMixin {
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subtle breathing accent dot + eyebrow.
          Row(
            children: [
              AnimatedBuilder(
                animation: _ambient,
                builder: (context, _) {
                  final t = 0.4 + _ambient.value * 0.6;
                  return Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.5 * t),
                          blurRadius: 10 * t,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              Text(
                'BLUEPRINT COMPLETE',
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '100%',
            style: textTheme.displayLarge?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w800,
              letterSpacing: -3,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.project.title,
            style: textTheme.headlineSmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Completed in ${widget.report.daysToComplete} '
            'day${widget.report.daysToComplete == 1 ? '' : 's'}'
            '${widget.report.completedAt != null ? ' · ${_formatDate(widget.report.completedAt!.toLocal())}' : ''}',
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats ───────────────────────────────────────────────────────────────────

class _StatsBlock extends StatelessWidget {
  const _StatsBlock({required this.report});
  final CompletionReport report;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hours = report.focusHours;
    final hoursStr = hours >= 10
        ? hours.toStringAsFixed(0)
        : hours.toStringAsFixed(1);

    final stats = <(_StatValue, String)>[
      (_StatValue('${report.daysToComplete}', ''), 'DAYS'),
      (_StatValue('${report.completedTasks}', ''), 'TASKS DONE'),
      (_StatValue(hoursStr, 'h'), 'FOCUS'),
      (_StatValue('${report.streakDays}', ''), 'BEST STREAK'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 44,
                color: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: _Stat(value: stats[i].$1, label: stats[i].$2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatValue {
  const _StatValue(this.number, this.unit);
  final String number;
  final String unit;
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final _StatValue value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [
              TextSpan(
                text: value.number,
                style: textTheme.headlineSmall?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              if (value.unit.isNotEmpty)
                TextSpan(
                  text: value.unit,
                  style: textTheme.titleMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontSize: 9,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

// ── Insights ──────────────────────────────────────────────────────────────

class _Insights extends StatelessWidget {
  const _Insights({required this.insights});
  final List<String> insights;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        for (var i = 0; i < insights.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == insights.length - 1 ? 0 : 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    insights[i],
                    style: textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurface,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
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

// ── Journey beats ───────────────────────────────────────────────────────────

class _JourneyBeats extends StatelessWidget {
  const _JourneyBeats({required this.beats});
  final List<TimelineBeat> beats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        for (var i = 0; i < beats.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 20,
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: Container(
                            width: 2,
                            color: i == 0
                                ? Colors.transparent
                                : scheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Container(
                            width: 2,
                            color: i == beats.length - 1
                                ? Colors.transparent
                                : scheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 64,
                          child: Text(
                            'Week ${beats[i].week}',
                            style: textTheme.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            beats[i].label,
                            style: textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
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

// ── What next ─────────────────────────────────────────────────────────────

class _WhatNext extends StatelessWidget {
  const _WhatNext({
    required this.onCreateNew,
    required this.onRegenerateSimilar,
    required this.onDuplicate,
    required this.onArchive,
    required this.onViewAnalytics,
  });

  final VoidCallback onCreateNew;
  final VoidCallback onRegenerateSimilar;
  final VoidCallback onDuplicate;
  final VoidCallback onArchive;
  final VoidCallback onViewAnalytics;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'WHAT NEXT',
          style: textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 14),
        _PrimaryButton(
          label: 'Create New Blueprint',
          icon: Icons.add_rounded,
          onTap: onCreateNew,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _GhostButton(
                label: 'Regenerate Similar',
                icon: Icons.auto_mode_rounded,
                onTap: onRegenerateSimilar,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _GhostButton(
                label: 'Duplicate',
                icon: Icons.copy_all_rounded,
                onTap: onDuplicate,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _GhostButton(
                label: 'View Analytics',
                icon: Icons.insights_rounded,
                onTap: onViewAnalytics,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _GhostButton(
                label: 'Archive',
                icon: Icons.inventory_2_outlined,
                onTap: onArchive,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: scheme.primary,
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        onTap: onTap,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: scheme.onPrimary),
              const SizedBox(width: 8),
              Text(
                label,
                style: textTheme.titleSmall?.copyWith(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: scheme.elevatedCard,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        onTap: onTap,
        child: Container(
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: scheme.onSurface),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelLarge?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
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

// ── Section label ───────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: scheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6,
      ),
    );
  }
}
