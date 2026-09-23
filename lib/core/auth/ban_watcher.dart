import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../l10n/l10n.dart';
import '../realtime/realtime_event.dart';
import '../realtime/realtime_table_stream.dart';
import '../routes/app_navigator.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/app_snackbar.dart';

/// Watches the signed-in account's `public.users.is_banned` flag and signs
/// the device out the moment it becomes true while the app is open (a
/// realtime UPDATE on the account's own row, see
/// `supabase/users_add_ban_realtime.sql`).
///
/// `AuthRepository.login` separately rejects a banned account trying to
/// sign in fresh, so this deliberately does *not* re-check right after a
/// plain sign-in -- doing so raced the login screen's own rejection and
/// showed the "suspended" message twice. It still does an explicit one-shot
/// check for a session that was already active before this launch (cold
/// start) and after any reconnect (a dropped realtime connection loses
/// events from while it was down).
class BanWatcher {
  BanWatcher._();

  static final BanWatcher _instance = BanWatcher._();

  StreamSubscription<RealtimeEvent<Map<String, dynamic>>>? _subscription;

  static void initialize() {
    final auth = Supabase.instance.client.auth;
    final currentId = auth.currentUser?.id;
    if (currentId != null) {
      _instance._start(currentId);
      _instance._checkNow(currentId);
    }

    auth.onAuthStateChange.listen((state) {
      switch (state.event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.tokenRefreshed:
          final id = state.session?.user.id;
          if (id != null) _instance._start(id);
          break;
        case AuthChangeEvent.signedOut:
          _instance._stop();
          break;
        default:
          break;
      }
    });
  }

  void _start(String userId) {
    _subscription?.cancel();
    _subscription =
        watchTable(
          Supabase.instance.client,
          channelName: 'ban_watch',
          table: 'users',
          bindings: [
            RealtimeBinding(
              event: PostgresChangeEvent.update,
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'id',
                value: userId,
              ),
            ),
          ],
        ).listen((event) {
          switch (event.type) {
            // Only a *re*-join (isReconnect) needs a manual re-check --
            // events raised while the socket was down are otherwise lost.
            // The first join right after sign-in skips it: AuthRepository
            // just did this exact check as part of login().
            case RealtimeEventType.subscribed:
              if (event.isReconnect) _checkNow(userId);
              break;
            case RealtimeEventType.update:
              if (event.record?['is_banned'] == true) _forceLogout();
              break;
            default:
              break;
          }
        });
  }

  void _stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _checkNow(String userId) async {
    try {
      final row = await Supabase.instance.client
          .from('users')
          .select('is_banned')
          .eq('id', userId)
          .maybeSingle();
      if (row?['is_banned'] == true) _forceLogout();
    } catch (_) {
      // Best-effort; the next reconnect or sign-in tries again.
    }
  }

  Future<void> _forceLogout() async {
    _stop();
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      // Signing out locally still protects the device even if the network
      // call fails; the token is cleared either way.
    }
    AppNavigator.navigatorKey.currentState?.pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
    final context = AppNavigator.navigatorKey.currentContext;
    if (context != null) {
      AppSnackbar.show(
        context,
        l10nNow.errorAccountBanned,
        icon: Icons.block,
        color: AppColors.error,
      );
    }
  }
}
