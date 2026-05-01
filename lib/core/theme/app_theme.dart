import 'package:chronyx/core/constants/app_colors.dart';
import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/theme/app_text_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The single source of truth for all [ThemeData] in Chronyx.
///
/// Usage:
/// ```dart
/// MaterialApp(
///   theme: AppTheme.light,
///   darkTheme: AppTheme.dark,
///   themeMode: ThemeMode.dark,
/// )
/// ```
class AppTheme {
  const AppTheme._();

  // ── Dark (default, premium) ────────────────────────────────────────────────

  static ThemeData get dark {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      // Brand
      primary: AppColors.indigo,
      onPrimary: Color(0xFFF1F4FF),
      primaryContainer: Color(0xFF1E2652),
      onPrimaryContainer: Color(0xFFCDD5FF),
      // Secondary
      secondary: AppColors.violet,
      onSecondary: Color(0xFFF1F4FF),
      secondaryContainer: Color(0xFF2D1F52),
      onSecondaryContainer: Color(0xFFDDD0FF),
      // Tertiary
      tertiary: AppColors.cyan,
      onTertiary: Color(0xFF001F26),
      tertiaryContainer: Color(0xFF003640),
      onTertiaryContainer: Color(0xFFA8EEFF),
      // Error
      error: AppColors.error,
      onError: Color(0xFF1A0010),
      errorContainer: Color(0xFF3D0020),
      onErrorContainer: Color(0xFFFFD9E2),
      // Surface
      surface: AppColors.darkSurface,
      onSurface: AppColors.textPrimaryDark,
      surfaceContainerHighest: AppColors.darkSurface3,
      onSurfaceVariant: AppColors.textSecondaryDark,
      // Outline
      outline: AppColors.darkBorder,
      outlineVariant: AppColors.darkBorderSubtle,
      // Inverse
      inverseSurface: AppColors.lightSurface,
      onInverseSurface: AppColors.textPrimaryLight,
      inversePrimary: AppColors.indigoDark,
      // Shadow / scrim
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

  // ── Light ──────────────────────────────────────────────────────────────────

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

  // ── Accent (Dark with violet shift) ───────────────────────────────────────

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

      // ── AppBar ──────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: systemOverlayStyle,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),

      // ── Card ────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerHighest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Elevated Button ────────────────────────────────────────────────
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

      // ── Filled Button ──────────────────────────────────────────────────
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

      // ── Outlined Button ────────────────────────────────────────────────
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

      // ── Input Decoration ───────────────────────────────────────────────
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
          color: scheme.onSurfaceVariant.withOpacity(0.6),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),

      // ── Divider ────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      // ── Snackbar ───────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.darkSurface3 : AppColors.darkSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.textPrimaryDark,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // ── ListTile ───────────────────────────────────────────────────────
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

      // ── Icon ───────────────────────────────────────────────────────────
      iconTheme: IconThemeData(
        color: scheme.onSurfaceVariant,
        size: AppSpacing.iconLg,
      ),
    );
  }
}
