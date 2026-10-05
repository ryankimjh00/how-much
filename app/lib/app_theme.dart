import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFFFFF9EF);
  static const surface = Color(0xFFFFFDF8);
  static const primary = Color(0xFFF57C00);
  static const checked = primary;
  static const secondary = Color(0xFFFFE8CC);
  static const ink = Color(0xFF30251F);
  static const body = Color(0xFF5A4A42);
  static const muted = Color(0xFF88796F);
  static const border = Color(0xFFE8DED1);
  static const coral = Color(0xFFB95000);
  static const note = Color(0xFFFFF2C7);
  static const noteBorder = Color(0xFFE8CF86);
  static const camera = Color(0xFF3B2118);
  static const error = Color(0xFFB13A2A);
  static const errorSurface = Color(0xFFFFE9E1);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
    primary: AppColors.primary,
    secondary: AppColors.coral,
    surface: AppColors.surface,
    error: AppColors.error,
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'NotoSansKR',
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontFamily: 'Jua',
        fontSize: 30,
        height: 1.3,
        fontWeight: FontWeight.w400,
        color: AppColors.ink,
      ),
      headlineSmall: TextStyle(
        fontFamily: 'Jua',
        fontSize: 20,
        height: 1.4,
        fontWeight: FontWeight.w400,
        color: AppColors.ink,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: AppColors.body),
      bodyMedium: TextStyle(fontSize: 14, height: 1.55, color: AppColors.body),
      bodySmall: TextStyle(fontSize: 12, height: 1.4, color: AppColors.muted),
      labelLarge: TextStyle(
        fontFamily: 'NotoSansKR',
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Jua',
        fontSize: 23,
        color: AppColors.ink,
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: AppColors.error, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontFamily: 'NotoSansKR',
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(
          fontFamily: 'NotoSansKR',
          fontWeight: FontWeight.w500,
        ),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: const BorderSide(color: AppColors.border),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.ink,
      contentTextStyle: TextStyle(color: Colors.white),
      actionTextColor: AppColors.secondary,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
