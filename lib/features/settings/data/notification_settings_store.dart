import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the user wants to receive push notifications, toggled from
/// Settings. Persisted locally so the choice survives an app restart.
/// [PushNotificationService] watches [enabled] and mirrors it server-side by
/// clearing/restoring `public.users.fcm_token`, so a disabled device
/// receives nothing at all -- not just a suppressed in-app banner.
class NotificationSettingsStore {
  NotificationSettingsStore._();

  static const _prefsKey = 'notifications_enabled';

  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(true);

  /// Loads the previously saved preference from local storage, if any. Call
  /// once, before [PushNotificationService.initialize], so the right value
  /// applies from the first frame.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    enabled.value = prefs.getBool(_prefsKey) ?? true;
  }

  static Future<void> setEnabled(bool value) async {
    enabled.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
  }
}
