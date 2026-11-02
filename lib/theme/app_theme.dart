import 'package:flutter/material.dart';

import 'app_colors.dart';

/// بناء ثيمي التطبيق (فاتح/داكن) من لوحة الألوان الزيتونية.
///
/// كل عناصر الواجهة تستمد ألوانها تلقائياً من [ColorScheme]
/// بحيث يتحول التطبيق بلا شروط لكنّة عند تغيير وضع العرض.
class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(brightness: Brightness.light);

  static ThemeData dark() => _build(brightness: Brightness.dark);

  static ThemeData _build({required Brightness brightness}) {
    final bool isDark = brightness == Brightness.dark;

    final Color primary = isDark ? AppColors.oliveLight : AppColors.olive;
    final Color background =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final Color card = isDark ? AppColors.darkCard : AppColors.lightCard;
    final Color text = isDark ? AppColors.darkText : AppColors.lightText;
    final Color textMuted =
        isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final Color border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final Color surface =
        isDark ? AppColors.darkSurface : AppColors.lightSurface;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: isDark ? AppColors.oliveDark : Colors.white,
      secondary: isDark ? AppColors.oliveLight : AppColors.oliveDark,
      onSecondary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      surface: card,
      onSurface: text,
      surfaceContainerHighest: surface,
      outline: border,
      onSurfaceVariant: textMuted,
    );

    final baseTextTheme = Typography.material2021(colorScheme: colorScheme)
        .black
        .apply(bodyColor: text, displayColor: text);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: baseTextTheme,
      cardTheme: CardThemeData(
        color: card,
        elevation: isDark ? 0 : 1,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shadowColor: Colors.black.withOpacity(isDark ? 0 : 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: text,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(color: textMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor:
              isDark ? AppColors.darkSurface : AppColors.lightSurface,
          disabledForegroundColor: textMuted,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary.withOpacity(0.5)),
          minimumSize: const Size(0, 42),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return textMuted;
          if (states.contains(WidgetState.selected)) return Colors.white;
          return isDark ? AppColors.darkTextMuted : Colors.grey.shade300;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return surface;
          }
          if (states.contains(WidgetState.selected)) return primary;
          return isDark ? AppColors.darkBorder : AppColors.lightBorder;
        }),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        indicatorColor: primary.withOpacity(0.14),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final bool selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? primary : textMuted,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        labelStyle: TextStyle(color: text, fontSize: 12),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.oliveDark,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: surface,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: primary,
        dense: true,
      ),
    );
  }
}
