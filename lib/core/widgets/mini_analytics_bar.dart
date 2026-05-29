import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/theme/design_tokens.dart';
import 'package:flutter/material.dart';

/// A compact category distribution bar for the dashboard.
///
/// Shows where time went as a segmented horizontal bar + legend.
/// Designed to be dense and readable — not a full chart.
class MiniAnalyticsBar extends StatelessWidget {
  const MiniAnalyticsBar({super.key, required this.segments, this.height = 8});

  final List<BarSegment> segments;
  final double height;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final total = segments.fold<double>(0, (a, s) => a + s.value);
    if (total == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Segmented bar
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          child: SizedBox(
            height: height,
            child: Row(
              children: segments.map((s) {
                final flex = ((s.value / total) * 1000).round();
                return Expanded(
                  flex: flex.clamp(1, 1000),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: DesignTokens.motionSlow,
                    curve: DesignTokens.easeOut,
                    builder: (context, v, _) {
                      return Container(color: s.color.withValues(alpha: v));
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Legend — compact, 2 per row
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: 4,
          children: segments.map((s) {
            final pct = ((s.value / total) * 100).round();
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: s.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${s.label} $pct%',
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

class BarSegment {
  const BarSegment({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;
}
