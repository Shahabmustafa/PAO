import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../firebase_options.dart';
import '../config/supabase_config.dart';

/// Chat-message notifications with an inline "Reply" box.
///
/// `supabase/functions/push/index.ts` sends chat messages as *data-only* FCM
/// messages (Android). Because the OS can't attach a reply box to a
/// notification it draws itself, the app draws it instead: this file's
/// [pushBackgroundMessageHandler] runs while the app is backgrounded or
/// closed, shows the notification with a Reply action, and
/// [notificationBackgroundResponseHandler] sends the typed reply straight to
/// Supabase without opening the app.
class MessageNotifications {
  MessageNotifications._();

  static const channel = AndroidNotificationChannel(
    'push_default',
    'General',
    description: 'New messages and requests',
    importance: Importance.high,
  );

  static const replyActionId = 'reply';

  /// iOS category (matched by `apns.payload.aps.category` in the edge
  /// function) that carries the text-input Reply action.
  static const iosCategory = 'chat_message';

  static final initSettings = InitializationSettings(
    // ic_notification: see PushNotificationService.
    android: const AndroidInitializationSettings('ic_notification'),
    iOS: DarwinInitializationSettings(
      notificationCategories: [
        DarwinNotificationCategory(
          iosCategory,
          actions: [
            DarwinNotificationAction.text(
              replyActionId,
              'Reply',
              buttonTitle: 'Send',
              placeholder: 'Message',
            ),
          ],
        ),
      ],
    ),
  );

  /// One notification per chat partner, so new messages replace each other.
  static int _idFor(String senderId) => senderId.hashCode & 0x7fffffff;

  /// Draws the notification for a data-only chat message.
  static Future<void> show(
    FlutterLocalNotificationsPlugin plugin,
    Map<String, dynamic> data,
  ) async {
    final senderId = data['sender_id'] as String?;
    if (senderId == null || senderId.isEmpty) return;
    await plugin.show(
      id: _idFor(senderId),
      title: data['title'] as String? ?? 'New message',
      body: data['body'] as String?,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_notification',
          actions: const [
            AndroidNotificationAction(
              replyActionId,
              'Reply',
              inputs: [AndroidNotificationActionInput(label: 'Reply…')],
              // Keep the notification so it can show "sending / sent".
              cancelNotification: false,
            ),
          ],
        ),
      ),
      payload: jsonEncode({
        'type': 'message',
        'request_id': data['request_id'] ?? '',
        'sender_id': senderId,
        'title': data['title'] ?? '',
      }),
    );
  }

  /// Sends [text] as a reply to whoever is named in [payload], then updates
  /// the notification to say so. Works with no UI (app closed).
  static Future<void> reply(
    FlutterLocalNotificationsPlugin plugin,
    String? payload,
    String? text,
  ) async {
    final body = text?.trim() ?? '';
    if (payload == null || body.isEmpty) return;
    Map<String, dynamic> data;
    try {
      data = jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final recipientId = data['sender_id'] as String?;
    if (recipientId == null || recipientId.isEmpty) return;
    final requestId = data['request_id'] as String?;
    final title = data['title'] as String? ?? '';
    final id = _idFor(recipientId);

    String? failure;
    try {
      final client = await _client();
      final me = client.auth.currentUser;
      if (me == null) throw StateError('not signed in');
      // Bounded, so Android's "sending" spinner on the notification can't
      // spin forever if the network or the isolate's Supabase stalls.
      await client
          .from('messages')
          .insert({
            'request_id': (requestId == null || requestId.isEmpty)
                ? null
                : requestId,
            'sender_id': me.id,
            'recipient_id': recipientId,
            'body': body,
          })
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      debugPrint('Notification reply failed: $e');
      failure = 'Couldn\'t send your reply. Tap to open the chat.';
    }

    await plugin.show(
      id: id,
      title: title,
      body: failure ?? 'You: $body',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          icon: 'ic_notification',
          onlyAlertOnce: true,
          // A sent reply disappears by itself; a failure stays.
          timeoutAfter: failure == null ? 3000 : null,
        ),
      ),
      payload: payload,
    );
  }

  /// Supabase in a background isolate: the session is restored from disk.
  static Future<SupabaseClient> _client() async {
    try {
      return Supabase.instance.client;
    } catch (_) {
      await dotenv.load(fileName: '.env');
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
        // No Activity / deep links in this isolate; the link lookup can
        // stall initialize() and leave the reply spinning.
        authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
      ).timeout(const Duration(seconds: 15));
      return Supabase.instance.client;
    }
  }
}

/// FCM handler for the app being backgrounded or closed. Must be top-level.
@pragma('vm:entry-point')
Future<void> pushBackgroundMessageHandler(RemoteMessage message) async {
  if (message.data['type'] != 'message' || message.data['sender_id'] == null) {
    return;
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(settings: MessageNotifications.initSettings);
  await MessageNotifications.show(plugin, message.data);
}

/// Reply typed into a notification with the app not in the foreground.
/// Must be top-level.
@pragma('vm:entry-point')
Future<void> notificationBackgroundResponseHandler(
  NotificationResponse response,
) async {
  if (response.actionId != MessageNotifications.replyActionId) return;
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(settings: MessageNotifications.initSettings);
  await MessageNotifications.reply(plugin, response.payload, response.input);
}
