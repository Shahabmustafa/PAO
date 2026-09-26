import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_links.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../l10n/l10n.dart';
import '../routes/app_navigator.dart';

/// Detects a newer Play Store version and offers it in a dialog on launch.
/// Only Android installs from Play can report this; everywhere else (and on
/// any error) nothing is shown.
class UpdateChecker {
  UpdateChecker._();

  static bool _prompted = false;

  /// Returns the Play update info, or null when none is available.
  static Future<AppUpdateInfo?> _check() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final info = await InAppUpdate.checkForUpdate();
      return info.updateAvailability == UpdateAvailability.updateAvailable
          ? info
          : null;
    } catch (_) {
      // Not installed from Play (debug/sideload) -- nothing to offer.
      return null;
    }
  }

  /// Shows the "Update your App" dialog (version, Update, Skip) once per
  /// launch when a newer version exists.
  static Future<void> checkAndPrompt() async {
    if (_prompted) return;
    final info = await _check();
    if (info == null) return;
    final context = AppNavigator.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    _prompted = true;
    final current = (await PackageInfo.fromPlatform()).version;
    if (!context.mounted) return;
    final l10n = context.l10n;
    final update = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.updateYourApp),
        content: Text(
          l10n.updateAvailableMessage(
            current,
            '${info.availableVersionCode ?? ''}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.skip),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.update),
          ),
        ],
      ),
    );
    if (update == true) await startUpdate();
  }

  /// For the always-visible Settings entry: updates in-app when Play reports
  /// a newer version, otherwise just opens the Play Store listing.
  static Future<void> openUpdate() async {
    if (await _check() != null) return startUpdate();
    await launchUrl(
      Uri.parse(AppLinks.playStore),
      mode: LaunchMode.externalApplication,
    );
  }

  static Future<void> startUpdate() async {
    try {
      await InAppUpdate.performImmediateUpdate();
    } catch (_) {
      await launchUrl(
        Uri.parse(AppLinks.playStore),
        mode: LaunchMode.externalApplication,
      );
    }
  }
}
