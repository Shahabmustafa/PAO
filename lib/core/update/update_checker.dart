import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_links.dart';
import '../l10n/l10n.dart';
import '../routes/app_navigator.dart';
import '../widgets/app_dialog.dart';

/// Detects a newer Play Store version so the home screen can show an
/// "Update your App" prompt -- most people never open the Play Store.
/// Only Android installs from Play can report this; everywhere else (and on
/// any error) [updateAvailable] stays false.
class UpdateChecker {
  UpdateChecker._();

  static final ValueNotifier<bool> updateAvailable = ValueNotifier(false);

  static bool _flexibleStarted = false;

  static Future<void> check() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final info = await InAppUpdate.checkForUpdate();
      updateAvailable.value =
          info.updateAvailability == UpdateAvailability.updateAvailable;
      if (updateAvailable.value && info.flexibleUpdateAllowed) {
        _startFlexible();
      }
    } catch (_) {
      // Not installed from Play (debug/sideload) -- nothing to offer.
    }
  }

  /// Play's own flexible flow: Google asks the user once, downloads in the
  /// background, and we offer a restart when it is ready. Once per launch.
  static Future<void> _startFlexible() async {
    if (_flexibleStarted) return;
    _flexibleStarted = true;
    try {
      InAppUpdate.installUpdateListener.listen((status) {
        if (status == InstallStatus.downloaded) _offerRestart();
      });
      await InAppUpdate.startFlexibleUpdate();
    } catch (_) {
      // Declined or failed; the "Update your App" pill stays available.
    }
  }

  static Future<void> _offerRestart() async {
    final context = AppNavigator.navigatorKey.currentContext;
    if (context == null) return;
    final l10n = context.l10n;
    final restart = await AppDialog.confirm(
      context,
      title: l10n.updateReadyTitle,
      message: l10n.updateReadyMessage,
      confirmText: l10n.restartToUpdate,
      cancelText: l10n.cancel,
    );
    if (restart) await InAppUpdate.completeFlexibleUpdate();
  }

  /// For the always-visible Settings entry: updates in-app when Play reports
  /// a newer version, otherwise just opens the Play Store listing.
  static Future<void> openUpdate() async {
    await check();
    if (updateAvailable.value) return startUpdate();
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
