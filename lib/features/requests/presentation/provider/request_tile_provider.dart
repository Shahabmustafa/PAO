import 'package:flutter/foundation.dart';
import '../../../../core/cache/local_cache.dart';
import '../../../add_item/data/repository/post_repository.dart';
import '../../../chat/data/chat_unread_store.dart';
import '../../../chat/data/model/message_model.dart';
import '../../../chat/data/repository/chat_repository.dart';
import '../../../auth/data/repository/auth_repository.dart';
import '../../../feedback/data/repository/feedback_repository.dart';
import '../../../settings/data/model/profile_model.dart';
import '../../../settings/data/repository/profile_repository.dart';
import '../../data/model/request_model.dart';
import '../../data/request_store.dart';
import '../../../../core/l10n/l10n.dart';

class RequestTileProvider extends ChangeNotifier {
  RequestTileProvider({
    required this.request,
    required this.otherUserId,
    required this.isSentTab,
    this.productName,
    this.productImageUrl,
    ProfileRepository? profileRepository,
    FeedbackRepository? feedbackRepository,
    PostRepository? postRepository,
    AuthRepository? authRepository,
    ChatRepository? chatRepository,
  }) : _chatRepositoryOverride = chatRepository,
       _profileRepository = profileRepository ?? ProfileRepository(),
       _feedbackRepository = feedbackRepository ?? FeedbackRepository(),
       _postRepository = postRepository ?? PostRepository(),
       _authRepository = authRepository ?? AuthRepository() {
    _loadProfile();
    loadLastMessage();
    // A new incoming message changes the unread counts; refresh the preview.
    ChatUnreadStore.unreadBySender.addListener(_onUnreadChanged);
    if (productName == null) _loadProduct();
    if (isSentTab && request.isAccepted) _checkFeedback();
  }

  final RequestModel request;
  final String otherUserId;
  final bool isSentTab;

  final ProfileRepository _profileRepository;
  final FeedbackRepository _feedbackRepository;
  final PostRepository _postRepository;
  final AuthRepository _authRepository;
  final ChatRepository? _chatRepositoryOverride;

  // Lazy: only built once a conversation preview is actually loaded.
  late final ChatRepository _chatRepository =
      _chatRepositoryOverride ?? ChatRepository();

  /// The newest message in the conversation with [otherUserId] that the
  /// current user hasn't deleted, for the chat list preview.
  MessageModel? lastMessage;

  ProfileModel? profile;
  bool isLoadingProfile = true;

  String? productName;
  String? productImageUrl;
  bool isLoadingProduct = false;

  bool feedbackGiven = false;
  bool isAccepting = false;
  String? errorMessage;

  String? get currentUserId => _authRepository.currentUser?.id;

  int _lastUnread = 0;

  void _onUnreadChanged() {
    final unread = ChatUnreadStore.unreadBySender.value[otherUserId] ?? 0;
    if (unread > _lastUnread) loadLastMessage(refresh: true);
    _lastUnread = unread;
  }

  /// The newest message the current user can see, from the chat's Hive copy
  /// (ChatProvider keeps it up to date), or null when nothing is cached.
  MessageModel? _cachedLastMessage(String me) {
    MessageModel? newest;
    for (final json in LocalCache.readList(
      LocalCache.messages,
      'conv:$otherUserId',
    )) {
      try {
        final m = MessageModel.fromJson(json);
        if (m.isDeletedFor(me)) continue;
        if (newest == null || m.createdAt.isAfter(newest.createdAt)) {
          newest = m;
        }
      } catch (_) {}
    }
    return newest;
  }

  /// Loads the preview. Uses the cached chat when there is one; only asks
  /// Supabase when nothing is cached or [refresh] says a new message
  /// arrived.
  Future<void> loadLastMessage({bool refresh = false}) async {
    final me = currentUserId;
    if (me == null) return;
    final cached = _cachedLastMessage(me);
    if (cached != null) {
      lastMessage = cached;
      notifyListeners();
      if (!refresh) return;
    }
    try {
      final page = await _chatRepository.fetchMessagesPage(
        currentUserId: me,
        otherUserId: otherUserId,
        limit: 5,
      );
      lastMessage = page.where((m) => !m.isDeletedFor(me)).firstOrNull;
      notifyListeners();
    } catch (_) {
      // No preview; the row still works.
    }
  }

  Future<void> _loadProfile() async {
    final cached = _profileRepository.cachedPublicProfile(otherUserId);
    if (cached != null) {
      // Name and photo rarely change; the cached copy is enough here.
      profile = cached;
      isLoadingProfile = false;
      notifyListeners();
      return;
    }
    try {
      profile = await _profileRepository.fetchPublicProfile(otherUserId);
    } catch (_) {
      // Keep the fallback name.
    } finally {
      isLoadingProfile = false;
      notifyListeners();
    }
  }

  Future<void> _loadProduct() async {
    final key = 'post:${request.postId}';
    final cached = LocalCache.readMap(LocalCache.products, key);
    if (cached != null && cached['title'] is String) {
      productName = cached['title'] as String;
      productImageUrl = cached['image'] as String?;
      return;
    }
    isLoadingProduct = true;
    notifyListeners();
    try {
      final post = await _postRepository.fetchPostById(request.postId);
      productName = post?.title ?? l10nNow.paoItem;
      productImageUrl = post != null && post.imageUrls.isNotEmpty
          ? post.imageUrls.first
          : null;
      if (post != null) {
        LocalCache.write(LocalCache.products, key, {
          'title': post.title,
          'image': productImageUrl,
        });
      }
    } catch (_) {
      productName = l10nNow.paoItem;
    } finally {
      isLoadingProduct = false;
      notifyListeners();
    }
  }

  Future<void> _checkFeedback() async {
    try {
      final feedback = await _feedbackRepository.fetchForRequest(request.id);
      feedbackGiven = feedback != null;
      notifyListeners();
    } catch (_) {
      // Leave the button visible; worst case they're asked again.
    }
  }

  Future<bool> accept() async {
    isAccepting = true;
    errorMessage = null;
    notifyListeners();
    try {
      await RequestStore.accept(request);
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

  // The tile is rebuilt (and this provider disposed) when its request's
  // status changes, while a profile/product/accept call may still be in
  // flight — don't notify after that.
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ChatUnreadStore.unreadBySender.removeListener(_onUnreadChanged);
    super.dispose();
  }
}
