import 'package:flutter/material.dart';

/// Centralized motion, shadow, and gradient tokens for Chronyx.
///
/// Use these instead of magic values to keep the visual language consistent.
/// Sits alongside [AppSpacing], [AppColors], [AppTextTheme] — never replace.
class DesignTokens {
  const DesignTokens._();

  // ── Motion ────────────────────────────────────────────────────────────────
  /// Snappy interactions (button press, tab switch).
  static const Duration motionFast = Duration(milliseconds: 150);

  /// Default UI transitions (card reveal, dialog).
  static const Duration motionMedium = Duration(milliseconds: 280);

  /// Slow, cinematic reveals (hero entrance, progress ring fill).
  static const Duration motionSlow = Duration(milliseconds: 600);

  /// Long ambient animations (background gradients, shimmer cycles).
  static const Duration motionAmbient = Duration(milliseconds: 1200);

  /// Standard easing curve for entries.
  static const Curve easeOut = Curves.easeOutCubic;

  /// Springy curve for emphasis (CTA presses, success states).
  static const Cubic easeEmphasized = Cubic(0.2, 0.0, 0.0, 1.0);

  // ── Elevation & Shadows ───────────────────────────────────────────────────
  static List<BoxShadow> shadowSm(Color tint) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.18),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> shadowMd(Color tint) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.25),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> shadowLg(Color tint) => [
    BoxShadow(
      color: tint.withValues(alpha: 0.18),
      blurRadius: 32,
      offset: const Offset(0, 12),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.30),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  /// Glow shadow for hero cards, used sparingly.
  static List<BoxShadow> glow(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.30),
      blurRadius: 40,
      spreadRadius: -8,
      offset: const Offset(0, 0),
    ),
  ];

  // ── Gradients ─────────────────────────────────────────────────────────────
  /// Primary brand gradient — use only on hero CTAs and key metrics.
  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFF5B6EF5), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Cool ambient gradient for background layers.
  static const LinearGradient ambientCool = LinearGradient(
    colors: [Color(0xFF0B1024), Color(0xFF1A0E33)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Subtle glass surface tint over scaffold background.
  static LinearGradient glassTint(Brightness brightness) => LinearGradient(
    colors: brightness == Brightness.dark
        ? [
            Colors.white.withValues(alpha: 0.04),
            Colors.white.withValues(alpha: 0.01),
          ]
        : [
            Colors.white.withValues(alpha: 0.50),
            Colors.white.withValues(alpha: 0.20),
          ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Aurora — used for hero focus card highlight.
  static const LinearGradient auroraGradient = LinearGradient(
    colors: [Color(0xFF5B6EF5), Color(0xFF8B5CF6), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.55, 1.0],
  );

  /// Warm gradient — for streaks, momentum, achievements.
  static const LinearGradient warmGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFFF6B6B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Success gradient — for completed states, on-track health.
  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF22D3A6), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Semantic colors (for badges, dots, accents) ──────────────────────────
  static const Color accentEmber = Color(0xFFF59E0B);
  static const Color accentMint = Color(0xFF22D3A6);
  static const Color accentSky = Color(0xFF38BDF8);
  static const Color accentRose = Color(0xFFFF6B9C);
}
