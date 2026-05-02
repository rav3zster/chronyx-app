import 'package:chronyx/core/constants/app_colors.dart';
import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/theme/app_text_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The single source of truth for all [ThemeData] in Chronyx.
class AppTheme {
  const AppTheme._();

  // ── Dark (Cosmic Dark — default, premium) ──────────────────────────────────

  static ThemeData get dark {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.indigo,
      onPrimary: Color(0xFFF1F4FF),
      primaryContainer: Color(0xFF1E2652),
      onPrimaryContainer: Color(0xFFCDD5FF),
      secondary: AppColors.violet,
      onSecondary: Color(0xFFF1F4FF),
      secondaryContainer: Color(0xFF2D1F52),
      onSecondaryContainer: Color(0xFFDDD0FF),
      tertiary: AppColors.cyan,
      onTertiary: Color(0xFF001F26),
      tertiaryContainer: Color(0xFF003640),
      onTertiaryContainer: Color(0xFFA8EEFF),
      error: AppColors.error,
      onError: Color(0xFF1A0010),
      errorContainer: Color(0xFF3D0020),
      onErrorContainer: Color(0xFFFFD9E2),
      surface: AppColors.darkSurface,
      onSurface: AppColors.textPrimaryDark,
      surfaceContainerHighest: AppColors.darkSurface3,
      onSurfaceVariant: AppColors.textSecondaryDark,
      outline: AppColors.darkBorder,
      outlineVariant: AppColors.darkBorderSubtle,
      inverseSurface: AppColors.lightSurface,
      onInverseSurface: AppColors.textPrimaryLight,
      inversePrimary: AppColors.indigoDark,
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
    );
    return _buildTheme(
      scheme: scheme,
      textTheme: AppTextTheme.dark,
      scaffoldBg: AppColors.darkBackground,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    );
  }

  // ── Light (Light Clean) ────────────────────────────────────────────────────

  static ThemeData get light {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.indigo,
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFDDE3FF),
      onPrimaryContainer: Color(0xFF1A2680),
      secondary: AppColors.violet,
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFECDCFF),
      onSecondaryContainer: Color(0xFF280060),
      tertiary: AppColors.cyan,
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFFB8F0FF),
      onTertiaryContainer: Color(0xFF001F26),
      error: AppColors.error,
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF410002),
      surface: AppColors.lightSurface,
      onSurface: AppColors.textPrimaryLight,
      surfaceContainerHighest: AppColors.lightSurface3,
      onSurfaceVariant: AppColors.textSecondaryLight,
      outline: AppColors.lightBorder,
      outlineVariant: AppColors.lightBorderSubtle,
      inverseSurface: AppColors.darkSurface,
      onInverseSurface: AppColors.textPrimaryDark,
      inversePrimary: AppColors.indigo,
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
    );
    return _buildTheme(
      scheme: scheme,
      textTheme: AppTextTheme.light,
      scaffoldBg: AppColors.lightBackground,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    );
  }

  // ── Accent (Violet Dream — dark with violet shift) ─────────────────────────

  static ThemeData get accent {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.violet,
      onPrimary: Color(0xFFF1F4FF),
      primaryContainer: Color(0xFF2D1F52),
      onPrimaryContainer: Color(0xFFDDD0FF),
      secondary: AppColors.cyan,
      onSecondary: Color(0xFF001F26),
      secondaryContainer: Color(0xFF003640),
      onSecondaryContainer: Color(0xFFA8EEFF),
      tertiary: AppColors.indigo,
      onTertiary: Color(0xFFF1F4FF),
      tertiaryContainer: Color(0xFF1E2652),
      onTertiaryContainer: Color(0xFFCDD5FF),
      error: AppColors.error,
      onError: Color(0xFF1A0010),
      errorContainer: Color(0xFF3D0020),
      onErrorContainer: Color(0xFFFFD9E2),
      surface: Color(0xFF100A1E),
      onSurface: AppColors.textPrimaryDark,
      surfaceContainerHighest: Color(0xFF1E1535),
      onSurfaceVariant: AppColors.textSecondaryDark,
      outline: Color(0xFF2E2050),
      outlineVariant: Color(0xFF1E1535),
      inverseSurface: AppColors.lightSurface,
      onInverseSurface: AppColors.textPrimaryLight,
      inversePrimary: AppColors.violet,
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
    );
    return _buildTheme(
      scheme: scheme,
      textTheme: AppTextTheme.dark,
      scaffoldBg: const Color(0xFF08050F),
      systemOverlayStyle: SystemUiOverlayStyle.light,
    );
  }

  // ── Ocean (Midnight Ocean — deep teal/cyan on dark navy) ──────────────────

  static ThemeData get ocean {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.oceanPrimary,
      onPrimary: Color(0xFFF0FEFF),
      primaryContainer: Color(0xFF063A42),
      onPrimaryContainer: Color(0xFFA8EEFF),
      secondary: Color(0xFF38BDF8),
      onSecondary: Color(0xFF001F2B),
      secondaryContainer: Color(0xFF002D3D),
      onSecondaryContainer: Color(0xFFB3E7FF),
      tertiary: AppColors.indigo,
      onTertiary: Color(0xFFF1F4FF),
      tertiaryContainer: Color(0xFF1E2652),
      onTertiaryContainer: Color(0xFFCDD5FF),
      error: AppColors.error,
      onError: Color(0xFF1A0010),
      errorContainer: Color(0xFF3D0020),
      onErrorContainer: Color(0xFFFFD9E2),
      surface: AppColors.oceanSurface,
      onSurface: Color(0xFFE0F7FA),
      surfaceContainerHighest: AppColors.oceanSurface3,
      onSurfaceVariant: Color(0xFF7ABCC6),
      outline: Color(0xFF1C3D44),
      outlineVariant: Color(0xFF112830),
      inverseSurface: Color(0xFFE0F7FA),
      onInverseSurface: Color(0xFF00171C),
      inversePrimary: AppColors.oceanPrimary,
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
    );
    return _buildTheme(
      scheme: scheme,
      textTheme: AppTextTheme.build(
        displayColor: const Color(0xFFE0F7FA),
        bodyColor: const Color(0xFF7ABCC6),
      ),
      scaffoldBg: AppColors.oceanBackground,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    );
  }

  // ── Amber (Sunset Amber — warm amber on near-black) ────────────────────────

  static ThemeData get amber {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.amberPrimary,
      onPrimary: Color(0xFF1A0F00),
      primaryContainer: Color(0xFF3D2800),
      onPrimaryContainer: Color(0xFFFFDFA3),
      secondary: Color(0xFFFF8C42),
      onSecondary: Color(0xFF200E00),
      secondaryContainer: Color(0xFF402300),
      onSecondaryContainer: Color(0xFFFFDBC0),
      tertiary: Color(0xFFFBD059),
      onTertiary: Color(0xFF1C1400),
      tertiaryContainer: Color(0xFF3A2C00),
      onTertiaryContainer: Color(0xFFFFE985),
      error: AppColors.error,
      onError: Color(0xFF1A0010),
      errorContainer: Color(0xFF3D0020),
      onErrorContainer: Color(0xFFFFD9E2),
      surface: AppColors.amberSurface,
      onSurface: Color(0xFFFFF3E0),
      surfaceContainerHighest: AppColors.amberSurface3,
      onSurfaceVariant: Color(0xFFBFA880),
      outline: Color(0xFF40300A),
      outlineVariant: Color(0xFF281E05),
      inverseSurface: Color(0xFFFFF3E0),
      onInverseSurface: Color(0xFF1A0F00),
      inversePrimary: AppColors.amberPrimary,
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
    );
    return _buildTheme(
      scheme: scheme,
      textTheme: AppTextTheme.build(
        displayColor: const Color(0xFFFFF3E0),
        bodyColor: const Color(0xFFBFA880),
      ),
      scaffoldBg: AppColors.amberBackground,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    );
  }

  // ── Shared builder ─────────────────────────────────────────────────────────

  static ThemeData _buildTheme({
    required ColorScheme scheme,
    required TextTheme textTheme,
    required Color scaffoldBg,
    required SystemUiOverlayStyle systemOverlayStyle,
  }) {
    final isDark = scheme.brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: scaffoldBg,

      // ── AppBar ────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: systemOverlayStyle,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),

      // ── NavigationBar (M3) ────────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark
            ? scheme.surface.withValues(alpha: 0.92)
            : scheme.surface.withValues(alpha: 0.96),
        indicatorColor: scheme.primary.withValues(alpha: 0.18),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: scheme.primary, size: AppSpacing.iconLg);
          }
          return IconThemeData(
            color: scheme.onSurfaceVariant,
            size: AppSpacing.iconLg,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelSmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
            );
          }
          return textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          );
        }),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),

      // ── Card ─────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerHighest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Elevated Button ──────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(double.infinity, AppSpacing.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          elevation: 0,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),

      // ── Filled Button ────────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(double.infinity, AppSpacing.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          elevation: 0,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),

      // ── Outlined Button ──────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: const Size(double.infinity, AppSpacing.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          side: BorderSide(color: scheme.outline),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),

      // ── Input Decoration ─────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? AppColors.darkSurface2
            : AppColors.lightSurface2,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: scheme.error),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),

      // ── Divider ──────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      // ── Snackbar ─────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor:
            isDark ? AppColors.darkSurface3 : AppColors.darkSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.textPrimaryDark,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // ── ListTile ─────────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),

      // ── Icon ─────────────────────────────────────────────────────────────
      iconTheme: IconThemeData(
        color: scheme.onSurfaceVariant,
        size: AppSpacing.iconLg,
      ),

      // ── FloatingActionButton ─────────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
      ),
    );
  }
}
