import 'package:flutter/material.dart';

/// لوحة ألوان الهوية البصرية (الزيتوني + الأبيض) ومشتقاتها.
///
/// تُستخدم كأساس قابل للتخصيص: كل الألوان مركزية هنا
/// وترجع الإصدار المناسب حسب وضع العرض (فاتح/داكن).
class AppColors {
  AppColors._();

  // ---- الزيتوني ----
  static const Color olive = Color(0xFF556B2F);
  static const Color oliveDark = Color(0xFF354522);
  static const Color oliveLight = Color(0xFF8FA765);

  // ---- الوضع الفاتح ----
  static const Color lightBackground = Color(0xFFF7F8F4);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF20251D);
  static const Color lightBorder = Color(0xFFE3E7DB);
  static const Color lightSurface = Color(0xFFEFF2E6);
  static const Color lightTextMuted = Color(0xFF6C7462);

  // ---- الوضع الداكن ----
  static const Color darkBackground = Color(0xFF151813);
  static const Color darkCard = Color(0xFF22271F);
  static const Color darkText = Color(0xFFF1F3EC);
  static const Color darkBorder = Color(0xFF323931);
  static const Color darkSurface = Color(0xFF2B3127);
  static const Color darkTextMuted = Color(0xFFA9B09E);

  // ---- ألوان دلالية ----
  static const Color warning = Color(0xFFE8A23A);
  static const Color error = Color(0xFFD95757);
}

/// ألوان "حسب الموضع": تغلّف ألوان الوضع الحالي في كائن واحد
/// حتى لا تُستدعى `Theme.of(context).brightness` في كل سطر.
class Palette {
  const Palette._({
    required this.isDark,
    required this.background,
    required this.card,
    required this.text,
    required this.textMuted,
    required this.border,
    required this.surface,
    required this.onPrimary,
  });

  final bool isDark;
  final Color background;
  final Color card;
  final Color text;
  final Color textMuted;
  final Color border;
  final Color surface;

  /// لون الزيتوني الواضح فوق خلفيات الوضع الحالي (أفتح قليلاً في الوضع الداكن).
  final Color onPrimary;

  static const Palette light = Palette._(
    isDark: false,
    background: AppColors.lightBackground,
    card: AppColors.lightCard,
    text: AppColors.lightText,
    textMuted: AppColors.lightTextMuted,
    border: AppColors.lightBorder,
    surface: AppColors.lightSurface,
    onPrimary: AppColors.olive,
  );

  static const Palette dark = Palette._(
    isDark: true,
    background: AppColors.darkBackground,
    card: AppColors.darkCard,
    text: AppColors.darkText,
    textMuted: AppColors.darkTextMuted,
    border: AppColors.darkBorder,
    surface: AppColors.darkSurface,
    onPrimary: AppColors.oliveLight,
  );

  static Palette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}
