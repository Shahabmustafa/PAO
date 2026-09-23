import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/settings/data/notification_settings_store.dart';
import 'notification_router.dart';

/// Wires Firebase Cloud Messaging to the app: requests notification
/// permission, keeps `public.users.fcm_token` in sync with whoever is
/// signed in (that's how `supabase/functions/push/index.ts` knows which
/// device to deliver to -- see `supabase/users_add_fcm_token.sql`), and
/// routes a tapped notification to the right tab.
///
/// `supabase/functions/push/index.ts` sends a hybrid FCM payload (both
/// `notification` and `data`). That means:
///   - Background / terminated: the OS shows the notification itself from
///     the `notification` block -- native, reliable, no Dart code involved.
///   - Foreground: neither Android nor iOS shows anything on their own for
///     *any* FCM message while the app is running, and we deliberately don't
///     add one -- no notification while the app is open.
///
/// Call [initialize] once, right after `Firebase.initializeApp()`.
class PushNotificationService {
  PushNotificationService._();

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'push_default',
    'General',
    description: 'New messages and requests',
    importance: Importance.high,
  );

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _localNotifications.initialize(
      // ic_notification: a plain white "PAO" silhouette (see
      // android/app/src/main/res/drawable-*dpi/ic_notification.png), not
      // the full-color launcher icon -- Android can only render a status
      // bar icon from its alpha channel, so a solid, non-transparent icon
      // like the launcher one just shows as a filled block.
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) =>
          _handleTap(response.payload),
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();

    final auth = Supabase.instance.client.auth;
    if (auth.currentUser != null) {
      await _saveToken(await messaging.getToken());
    }
    messaging.onTokenRefresh.listen(_saveToken);

    auth.onAuthStateChange.listen((state) async {
      switch (state.event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.tokenRefreshed:
        case AuthChangeEvent.userUpdated:
          await _saveToken(await messaging.getToken());
          break;
        case AuthChangeEvent.signedOut:
          // Detach this device from the account that just signed out, so it
          // stops receiving that account's notifications.
          await _clearTokenForPreviousUser();
          break;
        default:
          break;
      }
    });

    // Settings > Notifications toggle: mirror it server-side by
    // saving/clearing this device's fcm_token, so a disabled device gets no
    // push at all rather than just suppressing the in-app banner below.
    NotificationSettingsStore.enabled.addListener(_handleSettingChanged);

    // Foreground: intentionally show nothing -- the user is already in the
    // app, and chat/requests update live via realtime.

    // Tapped while backgrounded (the OS's own notification).
    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _handleTap(jsonEncode(message.data)),
    );
    // Tapped from a fully terminated state (cold start), same source.
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleTap(jsonEncode(initialMessage.data));
    }

    // Tapped from a fully terminated state, on a notification *we* showed
    // (the app was foregrounded when it arrived, then closed without
    // opening it).
    final launchDetails = await _localNotifications
        .getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      _handleTap(launchDetails!.notificationResponse?.payload);
    }
  }

  static String? _lastKnownUserId;

  static Future<void> _saveToken(String? token) async {
    if (!NotificationSettingsStore.enabled.value) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (token == null || user == null) return;
    _lastKnownUserId = user.id;
    try {
      await Supabase.instance.client
          .from('users')
          .update({'fcm_token': token})
          .eq('id', user.id);
    } catch (e) {
      debugPrint('Failed to save FCM token: $e');
    }
  }

  static Future<void> _clearToken(String userId) async {
    try {
      await Supabase.instance.client
          .from('users')
          .update({'fcm_token': null})
          .eq('id', userId);
    } catch (e) {
      debugPrint('Failed to clear FCM token: $e');
    }
  }

  static Future<void> _clearTokenForPreviousUser() async {
    final userId = _lastKnownUserId;
    _lastKnownUserId = null;
    if (userId == null) return;
    await _clearToken(userId);
  }

  /// Reacts to the Settings > Notifications toggle: clears this device's
  /// token when turned off (so the backend has nothing to send to), and
  /// re-registers it when turned back on.
  static Future<void> _handleSettingChanged() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    if (NotificationSettingsStore.enabled.value) {
      await _saveToken(await FirebaseMessaging.instance.getToken());
    } else {
      await _clearToken(user.id);
    }
  }

  static void _handleTap(String? payload) {
    if (payload == null || payload.isEmpty) return;
    Map<String, dynamic> data;
    try {
      data = jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final type = data['type'] as String?;
    final requestId = data['request_id'] as String?;
    if ((type == 'message' || type == 'request') && requestId != null) {
      NotificationRouter.openChat(requestId);
    }
  }
}
