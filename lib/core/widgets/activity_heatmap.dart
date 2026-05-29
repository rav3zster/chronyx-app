import 'package:chronyx/core/theme/design_tokens.dart';
import 'package:flutter/material.dart';

/// Compact activity heatmap — shows hourly activity intensity.
///
/// Inspired by GitHub contribution graph + Monolith analytics UI.
/// Renders a 7×24 grid (7 days × 24 hours) or a simplified 7-day view.
class ActivityHeatmap extends StatelessWidget {
  const ActivityHeatmap({
    super.key,
    required this.data,
    this.accentColor,
    this.cellSize = 10,
    this.cellGap = 2,
  });

  /// Map of day-offset (0=today, 6=6 days ago) → hour (0-23) → intensity (0.0-1.0)
  final Map<int, Map<int, double>> data;
  final Color? accentColor;
  final double cellSize;
  final double cellGap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final accent = accentColor ?? scheme.primary;

    // Show 7 days × 6 time buckets (4-hour blocks) for compactness
    const buckets = ['12a', '4a', '8a', '12p', '4p', '8p'];
    const bucketHours = [0, 4, 8, 12, 16, 20];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hour labels
        Row(
          children: [
            const SizedBox(width: 20), // day label space
            ...List.generate(buckets.length, (i) {
              return Expanded(
                child: Text(
                  buckets[i],
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                    fontSize: 8,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 4),
        // Grid: 7 rows (days) × 6 columns (time buckets)
        ...List.generate(7, (dayOffset) {
          final dayData = data[dayOffset] ?? {};
          final now = DateTime.now();
          final day = now.subtract(Duration(days: dayOffset));
          final dayLabel = _dayLabel(day, dayOffset);

          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: Text(
                    dayLabel,
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                      fontSize: 8,
                    ),
                  ),
                ),
                ...List.generate(buckets.length, (bucketIdx) {
                  // Average intensity across the 4-hour bucket
                  final startHour = bucketHours[bucketIdx];
                  var total = 0.0;
                  var count = 0;
                  for (var h = startHour; h < startHour + 4; h++) {
                    if (dayData.containsKey(h)) {
                      total += dayData[h]!;
                      count++;
                    }
                  }
                  final intensity = count == 0 ? 0.0 : (total / count);

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: intensity),
                        duration: DesignTokens.motionSlow,
                        curve: DesignTokens.easeOut,
                        builder: (context, v, _) {
                          return Container(
                            height: cellSize,
                            decoration: BoxDecoration(
                              color: v < 0.05
                                  ? scheme.surfaceContainerHighest.withValues(
                                      alpha: 0.4,
                                    )
                                  : accent.withValues(alpha: 0.15 + v * 0.75),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }

  String _dayLabel(DateTime day, int offset) {
    if (offset == 0) return 'T';
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return labels[day.weekday - 1];
  }
}
