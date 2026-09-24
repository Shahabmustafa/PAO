import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFFAEF503);
  static const Color onPrimary = Color(0xFF000000);
  static const Color primaryDark = Color(0xFF2843C9);
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1B1D28);
  static const Color textSecondary = Color(0xFF7C7F8E);
  static const Color border = Color(0xFFE3E5EE);
  static const Color error = Color(0xFFE0473E);
}

class AppColorsDark {
  AppColorsDark._();

  static const Color background = Color(0xFF14151C);
  static const Color surface = Color(0xFF1E2029);
  static const Color textPrimary = Color(0xFFF2F2F5);
  static const Color textSecondary = Color(0xFF9497A6);
  static const Color border = Color(0xFF2C2E3A);
}

/// Resolves the light/dark variant of a color for the current [BuildContext],
/// since [AppColors] and [AppColorsDark] are fixed constants on their own.
extension AppColorsContext on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get appBackground =>
      isDarkMode ? AppColorsDark.background : AppColors.background;
  Color get appSurface =>
      isDarkMode ? AppColorsDark.surface : AppColors.surface;
  Color get appTextPrimary =>
      isDarkMode ? AppColorsDark.textPrimary : AppColors.textPrimary;
  Color get appTextSecondary =>
      isDarkMode ? AppColorsDark.textSecondary : AppColors.textSecondary;
  Color get appBorder => isDarkMode ? AppColorsDark.border : AppColors.border;
}
