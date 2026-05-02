import 'package:flutter/material.dart';

/// Central color palette for Chronyx.
/// All raw color values live here; never hardcode colors in widgets.
class AppColors {
  const AppColors._();

  // ── Brand ──────────────────────────────────────────────────────────────────
  /// Electric indigo — primary brand color
  static const Color indigo = Color(0xFF5B6EF5);

  /// Deep indigo — darker tint for gradients
  static const Color indigoDark = Color(0xFF3A4FE0);

  /// Vivid violet — secondary accent
  static const Color violet = Color(0xFF8B5CF6);

  /// Cyan glow — tertiary highlight
  static const Color cyan = Color(0xFF06B6D4);

  // ── Dark theme palette ─────────────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF080B14);
  static const Color darkSurface = Color(0xFF0D1120);
  static const Color darkSurface2 = Color(0xFF131929);
  static const Color darkSurface3 = Color(0xFF1C2340);
  static const Color darkBorder = Color(0xFF252D4A);
  static const Color darkBorderSubtle = Color(0xFF1A2035);

  // ── Light theme palette ────────────────────────────────────────────────────
  static const Color lightBackground = Color(0xFFF4F6FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurface2 = Color(0xFFF0F3FA);
  static const Color lightSurface3 = Color(0xFFE8EDF8);
  static const Color lightBorder = Color(0xFFDDE3F0);
  static const Color lightBorderSubtle = Color(0xFFECF0FA);

  // ── Text ───────────────────────────────────────────────────────────────────
  static const Color textPrimaryDark = Color(0xFFF1F4FF);
  static const Color textSecondaryDark = Color(0xFF8B96B8);
  static const Color textDisabledDark = Color(0xFF4A5580);

  static const Color textPrimaryLight = Color(0xFF0F1733);
  static const Color textSecondaryLight = Color(0xFF5A6480);
  static const Color textDisabledLight = Color(0xFFADB8D4);

  // ── Semantic ───────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF22D3A6);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFFF5370);
  static const Color info = Color(0xFF38BDF8);

  // ── Ocean (Midnight Ocean) theme palette ───────────────────────────────────
  static const Color oceanPrimary = Color(0xFF06B6D4);
  static const Color oceanBackground = Color(0xFF040D12);
  static const Color oceanSurface = Color(0xFF071419);
  static const Color oceanSurface2 = Color(0xFF0C1E24);
  static const Color oceanSurface3 = Color(0xFF132830);

  // ── Amber (Sunset Amber) theme palette ────────────────────────────────────
  static const Color amberPrimary = Color(0xFFF59E0B);
  static const Color amberBackground = Color(0xFF0A0700);
  static const Color amberSurface = Color(0xFF120E02);
  static const Color amberSurface2 = Color(0xFF1C1704);
  static const Color amberSurface3 = Color(0xFF28200A);

  // ── Gradient stops ─────────────────────────────────────────────────────────
  static const List<Color> brandGradient = [indigo, violet];
  static const List<Color> oceanGradient = [oceanPrimary, Color(0xFF38BDF8)];
  static const List<Color> amberGradient = [amberPrimary, Color(0xFFFF8C42)];
  static const List<Color> violetGradient = [violet, Color(0xFF6366F1)];
  static const List<Color> darkBgGradient = [
    Color(0xFF0A0E1A),
    Color(0xFF0F1525),
  ];
  static const List<Color> glowGradient = [
    Color(0x335B6EF5),
    Color(0x008B5CF6),
  ];

  // ── Legacy seed (kept for backwards compat) ────────────────────────────────
  static const Color seed = indigo;
  static const Color surface = lightSurface;
  static const Color card = lightSurface;
  static const Color danger = error;
}
