import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/realtime/realtime_event.dart';
import '../../../core/realtime/realtime_log.dart';
import '../../auth/data/repository/auth_repository.dart';
import 'chat_activity_store.dart';
import 'model/message_model.dart';
import 'repository/chat_repository.dart';

/// Local reactive cache of how many unread messages the current user has
/// from each other participant, backed by Supabase. Powers the Requests
/// screen's badges -- a message you haven't opened shows up right on the
/// tile, with a count, so it's obvious both that something arrived and who
/// sent it.
class ChatUnreadStore {
  ChatUnreadStore._();

  /// otherUserId -> number of unread messages from them.
  static final ValueNotifier<Map<String, int>> unreadBySender =
      ValueNotifier<Map<String, int>>({});

  // messageId -> senderId, for every currently-unread message. Counts are
  // derived from this so a read-receipt update or a delete can be applied
  // locally instead of re-fetching everything.
  static final Map<String, String> _unreadSenders = {};

  static StreamSubscription<RealtimeEvent<MessageModel>>? _subscription;
  static bool _hasSynced = false;

  /// Starts a live Supabase Realtime subscription that keeps
  /// [unreadBySender] in sync automatically. Safe to call more than once;
  /// only the first call (per sign-in, see [reset]) actually starts it.
  static void startRealtimeSync({
    ChatRepository? repository,
    AuthRepository? authRepository,
  }) {
    final userId = (authRepository ?? AuthRepository()).currentUser?.id;
    if (userId == null || _subscription != null) return;

    final repo = repository ?? ChatRepository();
    _subscription = repo
        .watchUnread(userId)
        .listen(
          (event) => _onEvent(event, userId, repo),
          onError: (Object e) =>
              realtimeLog('unread messages stream error: $e'),
        );
  }

  static void _onEvent(
    RealtimeEvent<MessageModel> event,
    String userId,
    ChatRepository repo,
  ) {
    switch (event.type) {
      case RealtimeEventType.subscribed:
        // Initial load, and catch-up after a reconnect.
        _hasSynced = true;
        _sync(userId, repo);
      case RealtimeEventType.error:
        // Realtime is down; still load once so the badges aren't stuck empty.
        if (!_hasSynced) {
          _hasSynced = true;
          _sync(userId, repo);
        }
      case RealtimeEventType.insert:
        final message = event.record;
        if (message == null) return;
        ChatActivityStore.bump(message.senderId, message.createdAt);
        if (message.readAt == null) {
          _unreadSenders[message.id] = message.senderId;
          _recompute();
        }
      case RealtimeEventType.update:
        final message = event.record;
        if (message == null) return;
        if (message.readAt != null || message.isDeletedFor(userId)) {
          if (_unreadSenders.remove(message.id) != null) _recompute();
        }
      case RealtimeEventType.delete:
        if (_unreadSenders.remove(event.id) != null) _recompute();
    }
  }

  static Future<void> _sync(String userId, ChatRepository repo) async {
    try {
      final unread = await repo.fetchUnread(userId);
      _unreadSenders
        ..clear()
        ..addEntries(
          unread
              .where((m) => !m.isDeletedFor(userId))
              .map((m) => MapEntry(m.id, m.senderId)),
        );
      _recompute();
    } catch (_) {
      // Best-effort -- the next realtime event or reconnect catches up.
    }
  }

  static void _recompute() {
    final counts = <String, int>{};
    for (final senderId in _unreadSenders.values) {
      counts[senderId] = (counts[senderId] ?? 0) + 1;
    }
    unreadBySender.value = counts;
  }

  /// Clears the badge for [otherUserId] right away -- called when a chat
  /// with them is opened, ahead of the server confirming the messages read.
  static void markSeen(String otherUserId) {
    final hadAny = _unreadSenders.values.contains(otherUserId);
    if (!hadAny) return;
    _unreadSenders.removeWhere((_, senderId) => senderId == otherUserId);
    _recompute();
  }

  /// Cancels the realtime subscription and clears the cache — call on
  /// logout so the next sign-in starts fresh, scoped to the new user.
  static void reset() {
    _subscription?.cancel();
    _subscription = null;
    _hasSynced = false;
    _unreadSenders.clear();
    unreadBySender.value = {};
    ChatActivityStore.reset();
  }
}
