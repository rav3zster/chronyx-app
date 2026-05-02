import 'package:chronyx/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// All available visual themes for Chronyx.
enum AppThemeVariant {
  cosmicDark('Cosmic Dark', Icons.dark_mode_rounded),
  lightClean('Light Clean', Icons.light_mode_rounded),
  violetDream('Violet Dream', Icons.auto_awesome_rounded),
  midnightOcean('Midnight Ocean', Icons.water_rounded),
  sunsetAmber('Sunset Amber', Icons.wb_sunny_rounded);

  const AppThemeVariant(this.label, this.icon);
  final String label;
  final IconData icon;
}

class ThemeNotifier extends StateNotifier<AppThemeVariant> {
  ThemeNotifier() : super(AppThemeVariant.cosmicDark);

  void setTheme(AppThemeVariant variant) => state = variant;
}

final themeProvider =
    StateNotifierProvider<ThemeNotifier, AppThemeVariant>(
  (ref) => ThemeNotifier(),
);

/// Resolved [ThemeData] for the currently selected variant.
final resolvedThemeProvider = Provider<ThemeData>((ref) {
  final variant = ref.watch(themeProvider);
  return switch (variant) {
    AppThemeVariant.cosmicDark => AppTheme.dark,
    AppThemeVariant.lightClean => AppTheme.light,
    AppThemeVariant.violetDream => AppTheme.accent,
    AppThemeVariant.midnightOcean => AppTheme.ocean,
    AppThemeVariant.sunsetAmber => AppTheme.amber,
  };
});
