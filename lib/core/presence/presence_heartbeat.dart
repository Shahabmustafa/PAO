import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Keeps `public.users.last_seen_at` fresh for the signed-in account while
/// the app is in the foreground, so other users can see this device's
/// online / last-seen status in chat (see `ChatProvider.otherProfile` and
/// `supabase/users_add_last_seen.sql`).
///
/// There's no presence/realtime channel for this on purpose -- the rest of
/// the app already treats profile fields (name, avatar) as polled, not
/// live, data, so a periodic heartbeat matches that and needs no extra RLS.
class PresenceHeartbeat with WidgetsBindingObserver {
  PresenceHeartbeat._();

  static final PresenceHeartbeat _instance = PresenceHeartbeat._();

  static const _interval = Duration(seconds: 45);

  Timer? _timer;

  static void initialize() {
    WidgetsBinding.instance.addObserver(_instance);

    final auth = Supabase.instance.client.auth;
    if (auth.currentUser != null) _instance._start();

    auth.onAuthStateChange.listen((state) {
      switch (state.event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.tokenRefreshed:
        case AuthChangeEvent.userUpdated:
          _instance._start();
          break;
        case AuthChangeEvent.signedOut:
          _instance._stop();
          break;
        default:
          break;
      }
    });
  }

  void _start() {
    unawaited(_touch());
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => _touch());
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _touch() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      await Supabase.instance.client
          .from('users')
          .update({'last_seen_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', user.id);
    } catch (_) {
      // Best-effort; a missed heartbeat just shows a slightly stale status.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (Supabase.instance.client.auth.currentUser != null) _start();
    } else {
      _stop();
    }
  }
}
