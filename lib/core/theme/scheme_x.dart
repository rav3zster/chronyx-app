import 'package:flutter/material.dart';

/// Convenience color roles derived from the active [ColorScheme].
extension SchemeX on ColorScheme {
  /// A deeper card surface that stands out against the scaffold background.
  ///
  /// In light themes the base surface and background are very close, so we
  /// blend the on-surface (dark) ink in to darken the card. In dark themes
  /// the elevated surface is already lighter than the background, so we keep
  /// it as-is for natural contrast.
  Color get elevatedCard => brightness == Brightness.dark
      ? surfaceContainerHighest
      : Color.alphaBlend(
          onSurface.withValues(alpha: 0.10),
          surfaceContainerHighest,
        );

  /// A subtle inner surface for chips/pills placed on top of [elevatedCard].
  Color get elevatedCardInner => brightness == Brightness.dark
      ? surface.withValues(alpha: 0.6)
      : Color.alphaBlend(
          onSurface.withValues(alpha: 0.05),
          surfaceContainerHighest,
        );
}
