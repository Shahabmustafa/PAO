import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/realtime/realtime_event.dart';
import '../../../../core/realtime/realtime_log.dart';
import '../../../auth/data/repository/auth_repository.dart';
import '../../../feedback/data/repository/feedback_repository.dart';
import '../../../requests/data/model/request_model.dart';
import '../../../requests/data/request_store.dart';
import '../../../settings/data/model/profile_model.dart';
import '../../../settings/data/repository/profile_repository.dart';
import '../../data/model/message_model.dart';
import '../../data/repository/chat_repository.dart';
import '../../../../core/l10n/l10n.dart';

class ChatProvider extends ChangeNotifier {
  ChatProvider({
    required this.request,
    required this.otherUserId,
    ChatRepository? repository,
    AuthRepository? authRepository,
    ProfileRepository? profileRepository,
    FeedbackRepository? feedbackRepository,
  }) : _repository = repository ?? ChatRepository(),
       _authRepository = authRepository ?? AuthRepository(),
       _profileRepository = profileRepository ?? ProfileRepository(),
       _feedbackRepository = feedbackRepository ?? FeedbackRepository() {
    _subscribe();
    _loadOtherProfile();
    if (isRequester && request.isAccepted) _checkFeedback();
    // Keep the accepted / closed state live too: the owner may answer while
    // the requester has the chat open.
    RequestStore.sent.addListener(_syncRequestStatus);
    RequestStore.received.addListener(_syncRequestStatus);
  }

  RequestModel request;
  final String otherUserId;
  final ChatRepository _repository;
  final AuthRepository _authRepository;
  final ProfileRepository _profileRepository;
  final FeedbackRepository _feedbackRepository;

  List<MessageModel> messages = [];
  bool isLoading = true;
  bool isSending = false;
  String? errorMessage;
  StreamSubscription<RealtimeEvent<MessageModel>>? _subscription;
  bool _disposed = false;

  ProfileModel? otherProfile;
  bool isLoadingProfile = true;
  bool isAccepting = false;
  bool feedbackGiven = false;

  String? get currentUserId => _authRepository.currentUser?.id;
  bool get isOwner => request.ownerId == currentUserId;
  bool get isRequester => request.requesterId == currentUserId;

  /// Subscribes to this conversation's realtime channel. Each INSERT /
  /// UPDATE / DELETE is applied to [messages] by message id — the history is
  /// only fetched when the channel (re)joins, never per event.
  void _subscribe() {
    _subscription = _repository
        .watchMessages(request.id)
        .listen(
          _onEvent,
          onError: (Object e) {
            realtimeLog('chat ${request.id} stream error: $e');
            _failLoading();
          },
        );
  }

  void _onEvent(RealtimeEvent<MessageModel> event) {
    if (_disposed) return;
    switch (event.type) {
      case RealtimeEventType.subscribed:
        // Initial load, and catch-up after a reconnect.
        _loadHistory();
      case RealtimeEventType.error:
        // Realtime is down; still load once so the chat isn't stuck loading.
        if (isLoading) _loadHistory();
      case RealtimeEventType.insert:
      case RealtimeEventType.update:
        final message = event.record;
        if (message == null || message.requestId != request.id) return;
        _upsert(message);
      case RealtimeEventType.delete:
        // Deletes can't be filtered to this chat, so most aren't ours.
        if (!messages.any((m) => m.id == event.id)) return;
        messages = messages.where((m) => m.id != event.id).toList();
        notifyListeners();
    }
  }

  Future<void> _loadHistory() async {
    try {
      final history = await _repository.fetchMessages(request.id);
      if (_disposed) return;
      // The server's list is the truth (so a message deleted while we were
      // disconnected disappears), except for messages newer than what it
      // returned: those arrived live while the request was in flight.
      final cutoff = history.isNotEmpty
          ? history.last.createdAt
          : (isLoading
                ? DateTime.fromMillisecondsSinceEpoch(0)
                : DateTime.now().add(const Duration(days: 1)));
      final byId = {for (final m in history) m.id: m};
      for (final m in messages) {
        if (m.createdAt.isAfter(cutoff)) byId[m.id] = m;
      }
      messages = _sorted(byId.values);
      errorMessage = null;
    } catch (_) {
      if (_disposed) return;
      if (messages.isEmpty) errorMessage = l10nNow.failedToLoadMessages;
    }
    isLoading = false;
    notifyListeners();
  }

  void _failLoading() {
    errorMessage = l10nNow.failedToLoadMessages;
    isLoading = false;
    notifyListeners();
  }

  /// Adds [message], or replaces the copy with the same id — a message we
  /// just sent is also delivered back over Realtime.
  void _upsert(MessageModel message) {
    final index = messages.indexWhere((m) => m.id == message.id);
    if (index >= 0) {
      messages = [...messages]..[index] = message;
    } else {
      messages = _sorted([...messages, message]);
    }
    notifyListeners();
  }

  // Oldest first, so the newest message lands at the bottom of the reversed
  // list regardless of the order events arrive in.
  List<MessageModel> _sorted(Iterable<MessageModel> list) =>
      list.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  void _syncRequestStatus() {
    for (final r in [
      ...RequestStore.sent.value,
      ...RequestStore.received.value,
    ]) {
      if (r.id != request.id) continue;
      if (r.status != request.status) {
        request = request.copyWith(status: r.status);
        notifyListeners();
      }
      return;
    }
  }

  Future<void> _loadOtherProfile() async {
    try {
      otherProfile = await _profileRepository.fetchPublicProfile(otherUserId);
    } catch (_) {
      // Keep the fallback name/avatar if the profile fails to load.
    } finally {
      isLoadingProfile = false;
      notifyListeners();
    }
  }

  Future<void> _checkFeedback() async {
    try {
      final feedback = await _feedbackRepository.fetchForRequest(request.id);
      feedbackGiven = feedback != null;
      notifyListeners();
    } catch (_) {
      // Leave the banner visible; worst case they're asked again.
    }
  }

  Future<bool> acceptRequest() async {
    isAccepting = true;
    errorMessage = null;
    notifyListeners();
    try {
      await RequestStore.accept(request);
      request = request.copyWith(status: 'accepted');
      return true;
    } catch (_) {
      errorMessage = l10nNow.failedToUpdate;
      return false;
    } finally {
      isAccepting = false;
      notifyListeners();
    }
  }

  void markFeedbackGiven() {
    feedbackGiven = true;
    notifyListeners();
  }

  Future<void> sendMessage(String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;
    final senderId = currentUserId;
    if (senderId == null) return;

    isSending = true;
    notifyListeners();
    try {
      final message = await _repository.sendMessage(
        requestId: request.id,
        senderId: senderId,
        body: trimmed,
      );
      // Show it right away; the realtime INSERT for the same id is a no-op.
      _upsert(message);
    } catch (_) {
      errorMessage = l10nNow.failedToSendMessage;
    } finally {
      isSending = false;
      notifyListeners();
    }
  }

  /// Deletes one of the current user's own messages. The bubble disappears
  /// right away and is put back if the delete fails.
  Future<bool> deleteMessage(MessageModel message) async {
    if (message.senderId != currentUserId) return false;
    final previous = messages;
    messages = messages.where((m) => m.id != message.id).toList();
    notifyListeners();
    try {
      await _repository.deleteMessage(message.id);
      return true;
    } catch (_) {
      messages = previous;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    RequestStore.sent.removeListener(_syncRequestStatus);
    RequestStore.received.removeListener(_syncRequestStatus);
    _subscription?.cancel();
    super.dispose();
  }
}
