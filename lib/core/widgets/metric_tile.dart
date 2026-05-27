import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/theme/design_tokens.dart';
import 'package:chronyx/core/widgets/animated_counter.dart';
import 'package:flutter/material.dart';

/// Premium metric tile with animated value, color accent, trend indicator.
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    this.suffix,
    this.fractionDigits = 0,
    this.trendLabel,
    this.trendUp,
  });

  final String label;
  final num value;
  final IconData icon;
  final Color accentColor;
  final String? suffix;
  final int fractionDigits;
  final String? trendLabel;
  final bool? trendUp;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.10),
            accentColor.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.20),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(icon, size: 14, color: accentColor),
              ),
              const Spacer(),
              if (trendLabel != null && trendUp != null)
                Row(
                  children: [
                    Icon(
                      trendUp! ? Icons.trending_up : Icons.trending_down,
                      size: 12,
                      color: trendUp!
                          ? DesignTokens.accentMint
                          : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      trendLabel!,
                      style: textTheme.labelSmall?.copyWith(
                        color: trendUp!
                            ? DesignTokens.accentMint
                            : scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AnimatedCounter(
            value: value,
            suffix: suffix,
            fractionDigits: fractionDigits,
            style: textTheme.headlineSmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
