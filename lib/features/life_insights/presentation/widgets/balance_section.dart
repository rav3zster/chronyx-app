import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/theme/scheme_x.dart';
import 'package:chronyx/core/widgets/section_header.dart';
import 'package:chronyx/features/life_insights/domain/entities/life_balance.dart';
import 'package:chronyx/features/life_insights/presentation/widgets/balance_radar.dart';
import 'package:flutter/material.dart';

/// "Life Balance" section: hex radar + commentary on dominant + neglected.
class BalanceSection extends StatelessWidget {
  const BalanceSection({super.key, required this.balance});

  final LifeBalance balance;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(eyebrow: 'Balance', title: 'Life balance radar'),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: scheme.elevatedCard,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Column(
            children: [
              if (!balance.hasData)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text(
                    'Track sessions to map your life balance.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                Center(child: BalanceRadar(balance: balance, size: 240)),
              const SizedBox(height: AppSpacing.md),
              if (balance.hasData) _Commentary(balance: balance),
            ],
          ),
        ),
      ],
    );
  }
}

class _Commentary extends StatelessWidget {
  const _Commentary({required this.balance});
  final LifeBalance balance;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final dominant = balance.dominantAxis;
    final neglected = balance.neglectedAxis;

    return Column(
      children: [
        if (dominant != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _CommentaryRow(
              dotColor: dominant.area.color,
              label: 'Most invested',
              value: dominant.area.label,
              hours: dominant.minutes / 60,
            ),
          ),
        if (neglected != null && neglected.area != dominant?.area)
          _CommentaryRow(
            dotColor: neglected.area.color,
            label: 'Least invested',
            value: neglected.area.label,
            hours: neglected.minutes / 60,
            muted: true,
          ),
        if (dominant != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm + 2,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: scheme.elevatedCardInner,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dominant.area.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    neglected != null && neglected.area != dominant.area
                        ? 'Strong on ${dominant.area.label}, light on ${neglected.area.label}.'
                        : 'You\'re leading with ${dominant.area.label}.',
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CommentaryRow extends StatelessWidget {
  const _CommentaryRow({
    required this.dotColor,
    required this.label,
    required this.value,
    required this.hours,
    this.muted = false,
  });

  final Color dotColor;
  final String label;
  final String value;
  final double hours;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final timeStr = hours >= 1
        ? '${hours.toStringAsFixed(1)}h'
        : '${(hours * 60).round()}m';
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: dotColor.withValues(alpha: 0.5), blurRadius: 6),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label.toUpperCase(),
          style: textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            letterSpacing: 1.2,
            fontSize: 9,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: textTheme.bodyMedium?.copyWith(
            color: muted ? scheme.onSurfaceVariant : scheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          timeStr,
          style: textTheme.labelMedium?.copyWith(
            color: dotColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
