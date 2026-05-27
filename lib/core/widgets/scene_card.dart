import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:flutter/material.dart';

/// A premium "scene" container with subtle inner gradient, soft border,
/// and tasteful elevation. The default container for content blocks.
///
/// Use this instead of `Card` or `GlassCard` for redesigned screens.
class SceneCard extends StatelessWidget {
  const SceneCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.borderRadius = AppSpacing.radiusXl,
    this.gradient,
    this.glow,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Gradient? gradient;
  final Color? glow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    final bgGradient =
        gradient ??
        LinearGradient(
          colors: isDark
              ? [
                  scheme.surfaceContainerHighest.withValues(alpha: 0.65),
                  scheme.surface.withValues(alpha: 0.85),
                ]
              : [
                  Colors.white.withValues(alpha: 0.95),
                  Colors.white.withValues(alpha: 0.75),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

    final shadows = <BoxShadow>[
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
        blurRadius: 28,
        offset: const Offset(0, 12),
      ),
      if (glow != null)
        BoxShadow(
          color: glow!.withValues(alpha: 0.15),
          blurRadius: 40,
          spreadRadius: -10,
          offset: const Offset(0, 0),
        ),
    ];

    final card = Container(
      decoration: BoxDecoration(
        gradient: bgGradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.6),
          width: 1,
        ),
        boxShadow: shadows,
      ),
      padding: padding,
      child: child,
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(borderRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: onTap,
        splashColor: scheme.primary.withValues(alpha: 0.08),
        highlightColor: scheme.primary.withValues(alpha: 0.04),
        child: card,
      ),
    );
  }
}
