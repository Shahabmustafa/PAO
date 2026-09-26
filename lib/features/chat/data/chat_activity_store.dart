import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// When each conversation last had a message (sent or received), keyed by
/// the other participant. The chats list sorts by this so whoever messaged
/// most recently is on top.
class ChatActivityStore {
  ChatActivityStore._();

  static final ValueNotifier<Map<String, DateTime>> lastActivity =
      ValueNotifier<Map<String, DateTime>>({});

  /// Records a message with [otherUserId] at [at]; older times are ignored.
  static void bump(String otherUserId, DateTime at) {
    // Chat tiles call this while they're being built (their provider loads
    // the cached last message in its constructor); notifying the list then
    // is a setState-during-build, so wait for the frame to finish.
    final binding = SchedulerBinding.instance;
    if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      binding.addPostFrameCallback((_) => bump(otherUserId, at));
      return;
    }
    final current = lastActivity.value[otherUserId];
    if (current != null && !at.isAfter(current)) return;
    lastActivity.value = {...lastActivity.value, otherUserId: at};
  }

  static void reset() => lastActivity.value = {};
}
