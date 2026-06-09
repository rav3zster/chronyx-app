import 'package:chronyx/core/theme/app_theme.dart';
import 'package:chronyx/features/settings/presentation/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// All available visual themes for Chronyx.
enum AppThemeVariant {
  warmMinimal('Warm Minimal', Icons.wb_sunny_outlined),
  cosmicDark('Cosmic Dark', Icons.dark_mode_rounded),
  lightClean('Light Clean', Icons.light_mode_rounded),
  violetDream('Violet Dream', Icons.auto_awesome_rounded),
  midnightOcean('Midnight Ocean', Icons.water_rounded),
  sunsetAmber('Sunset Amber', Icons.wb_sunny_rounded),
  warmCream('Warm Cream', Icons.local_cafe_outlined),
  graphiteBlue('Graphite Blue', Icons.bolt_outlined),
  forestSage('Forest Sage', Icons.eco_outlined),
  noirRust('Noir Rust', Icons.local_fire_department_outlined);

  const AppThemeVariant(this.label, this.icon);
  final String label;
  final IconData icon;
}

class ThemeNotifier extends StateNotifier<AppThemeVariant> {
  final Ref _ref;

  // Warm Minimal is now the default — matches the reference design.
  ThemeNotifier(this._ref) : super(AppThemeVariant.warmMinimal) {
    state = _ref.read(settingsProvider).themeVariant;
  }

  void setTheme(AppThemeVariant variant) {
    state = variant;
    _ref.read(settingsProvider.notifier).setThemeVariant(variant);
  }

  void updateFromSettings(AppThemeVariant variant) {
    if (state != variant) {
      state = variant;
    }
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, AppThemeVariant>(
  (ref) {
    final notifier = ThemeNotifier(ref);
    ref.listen<SettingsState>(settingsProvider, (previous, next) {
      notifier.updateFromSettings(next.themeVariant);
    });
    return notifier;
  },
);

/// Resolved [ThemeData] for the currently selected variant.
final resolvedThemeProvider = Provider<ThemeData>((ref) {
  final variant = ref.watch(themeProvider);
  final isAmoled = ref.watch(settingsProvider.select((s) => s.amoledMode));

  final baseTheme = switch (variant) {
    AppThemeVariant.warmMinimal => AppTheme.warm,
    AppThemeVariant.cosmicDark => AppTheme.dark,
    AppThemeVariant.lightClean => AppTheme.light,
    AppThemeVariant.violetDream => AppTheme.accent,
    AppThemeVariant.midnightOcean => AppTheme.ocean,
    AppThemeVariant.sunsetAmber => AppTheme.amber,
    AppThemeVariant.warmCream => AppTheme.warmCream,
    AppThemeVariant.graphiteBlue => AppTheme.graphiteBlue,
    AppThemeVariant.forestSage => AppTheme.forestSage,
    AppThemeVariant.noirRust => AppTheme.noirRust,
  };

  if (isAmoled && baseTheme.brightness == Brightness.dark) {
    return baseTheme.copyWith(
      scaffoldBackgroundColor: Colors.black,
      colorScheme: baseTheme.colorScheme.copyWith(
        surface: Colors.black,
        surfaceContainerHighest: const Color(0xFF101010),
      ),
      inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
        fillColor: Colors.black,
      ),
    );
  }
  return baseTheme;
});
