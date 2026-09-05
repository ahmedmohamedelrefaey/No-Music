import 'package:flutter/material.dart';

/// Phase 2 design-system tokens (high-contrast dark theme).
class AppColors {
  static const primary = Color(0xFF7C3AED);
  static const primaryLight = Color(0xFFA78BFA);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const background = Color(0xFF0A0A0A);
  static const surface = Color(0xFF1A1A1A);
  static const card = Color(0xFF1F1F1F);
  static const border = Color(0xFF3F3F46);
  static const primaryText = Color(0xFFFFFFFF);
  static const secondaryText = Color(0xFFE5E7EB);
  static const helperText = Color(0xFFC4C4C8);
  static const disabledText = Color(0xFF8B8B94);
  static const errorText = Color(0xFFFCA5A5);
  static const successText = Color(0xFF6EE7B7);
}

/// Premium typography: Arabic serif (Amiri) for display headings only,
/// Cairo for Arabic body/labels, Inter for English.
class AppTypography {
  static const arDisplay = 'Amiri';
  static const arBody = 'Cairo';
  static const enBody = 'Inter';

  static TextStyle display(Locale? locale, {double size = 34}) => TextStyle(
        fontFamily: locale?.languageCode == 'ar' ? arDisplay : enBody,
        fontSize: size,
        height: 1.35,
        fontWeight: FontWeight.w700,
        color: AppColors.primaryText,
      );
}

ThemeData buildAppTheme(Locale locale) {
  final isArabic = locale.languageCode == 'ar';
  final bodyFamily = isArabic ? AppTypography.arBody : AppTypography.enBody;
  final display = AppTypography.display(locale);

  TextStyle text(double size, FontWeight weight, Color color,
          {double height = 1.55}) =>
      TextStyle(
          fontFamily: bodyFamily,
          fontSize: size,
          height: height,
          fontWeight: weight,
          color: color);

  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.dark,
    primary: AppColors.primary,
    onPrimary: AppColors.primaryText,
    secondary: AppColors.primaryLight,
    surface: AppColors.surface,
    onSurface: AppColors.primaryText,
    error: AppColors.error,
    onError: AppColors.primaryText,
    outline: AppColors.border,
    outlineVariant: AppColors.border,
    onSurfaceVariant: AppColors.helperText,
  ).copyWith(surfaceContainerHighest: AppColors.card);

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.background,
  );

  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      displayLarge: display.copyWith(fontSize: 34),
      displayMedium: display.copyWith(fontSize: 30),
      displaySmall: display.copyWith(fontSize: 26),
      headlineMedium: display.copyWith(fontSize: 28),
      headlineSmall: display.copyWith(fontSize: 26),
      titleLarge: text(19, FontWeight.w800, AppColors.primaryText),
      titleMedium: text(16, FontWeight.w700, AppColors.primaryText),
      titleSmall: text(14, FontWeight.w700, AppColors.primaryText),
      bodyLarge: text(16, FontWeight.w400, AppColors.secondaryText),
      bodyMedium: text(14, FontWeight.w400, AppColors.secondaryText),
      bodySmall: text(12, FontWeight.w400, AppColors.helperText),
      labelLarge: text(15, FontWeight.w700, AppColors.primaryText),
      labelMedium: text(12, FontWeight.w600, AppColors.helperText),
      labelSmall: text(11, FontWeight.w600, AppColors.helperText),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: text(17, FontWeight.w800, AppColors.primaryText),
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerTheme:
        const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
    iconTheme: const IconThemeData(color: AppColors.primaryText),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.primaryText,
        disabledBackgroundColor: const Color(0xFF232327),
        disabledForegroundColor: AppColors.disabledText,
        textStyle: text(15, FontWeight.w700, AppColors.primaryText),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: const BorderSide(color: AppColors.border),
        foregroundColor: AppColors.secondaryText,
        disabledForegroundColor: AppColors.disabledText,
        textStyle: text(14, FontWeight.w700, AppColors.secondaryText),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryLight,
        textStyle: text(14, FontWeight.w700, AppColors.primaryLight),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        backgroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.card),
        foregroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.primaryText
                : AppColors.secondaryText),
        side: WidgetStateProperty.resolveWith((states) => BorderSide(
            color: states.contains(WidgetState.selected)
                ? AppColors.primaryLight
                : AppColors.border)),
        textStyle: WidgetStateProperty.resolveWith((states) => text(
            14,
            FontWeight.w700,
            states.contains(WidgetState.selected)
                ? AppColors.primaryText
                : AppColors.secondaryText)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: text(18, FontWeight.w800, AppColors.primaryText),
      contentTextStyle:
          text(14, FontWeight.w400, AppColors.helperText, height: 1.7),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF26262B),
      contentTextStyle: text(13, FontWeight.w600, AppColors.primaryText),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: Color(0xFF2A2A2E),
      circularTrackColor: Color(0xFF2A2A2E),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: AppColors.secondaryText,
      titleTextStyle: text(15, FontWeight.w600, AppColors.primaryText),
      subtitleTextStyle: text(12, FontWeight.w400, AppColors.helperText),
    ),
  );
}
