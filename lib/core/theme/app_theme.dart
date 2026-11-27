import 'package:fixer/core/theme/app_accent.dart';
import 'package:flutter/material.dart';

/// Neutral dark palette shared by every accent.
abstract final class AppColors {
  static const background = Color(0xFF0A0A0F);
  static const surface = Color(0xFF12121A);
  static const surfaceHigh = Color(0xFF1A1A25);
  static const outline = Color(0xFF2A2A38);
  static const text = Color(0xFFE8E8F0);
  static const textMuted = Color(0xFF9A9AB0);
  static const error = Color(0xFFFF6B81);
}

/// Spacing scale (logical pixels).
abstract final class Gap {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
}

/// Breakpoint where the Split tab shows editor and results side by side.
const wideLayoutMinWidth = 840.0;

/// Builds the app's dark theme from a single accent (Factory).
abstract final class AppThemeFactory {
  static const _bevel = BeveledRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(10)),
  );

  static ThemeData build(AppAccent accent) {
    final scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: accent.color,
      onPrimary: accent.onColor,
      secondary: accent.color,
      onSecondary: accent.onColor,
      error: AppColors.error,
      onError: AppColors.background,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      onSurfaceVariant: AppColors.textMuted,
      surfaceContainerLowest: AppColors.background,
      surfaceContainerLow: AppColors.surface,
      surfaceContainer: AppColors.surface,
      surfaceContainerHigh: AppColors.surfaceHigh,
      surfaceContainerHighest: AppColors.surfaceHigh,
      outline: AppColors.outline,
      outlineVariant: AppColors.outline,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: Brightness.dark,
    );
    final text = base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      textTheme: text.copyWith(
        titleLarge: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
        labelLarge: text.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: _bevel.copyWith(
          side: const BorderSide(color: AppColors.outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: _bevel,
          minimumSize: const Size(48, 48),
          textStyle: text.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: _bevel,
          minimumSize: const Size(48, 48),
          foregroundColor: accent.color,
          side: BorderSide(color: accent.color),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceHigh,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Gap.m,
          vertical: Gap.m,
        ),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
          borderSide: BorderSide(color: AppColors.outline),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
          borderSide: BorderSide(color: AppColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(4)),
          borderSide: BorderSide(color: accent.color, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: accent.color,
        indicatorShape: _bevel,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? accent.onColor
                : AppColors.textMuted,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: accent.color,
        indicatorShape: _bevel,
        selectedIconTheme: IconThemeData(color: accent.onColor),
        unselectedIconTheme: const IconThemeData(color: AppColors.textMuted),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.outline, space: 1),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceHigh,
        contentTextStyle: TextStyle(color: AppColors.text),
      ),
    );
  }
}

/// Text styles for money: tabular digits so columns line up.
extension AmountStyles on TextTheme {
  TextStyle get amount => (bodyLarge ?? const TextStyle()).copyWith(
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  TextStyle get amountLarge => (headlineSmall ?? const TextStyle()).copyWith(
    fontWeight: FontWeight.w700,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}
