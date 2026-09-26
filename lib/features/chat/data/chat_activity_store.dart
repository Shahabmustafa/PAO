import 'package:flutter/foundation.dart';

/// When each conversation last had a message (sent or received), keyed by
/// the other participant. The chats list sorts by this so whoever messaged
/// most recently is on top.
class ChatActivityStore {
  ChatActivityStore._();

  static final ValueNotifier<Map<String, DateTime>> lastActivity =
      ValueNotifier<Map<String, DateTime>>({});

  /// Records a message with [otherUserId] at [at]; older times are ignored.
  static void bump(String otherUserId, DateTime at) {
    final current = lastActivity.value[otherUserId];
    if (current != null && !at.isAfter(current)) return;
    lastActivity.value = {...lastActivity.value, otherUserId: at};
  }

  static void reset() => lastActivity.value = {};
}
