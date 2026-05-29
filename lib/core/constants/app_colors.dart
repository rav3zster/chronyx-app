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

  // ── Warm (reference design) palette ──────────────────────────────────────
  /// Warm cream — main background
  static const Color warmBackground = Color(0xFFF2EDE4);

  /// Warm card surface
  static const Color warmSurface = Color(0xFFEDE8DF);

  /// Warm elevated card
  static const Color warmSurface2 = Color(0xFFE6E0D6);

  /// Near-black hero card
  static const Color warmHero = Color(0xFF1C1C14);

  /// Warm gold — CTA, accent, ring
  static const Color warmGold = Color(0xFFC9A84C);

  /// Warm gold light — button fill
  static const Color warmGoldLight = Color(0xFFD4B06A);

  /// Warm text primary
  static const Color warmTextPrimary = Color(0xFF1A1A14);

  /// Warm text secondary / labels
  static const Color warmTextSecondary = Color(0xFF8B7A5E);

  /// Warm text muted
  static const Color warmTextMuted = Color(0xFFB0A090);

  // ── HTML redesign palettes (4 new themes) ─────────────────────────────────

  // T1 — Warm Cream (light, gold)
  static const Color creamBg = Color(0xFFF5F0E8);
  static const Color creamSurface = Color(0xFFEDE8DE);
  static const Color creamTrack = Color(0xFFDDD8CE);
  static const Color creamHero = Color(0xFF1A1510);
  static const Color creamGold = Color(0xFFC8A96E);
  static const Color creamGoldDeep = Color(0xFFB08D5B);
  static const Color creamTextPrimary = Color(0xFF1A1510);
  static const Color creamTextSecondary = Color(0xFF9A8E80);

  // T2 — Graphite Blue (dark, electric blue)
  static const Color graphiteBg = Color(0xFF141417);
  static const Color graphiteBase = Color(0xFF0F0F12);
  static const Color graphiteSurface = Color(0xFF1A1A22);
  static const Color graphiteHero = Color(0xFF1A1A2E);
  static const Color graphiteBlue = Color(0xFF3B5BDB);
  static const Color graphiteBlueBright = Color(0xFF4C83FF);
  static const Color graphiteTextPrimary = Color(0xFFE8E8F0);
  static const Color graphiteTextSecondary = Color(0xFF6A6A80);
  static const Color graphiteBorder = Color(0xFF22222E);

  // T3 — Forest Sage (light, green)
  static const Color sageBg = Color(0xFFF2F5F0);
  static const Color sageSurface = Color(0xFFEAEDE7);
  static const Color sageTrack = Color(0xFFDDE3DA);
  static const Color sageHero = Color(0xFF1E2B1A);
  static const Color sageGreen = Color(0xFF4A9438);
  static const Color sageGreenBright = Color(0xFF6AAA54);
  static const Color sageTextPrimary = Color(0xFF1A2218);
  static const Color sageTextSecondary = Color(0xFF8A9A82);

  // T4 — Noir Rust (dark, rust orange)
  static const Color noirBg = Color(0xFF111010);
  static const Color noirBase = Color(0xFF0C0B0B);
  static const Color noirSurface = Color(0xFF1A1816);
  static const Color noirHero = Color(0xFF1E1A17);
  static const Color noirRust = Color(0xFFC85A20);
  static const Color noirRustBright = Color(0xFFD8703A);
  static const Color noirTextPrimary = Color(0xFFF0ECE8);
  static const Color noirTextSecondary = Color(0xFF6A6260);
  static const Color noirBorder = Color(0xFF252220);

  // Theme swatch gradients for the settings picker
  static const List<Color> creamGradient = [creamGold, Color(0xFFD8C29A)];
  static const List<Color> graphiteGradient = [
    graphiteBlue,
    graphiteBlueBright,
  ];
  static const List<Color> sageGradient = [sageGreen, sageGreenBright];
  static const List<Color> noirGradient = [noirRust, noirRustBright];
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
