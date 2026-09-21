import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import '../theme/app_colors.dart';

/// A branded toast (rounded, colored, with an icon), shown via the
/// `toastification` package in place of the plain default SnackBar for
/// key confirmations and errors across the app.
class AppSnackbar {
  AppSnackbar._();

  static void show(
    BuildContext context,
    String message, {
    IconData icon = Icons.check_circle,
    Color color = AppColors.primary,
  }) {
    final background = context.appSurface;
    final foreground = context.appTextPrimary;

    toastification.show(
      context: context,
      type: color == AppColors.error
          ? ToastificationType.error
          : ToastificationType.success,
      // `flatColored` ignores `backgroundColor` and paints a light tint, which
      // hides the theme-colored text in dark mode; `flat` honours it.
      style: ToastificationStyle.flat,
      alignment: Alignment.bottomCenter,
      autoCloseDuration: const Duration(seconds: 2),
      showProgressBar: false,
      dragToClose: true,
      backgroundColor: background,
      foregroundColor: foreground,
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: context.appBorder),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      icon: Icon(icon, color: color, size: 20),
      title: Text(
        message,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
    );
  }
}
