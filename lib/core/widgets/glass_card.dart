import 'dart:ui';
import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:flutter/material.dart';

/// A glass-morphism card container with a frosted blur effect.
///
/// Adapts automatically to dark/light themes using the color scheme.
/// Set [useBlur] to false for a solid surface card without the blur overhead.
class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.borderRadius = AppSpacing.radiusXl,
    this.useBlur = true,
    this.blurSigma = AppSpacing.blurMd,
    this.borderColor,
    this.backgroundColor,
    this.boxShadow,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  /// Whether to apply a BackdropFilter blur behind the card.
  final bool useBlur;

  /// Sigma for the blur effect (larger = more frosted).
  final double blurSigma;

  /// Override the border color; defaults to [ColorScheme.outlineVariant].
  final Color? borderColor;

  /// Override the fill color; defaults to a semi-transparent surface.
  final Color? backgroundColor;

  /// Optional shadow list.
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    final defaultBg = isDark
        ? scheme.surfaceContainerHighest.withValues(alpha: 0.55)
        : scheme.surface.withValues(alpha: 0.75);

    final defaultBorder = borderColor ?? scheme.outlineVariant;

    final decoration = BoxDecoration(
      color: backgroundColor ?? defaultBg,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: defaultBorder, width: 1),
      boxShadow: boxShadow ??
          [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
    );

    final content = Container(
      padding: padding,
      decoration: decoration,
      child: child,
    );

    if (!useBlur) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: content,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: content,
      ),
    );
  }
}
