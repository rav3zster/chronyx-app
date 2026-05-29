import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/theme/scheme_x.dart';
import 'package:chronyx/core/widgets/section_header.dart';
import 'package:chronyx/features/life_insights/domain/entities/weekly_win.dart';
import 'package:flutter/material.dart';

/// Horizontally scrolling celebratory cards.
class WeeklyWinsRow extends StatelessWidget {
  const WeeklyWinsRow({super.key, required this.wins});
  final List<WeeklyWin> wins;

  @override
  Widget build(BuildContext context) {
    if (wins.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(eyebrow: 'Wins', title: 'This week\'s wins'),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: wins.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (_, i) => _WinCard(win: wins[i]),
          ),
        ),
      ],
    );
  }
}

class _WinCard extends StatelessWidget {
  const _WinCard({required this.win});
  final WeeklyWin win;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: 200,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.elevatedCard,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Text(win.emoji, style: const TextStyle(fontSize: 18)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(
                  'WIN',
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            win.title,
            style: textTheme.titleSmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Text(
              win.detail,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
