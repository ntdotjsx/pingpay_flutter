import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

class DarkTheme {
  static ThemeData get theme {
    final textTheme = AppTypography.createTextTheme(
      AppColors.bodyOnDark,
      AppColors.bodyMuted,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.primaryOnDark,
      scaffoldBackgroundColor: AppColors.surfaceBlack,
      cardColor: AppColors.surfaceTile1,
      dividerColor: AppColors.surfaceTile2,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryOnDark,
        onPrimary: AppColors.surfaceBlack,
        surface: AppColors.surfaceTile1,
        onSurface: AppColors.bodyOnDark,
        outline: AppColors.surfaceTile2,
        surfaceContainerHighest: AppColors.surfaceTile2,
        error: AppColors.error,
        onError: Colors.white,
      ),
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfaceBlack,
        foregroundColor: AppColors.bodyOnDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w600,
          color: AppColors.bodyOnDark,
          letterSpacing: -0.2,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryOnDark,
          foregroundColor: AppColors.surfaceBlack,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.roundedPill,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryOnDark,
          side: const BorderSide(color: AppColors.primaryOnDark, width: 1.0),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.roundedPill,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceTile1,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
        border: const OutlineInputBorder(
          borderRadius: AppRadius.roundedLg,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.roundedLg,
          borderSide: BorderSide(color: AppColors.surfaceTile2, width: 1.0),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadius.roundedLg,
          borderSide: BorderSide(color: AppColors.primaryOnDark, width: 2.0),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: AppRadius.roundedLg,
          borderSide: BorderSide(color: AppColors.error, width: 1.0),
        ),
        hintStyle: const TextStyle(color: AppColors.inkMuted48, fontSize: 15),
      ),
    );
  }
}
