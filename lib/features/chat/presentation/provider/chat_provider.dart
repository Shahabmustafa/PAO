import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException, StorageException;
import 'package:uuid/uuid.dart';
import '../../../../core/cache/local_cache.dart';
import '../../../../core/realtime/realtime_event.dart';
import '../../../../core/realtime/realtime_log.dart';
import '../../../auth/data/repository/auth_repository.dart';
import '../../../feedback/data/repository/feedback_repository.dart';
import '../../../requests/data/model/request_model.dart';
import '../../../requests/data/request_store.dart';
import '../../../settings/data/model/profile_model.dart';
import '../../../settings/data/repository/profile_repository.dart';
import '../../data/chat_media_cache.dart';
import '../../data/chat_unread_store.dart';
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
    // Cached messages are on screen from the very first frame; Supabase
    // then syncs in the background.
    _hydrateFromCache();
    _subscribe();
    _loadOtherProfile();
    _loadBlockState();
    if (isRequester && request.isAccepted) _checkFeedback();
    // Keep the accepted / closed state live too: the owner may answer while
    // the requester has the chat open.
    RequestStore.sent.addListener(_syncRequestStatus);
    RequestStore.received.addListener(_syncRequestStatus);
    // The other participant's online/last-seen status has no realtime
    // channel of its own (see PresenceHeartbeat), so poll it while this
    // chat is open.
    _profileRefreshTimer = Timer.periodic(
      const Duration(seconds: 25),
      (_) => _loadOtherProfile(),
    );
  }

  RequestModel request;
  final String otherUserId;
  final ChatRepository _repository;
  final AuthRepository _authRepository;
  final ProfileRepository _profileRepository;
  final FeedbackRepository _feedbackRepository;

  /// Messages held per fetch, and the most kept in the local cache.
  static const int pageSize = 30;
  static const int _cacheLimit = 100;
  static const _uuid = Uuid();

  List<MessageModel> messages = [];

  /// True only while there is nothing to show yet (no cache, first sync
  /// pending) -- with cached messages the chat never shows a spinner.
  bool isLoading = true;

  /// False once the server has no older messages than the ones loaded.
  bool hasMoreOlder = true;
  bool isLoadingOlder = false;
  bool isUploadingMedia = false;
  String? errorMessage;
  StreamSubscription<RealtimeEvent<MessageModel>>? _subscription;
  Timer? _profileRefreshTimer;
  bool _disposed = false;

  ProfileModel? otherProfile;
  bool isLoadingProfile = true;
  bool isAccepting = false;
  bool feedbackGiven = false;

  String? get currentUserId => _authRepository.currentUser?.id;
  bool get isOwner => request.ownerId == currentUserId;
  bool get isRequester => request.requesterId == currentUserId;

  /// True when [message] belongs to this conversation -- sent by either
  /// participant, to the other.
  bool _belongsToThisChat(MessageModel message) {
    final userId = currentUserId;
    if (userId == null) return false;
    return (message.senderId == userId && message.recipientId == otherUserId) ||
        (message.senderId == otherUserId && message.recipientId == userId);
  }

  /// Subscribes to this conversation's realtime channel. Each INSERT /
  /// UPDATE / DELETE is applied to [messages] by message id — the history is
  /// only fetched when the channel (re)joins, never per event.
  void _subscribe() {
    final userId = currentUserId;
    if (userId == null) return;
    _subscription = _repository
        .watchConversation(currentUserId: userId, otherUserId: otherUserId)
        .listen(
          _onEvent,
          onError: (Object e) {
            realtimeLog('chat with $otherUserId stream error: $e');
            _failLoading();
          },
        );
  }

  void _onEvent(RealtimeEvent<MessageModel> event) {
    if (_disposed) return;
    switch (event.type) {
      case RealtimeEventType.subscribed:
        // Initial sync, and catch-up after a reconnect.
        _syncLatest().then((_) => _retryFailed());
      case RealtimeEventType.error:
        // Realtime is down; still sync once so the chat isn't stuck loading.
        if (isLoading) _syncLatest();
      case RealtimeEventType.insert:
      case RealtimeEventType.update:
        final message = event.record;
        if (message == null || !_belongsToThisChat(message)) return;
        if (message.isDeletedFor(currentUserId!)) {
          _removeLocally(message.id);
          return;
        }
        _upsert(message);
        // A message just arrived while this chat is open -- that counts as
        // seen right away.
        if (event.type == RealtimeEventType.insert &&
            message.senderId != currentUserId) {
          unawaited(_markIncomingAsRead());
        }
      case RealtimeEventType.delete:
        // Deletes can't be filtered to this chat, so most aren't ours.
        if (!messages.any((m) => m.id == event.id)) return;
        _removeLocally(event.id);
    }
  }

  void _removeLocally(String id) {
    if (!messages.any((m) => m.id == id)) return;
    messages = messages.where((m) => m.id != id).toList();
    _persist();
    notifyListeners();
  }

  void _hydrateFromCache() {
    final userId = currentUserId;
    if (userId == null) return;
    final cached = [
      for (final json in LocalCache.readList(LocalCache.messages, _cacheKey))
        MessageModel.fromJson(json),
    ];
    if (cached.isEmpty) return;
    messages = _sorted([
      for (final m in cached)
        if (!m.isDeletedFor(userId))
          // Nothing is in flight right after opening, so a message left
          // "sending" (app closed mid-send) is really a failed one.
          m.status == MessageStatus.sending
              ? m.copyWith(status: MessageStatus.failed)
              : m,
    ]);
    isLoading = false;
  }

  String get _cacheKey => 'conv:$otherUserId';

  void _persist() {
    final kept = messages.length > _cacheLimit
        ? messages.sublist(messages.length - _cacheLimit)
        : messages;
    LocalCache.write(LocalCache.messages, _cacheKey, [
      for (final m in kept) m.toJson(),
    ]);
  }

  /// Fetches the latest page and merges it into [messages] and the cache.
  Future<void> _syncLatest() async {
    final userId = currentUserId;
    if (userId == null) return;
    try {
      final page = await _repository.fetchMessagesPage(
        currentUserId: userId,
        otherUserId: otherUserId,
        limit: pageSize,
      );
      if (_disposed) return;
      // The server's page is the truth for the time window it covers (so a
      // message deleted while we were away disappears). Kept as they are:
      // older cached messages, unconfirmed local ones, and anything newer
      // than the page that arrived live while it was in flight.
      final complete = page.length < pageSize;
      final windowStart = complete || page.isEmpty
          ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
          : page.last.createdAt;
      final newest = page.isEmpty ? null : page.first.createdAt;
      final byId = <String, MessageModel>{
        for (final m in messages)
          if (m.isPending ||
              m.createdAt.isBefore(windowStart) ||
              (newest != null && m.createdAt.isAfter(newest)))
            m.id: m,
      };
      for (final m in page) {
        if (m.isDeletedFor(userId)) {
          byId.remove(m.id);
        } else {
          byId[m.id] = m;
        }
      }
      messages = _sorted(byId.values);
      if (complete) hasMoreOlder = false;
      errorMessage = null;
      _persist();
      unawaited(_markIncomingAsRead());
    } catch (_) {
      if (_disposed) return;
      if (messages.isEmpty) errorMessage = l10nNow.failedToLoadMessages;
    }
    isLoading = false;
    notifyListeners();
  }

  /// Loads the next batch of older messages (called when the user scrolls
  /// to the top of the loaded history), using the oldest confirmed message
  /// as a keyset cursor.
  Future<void> loadOlder() async {
    final userId = currentUserId;
    if (userId == null || isLoading || isLoadingOlder || !hasMoreOlder) return;
    final confirmed = messages.where((m) => !m.isPending);
    if (confirmed.isEmpty) return;
    isLoadingOlder = true;
    notifyListeners();
    try {
      final page = await _repository.fetchMessagesPage(
        currentUserId: userId,
        otherUserId: otherUserId,
        before: confirmed.first.createdAt,
        limit: pageSize,
      );
      if (_disposed) return;
      final known = {for (final m in messages) m.id};
      messages = _sorted([
        ...messages,
        for (final m in page)
          if (!known.contains(m.id) && !m.isDeletedFor(userId)) m,
      ]);
      hasMoreOlder = page.length >= pageSize;
    } catch (_) {
      // Leave hasMoreOlder as is: scrolling to the top again retries.
    }
    if (_disposed) return;
    isLoadingOlder = false;
    notifyListeners();
  }

  /// Marks the other participant's unread messages as seen. Fire-and-forget:
  /// the server's realtime UPDATE echo (not a local edit) is what actually
  /// flips the ticks, for both participants alike.
  Future<void> _markIncomingAsRead() async {
    final userId = currentUserId;
    if (userId == null) return;
    // Clear this conversation's unread badge right away, ahead of the
    // server confirming the messages as read.
    ChatUnreadStore.markSeen(otherUserId);
    final hasUnread = messages.any(
      (m) => m.senderId != userId && m.readAt == null,
    );
    if (!hasUnread) return;
    try {
      await _repository.markMessagesRead(
        readerId: userId,
        otherUserId: otherUserId,
      );
    } catch (_) {
      // Best-effort -- the ticks just catch up next time this runs.
    }
  }

  void _failLoading() {
    errorMessage = l10nNow.failedToLoadMessages;
    isLoading = false;
    notifyListeners();
  }

  /// Adds [message], or replaces the copy with the same id. The optimistic
  /// copy of a sent message shares its id with the server row, so a
  /// Realtime / sync copy of it replaces it instead of duplicating it.
  void _upsert(MessageModel message) {
    final index = messages.indexWhere((m) => m.id == message.id);
    if (index >= 0) {
      messages = [...messages]..[index] = message;
    } else {
      messages = _sorted([...messages, message]);
    }
    _persist();
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
        // The owner just accepted while this chat is open.
        if (isRequester && request.isAccepted) _checkFeedback();
        notifyListeners();
      }
      return;
    }
  }

  Future<void> _loadOtherProfile() async {
    // Show the cached name / avatar straight away.
    if (otherProfile == null) {
      final cached = _profileRepository.cachedPublicProfile(otherUserId);
      if (cached != null) {
        otherProfile = cached;
        isLoadingProfile = false;
        notifyListeners();
      }
    }
    try {
      otherProfile = await _profileRepository.fetchPublicProfile(otherUserId);
    } catch (_) {
      // Keep the fallback name/avatar if the profile fails to load.
    }
    if (_disposed) return;
    isLoadingProfile = false;
    notifyListeners();
  }

  /// True once it is known whether the requester already left feedback, so
  /// the chat doesn't pop the feedback dialog for someone who already did.
  bool feedbackChecked = false;

  Future<void> _checkFeedback() async {
    try {
      final feedback = await _feedbackRepository.fetchForRequest(request.id);
      feedbackGiven = feedback != null;
      feedbackChecked = true;
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

  /// Optimistic send: the message is stored and shown at once as
  /// `sending`, then delivered in the background and marked `sent` or
  /// `failed` (tap it to retry).
  Future<void> sendMessage(String body, {String? replyToId}) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;
    final senderId = currentUserId;
    if (senderId == null) return;

    final local = MessageModel(
      // Also used as the row id on the server: that is the dedupe key.
      id: _uuid.v4(),
      senderId: senderId,
      recipientId: otherUserId,
      requestId: request.id,
      body: trimmed,
      createdAt: DateTime.now().toUtc(),
      replyToId: replyToId,
      status: MessageStatus.sending,
    );
    _upsert(local);
    await _deliver(local);
  }

  Future<void> _deliver(MessageModel local) async {
    try {
      final sent = await _repository.sendMessage(
        id: local.id,
        requestId: request.id,
        replyToId: local.replyToId,
        senderId: local.senderId,
        recipientId: local.recipientId,
        body: local.body,
      );
      if (_disposed) {
        _persistConfirmed(sent);
        return;
      }
      _upsert(sent);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        // A previous attempt did reach the server: it is delivered.
        if (_disposed) return;
        _upsert(local.copyWith(status: MessageStatus.sent));
        unawaited(_syncLatest());
        return;
      }
      _markFailed(local);
    } catch (_) {
      _markFailed(local);
    }
  }

  // The chat was closed while the send was in flight: still record the
  // outcome so the cache doesn't keep it as "sending".
  void _persistConfirmed(MessageModel sent) {
    final cached = LocalCache.readList(LocalCache.messages, _cacheKey);
    final updated = [
      for (final json in cached)
        if (json['id'] == sent.id) sent.toJson() else json,
    ];
    LocalCache.write(LocalCache.messages, _cacheKey, updated);
  }

  void _markFailed(MessageModel local) {
    if (_disposed) {
      final cached = LocalCache.readList(LocalCache.messages, _cacheKey);
      LocalCache.write(LocalCache.messages, _cacheKey, [
        for (final json in cached)
          if (json['id'] == local.id)
            local.copyWith(status: MessageStatus.failed).toJson()
          else
            json,
      ]);
      return;
    }
    final current = messageById(local.id);
    if (current == null) return; // deleted meanwhile
    _upsert(current.copyWith(status: MessageStatus.failed));
    errorMessage = l10nNow.failedToSendMessage;
  }

  /// Re-sends a failed text message with the same id.
  Future<void> retry(MessageModel message) async {
    if (message.status != MessageStatus.failed) return;
    final sending = message.copyWith(status: MessageStatus.sending);
    _upsert(sending);
    await _deliver(sending);
  }

  Future<void> _retryFailed() async {
    for (final m in messages.where(
      (m) => m.status == MessageStatus.failed && m.senderId == currentUserId,
    )) {
      if (_disposed) return;
      await retry(m);
    }
  }

  final _mediaUrls = <String, Future<String>>{};

  /// A signed URL for a message's media file, fetched once per path.
  Future<String> mediaUrl(String path) {
    return _mediaUrls.putIfAbsent(path, () {
      final url = _repository.mediaUrl(path);
      url.catchError((_) {
        _mediaUrls.remove(path);
        return '';
      });
      return url;
    });
  }

  /// The local file of a message's media: read from the disk cache, or
  /// downloaded once and kept there.
  Future<File> mediaFile(String path) =>
      ChatMediaCache.load(path, () => mediaUrl(path));

  // ---- Safety: clear chat, block, report ----------------------------------

  /// True once the current user has blocked the other participant.
  bool isBlockedByMe = false;

  /// True while the block state is being looked up, so the composer doesn't
  /// flash before it is known.
  bool blockChecked = false;

  Future<void> _loadBlockState() async {
    final userId = currentUserId;
    if (userId == null) return;
    try {
      isBlockedByMe = await _repository.isBlockedByMe(
        myId: userId,
        otherUserId: otherUserId,
      );
    } catch (_) {
      // Offline: assume not blocked; a send would still be refused server-side.
    }
    blockChecked = true;
    if (!_disposed) notifyListeners();
  }

  Future<bool> setBlocked(bool blocked) async {
    final userId = currentUserId;
    if (userId == null) return false;
    try {
      if (blocked) {
        await _repository.blockUser(myId: userId, otherUserId: otherUserId);
      } else {
        await _repository.unblockUser(myId: userId, otherUserId: otherUserId);
      }
      isBlockedByMe = blocked;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Hides the whole conversation from this user only. Their copy of the
  /// chat, and the other person's, are untouched.
  Future<bool> clearChat() async {
    try {
      await _repository.clearConversation(otherUserId);
    } catch (_) {
      return false;
    }
    for (final m in messages) {
      final path = m.mediaPath;
      if (path != null) unawaited(ChatMediaCache.remove(path));
    }
    messages = [];
    hasMoreOlder = false;
    _persist();
    notifyListeners();
    return true;
  }

  /// Reports the other participant. Returns null on success (a repeat
  /// report by the same person counts as success), else an error message.
  Future<String?> reportUser(String reason, String? details) async {
    final userId = currentUserId;
    if (userId == null) return l10nNow.somethingWentWrong;
    try {
      await _repository.reportUser(
        reporterId: userId,
        reportedId: otherUserId,
        reason: reason,
        details: details,
      );
      return null;
    } on PostgrestException catch (e) {
      if (e.code == '23505') return null;
      return l10nNow.somethingWentWrong;
    } catch (_) {
      return l10nNow.somethingWentWrong;
    }
  }

  /// Uploads [file] and sends it as a photo / video / voice message.
  Future<bool> sendMedia(
    File file,
    MessageMediaType type, {
    int? durationMs,
  }) async {
    final senderId = currentUserId;
    if (senderId == null) return false;

    isUploadingMedia = true;
    notifyListeners();
    String? uploadedPath;
    try {
      final dot = file.path.lastIndexOf('.');
      final extension = dot >= 0
          ? file.path.substring(dot + 1).toLowerCase()
          : _defaultExtension(type);
      uploadedPath = await _repository.uploadMedia(
        userId: senderId,
        file: file,
        extension: extension,
        contentType: _contentType(type, extension),
      );
      final message = await _repository.sendMessage(
        requestId: request.id,
        senderId: senderId,
        recipientId: otherUserId,
        body: '',
        mediaType: type,
        mediaPath: uploadedPath,
        mediaDurationMs: durationMs,
      );
      await ChatMediaCache.put(uploadedPath, file);
      _upsert(message);
      return true;
    } catch (e, st) {
      debugPrint('sendMedia failed (upload: ${uploadedPath == null}): $e\n$st');
      if (uploadedPath != null) {
        // The file went up but the message didn't -- don't leave it orphaned.
        unawaited(_repository.removeMedia(uploadedPath).catchError((_) {}));
      }
      // Say why (bucket missing, policy denied, ...) so it can be fixed.
      final reason = switch (e) {
        StorageException(:final message) => message,
        PostgrestException(:final message) => message,
        _ => null,
      };
      errorMessage = reason == null
          ? l10nNow.failedToSendMessage
          : '${l10nNow.failedToSendMessage} ($reason)';
      return false;
    } finally {
      isUploadingMedia = false;
      notifyListeners();
    }
  }

  static String _defaultExtension(MessageMediaType type) => switch (type) {
    MessageMediaType.image => 'jpg',
    MessageMediaType.video => 'mp4',
    MessageMediaType.audio => 'm4a',
  };

  static String _contentType(MessageMediaType type, String extension) =>
      switch (type) {
        MessageMediaType.image => switch (extension) {
          'png' => 'image/png',
          'webp' => 'image/webp',
          'gif' => 'image/gif',
          'heic' => 'image/heic',
          _ => 'image/jpeg',
        },
        MessageMediaType.video => switch (extension) {
          'mov' => 'video/quicktime',
          '3gp' => 'video/3gpp',
          'webm' => 'video/webm',
          _ => 'video/mp4',
        },
        MessageMediaType.audio => switch (extension) {
          'mp3' => 'audio/mpeg',
          'aac' => 'audio/aac',
          'ogg' => 'audio/ogg',
          _ => 'audio/mp4',
        },
      };

  /// Edits one of the current user's own messages.
  Future<bool> editMessage(MessageModel message, String newBody) async {
    final trimmed = newBody.trim();
    if (trimmed.isEmpty ||
        trimmed == message.body ||
        message.senderId != currentUserId) {
      return false;
    }
    try {
      final updated = await _repository.editMessage(
        messageId: message.id,
        body: trimmed,
      );
      _upsert(updated);
      return true;
    } catch (_) {
      errorMessage = l10nNow.failedToEditMessage;
      notifyListeners();
      return false;
    }
  }

  /// Deletes one of the current user's own messages. The bubble disappears
  /// right away and is put back if the delete fails.
  Future<bool> deleteMessage(MessageModel message) async {
    if (message.senderId != currentUserId) return false;
    if (message.isPending) {
      // Never confirmed by the server: just drop the local copy.
      _removeLocally(message.id);
      return true;
    }
    final previous = messages;
    messages = messages.where((m) => m.id != message.id).toList();
    _persist();
    notifyListeners();
    try {
      await _repository.deleteMessage(message.id);
      return true;
    } catch (_) {
      messages = previous;
      _persist();
      notifyListeners();
      return false;
    }
  }

  /// The loaded message with [id], or null (deleted / hidden / not loaded).
  MessageModel? messageById(String? id) {
    if (id == null) return null;
    for (final m in messages) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Sets the current user's reaction on [message]; reacting with the emoji
  /// already chosen removes it. Applied locally first, put back on failure.
  Future<bool> react(MessageModel message, String emoji) async {
    final userId = currentUserId;
    if (userId == null || message.isPending) return false;
    final remove = message.reactions[userId] == emoji;
    final previous = messages;
    final updated = {...message.reactions};
    if (remove) {
      updated.remove(userId);
    } else {
      updated[userId] = emoji;
    }
    messages = [
      for (final m in messages)
        if (m.id == message.id) m.copyWith(reactions: updated) else m,
    ];
    notifyListeners();
    try {
      await _repository.reactToMessage(message.id, remove ? null : emoji);
      return true;
    } catch (_) {
      messages = previous;
      notifyListeners();
      return false;
    }
  }

  /// Hides any message (mine or theirs) from the current user's view only.
  Future<bool> deleteMessageForMe(MessageModel message) async {
    final previous = messages;
    messages = messages.where((m) => m.id != message.id).toList();
    _persist();
    notifyListeners();
    try {
      await _repository.deleteMessageForMe(message.id);
      return true;
    } catch (_) {
      messages = previous;
      _persist();
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
    _profileRefreshTimer?.cancel();
    super.dispose();
  }
}
