import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/widgets/section_header.dart';
import 'package:chronyx/features/life_insights/domain/entities/life_report.dart';
import 'package:flutter/material.dart';

/// "Micro Wrapped" — Spotify Wrapped-style numbered story snapshot.
///
/// Visually the most rewarding section. Always shows when there's data.
class MicroWrapped extends StatelessWidget {
  const MicroWrapped({super.key, required this.report});
  final LifeReport report;

  @override
  Widget build(BuildContext context) {
    if (!report.hasEnoughData) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final r = report.reflection;
    final accent = scheme.primary;

    final entries = [
      _Entry('01', 'Focused', r.focusedFormatted),
      _Entry('02', 'Top activity', r.topActivityLabel),
      _Entry('03', 'Peak hour', _formatHour(r.peakHour)),
      _Entry('04', 'Top day', _bestDayLabel(r) ?? '—'),
      _Entry('05', 'Momentum', switch (r.momentum) {
        TrendDirection.up => 'Rising',
        TrendDirection.down => 'Slowing',
        TrendDirection.flat => 'Steady',
      }),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          eyebrow: 'Wrapped',
          title: 'Your ${report.window.label.toLowerCase()} story',
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Icon(
                      Icons.auto_stories_outlined,
                      size: 18,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Your story',
                      style: textTheme.titleLarge?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusFull,
                      ),
                    ),
                    child: Text(
                      report.window.label.toUpperCase(),
                      style: textTheme.labelSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              for (var i = 0; i < entries.length; i++) ...[
                _WrappedEntry(entry: entries[i], accent: accent),
                if (i != entries.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Container(
                      height: 1,
                      color: scheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
              ],
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

  String? _bestDayLabel(WeeklyReflection r) {
    if (r.dailyMinutes.isEmpty) return null;
    final best = r.dailyMinutes.reduce((a, b) => a.value >= b.value ? a : b);
    if (best.value <= 0) return null;
    return best.label;
  }
}

class _Entry {
  const _Entry(this.index, this.label, this.value);
  final String index;
  final String label;
  final String value;
}

class _WrappedEntry extends StatelessWidget {
  const _WrappedEntry({required this.entry, required this.accent});
  final _Entry entry;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 30,
          child: Text(
            entry.index,
            style: textTheme.labelLarge?.copyWith(
              color: accent.withValues(alpha: 0.7),
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        Expanded(
          child: Text(
            entry.label,
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        Flexible(
          child: Text(
            entry.value,
            style: textTheme.titleMedium?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
