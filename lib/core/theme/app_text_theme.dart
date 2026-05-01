import 'package:chronyx/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized text theme builder.
/// Pass [textColor] to get a cohesive set of text styles for any theme mode.
class AppTextTheme {
  const AppTextTheme._();

  /// Returns a complete [TextTheme] using Inter + Outfit from Google Fonts.
  /// [displayColor] — used for large display / headline text
  /// [bodyColor]    — used for body / label / caption text
  static TextTheme build({
    required Color displayColor,
    required Color bodyColor,
  }) {
    final display = GoogleFonts.outfit(color: displayColor);
    final body = GoogleFonts.inter(color: bodyColor);

    return TextTheme(
      // Display
      displayLarge: display.copyWith(
        fontSize: 57,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.5,
        height: 1.12,
      ),
      displayMedium: display.copyWith(
        fontSize: 45,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
        height: 1.15,
      ),
      displaySmall: display.copyWith(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.18,
      ),
      // Headline
      headlineLarge: display.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.22,
      ),
      headlineMedium: display.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        height: 1.25,
      ),
      headlineSmall: display.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.28,
      ),
      // Title
      titleLarge: display.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        height: 1.3,
      ),
      titleMedium: body.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.35,
      ),
      titleSmall: body.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 1.4,
      ),
      // Body
      bodyLarge: body.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.5,
      ),
      bodyMedium: body.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.5,
      ),
      bodySmall: body.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
        height: 1.5,
      ),
      // Label
      labelLarge: body.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        height: 1.4,
      ),
      labelMedium: body.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
        height: 1.4,
      ),
      labelSmall: body.copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        height: 1.4,
      ),
    );
  }

  // ── Convenience getters ────────────────────────────────────────────────────

  static TextTheme get dark => build(
        displayColor: AppColors.textPrimaryDark,
        bodyColor: AppColors.textSecondaryDark,
      );

  static TextTheme get light => build(
        displayColor: AppColors.textPrimaryLight,
        bodyColor: AppColors.textSecondaryLight,
      );
}
