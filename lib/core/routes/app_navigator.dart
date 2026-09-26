import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/ban_watcher.dart';
import 'app_routes.dart';

/// App-wide navigation that has to happen without a [BuildContext]: opening
/// the "set a new password" screen when the user taps the link in a
/// password-reset email.
class AppNavigator {
  AppNavigator._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static StreamSubscription<AuthState>? _subscription;
  static bool _ready = false;
  static bool _recoveryPending = false;

  /// Starts watching for the password-recovery sign-in that Supabase
  /// reports once the deep link from the reset email has been handled. Call
  /// once, right after `Supabase.initialize`, so a link that cold-starts the
  /// app is not missed.
  static void listenForPasswordRecovery() {
    _subscription ??= Supabase.instance.client.auth.onAuthStateChange.listen((
      state,
    ) async {
      if (state.event != AuthChangeEvent.passwordRecovery) return;
      // The reset link signs the user in without going through login(), so a
      // banned account must be rejected here or it could reset its password
      // and get in.
      if (await BanWatcher.enforceForCurrentUser()) {
        _recoveryPending = false;
        return;
      }
      _recoveryPending = true;
      if (_ready) _openResetPassword();
    });
  }

  /// Called by the splash screen when it is about to route the user on.
  /// Returns whether a reset-password link arrived while the app was still
  /// starting, and from now on opens the screen straight away.
  static bool takePendingRecovery() {
    _ready = true;
    final pending = _recoveryPending;
    _recoveryPending = false;
    return pending;
  }

  static void _openResetPassword() {
    _recoveryPending = false;
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      AppRoutes.resetPassword,
      (route) => false,
    );
  }
}
