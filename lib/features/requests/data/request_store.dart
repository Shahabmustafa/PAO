import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/cache/local_cache.dart';
import '../../../core/realtime/realtime_event.dart';
import '../../../core/realtime/realtime_log.dart';
import '../../add_item/data/repository/post_repository.dart';
import '../../auth/data/repository/auth_repository.dart';
import '../../home/data/product_store.dart';
import 'datasource/request_remote_datasource.dart';
import 'model/request_model.dart';
import 'repository/request_repository.dart';

/// Local reactive cache of the current user's requests, backed by Supabase:
/// [sent] (items they've asked for) and [received] (requests on items they
/// posted). [sent] also powers the "already requested" check on the
/// product detail screen.
class RequestStore {
  RequestStore._();

  static final ValueNotifier<List<RequestModel>> sent =
      ValueNotifier<List<RequestModel>>([]);
  static final ValueNotifier<List<RequestModel>> received =
      ValueNotifier<List<RequestModel>>([]);

  /// Requests are fetched from the server [pageSize] at a time.
  static const int pageSize = 10;

  static final ValueNotifier<bool> hasMoreSent = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> hasMoreReceived = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> isLoadingMoreSent = ValueNotifier<bool>(
    false,
  );
  static final ValueNotifier<bool> isLoadingMoreReceived = ValueNotifier<bool>(
    false,
  );

  // Rows already fetched for each list; the next page starts here.
  static int _sentOffset = 0;
  static int _receivedOffset = 0;

  static StreamSubscription<RealtimeEvent<RequestModel>>? _subscription;
  static bool _hasSynced = false;
  static bool _cacheWired = false;

  static const int _cacheLimit = 30;

  /// Loads the cached lists (so the Requests screen has content on the
  /// first frame) and starts mirroring changes back to the cache. Call once
  /// at startup, after [LocalCache.init]. The cache belongs to the signed-in
  /// account only: [LocalCache] wipes it when the account changes.
  static void hydrateFromCache() {
    if (_cacheWired) return;
    _cacheWired = true;
    List<RequestModel> read(String key) {
      final list = <RequestModel>[];
      for (final json in LocalCache.readList(LocalCache.requests, key)) {
        try {
          list.add(RequestModel.fromJson(json));
        } catch (_) {
          // Skip an entry from another app version.
        }
      }
      return list;
    }

    final cachedSent = read('sent');
    final cachedReceived = read('received');
    if (cachedSent.isNotEmpty) {
      sent.value = cachedSent;
      _sentOffset = cachedSent.length;
    }
    if (cachedReceived.isNotEmpty) {
      received.value = cachedReceived;
      _receivedOffset = cachedReceived.length;
    }
    sent.addListener(() => _persist('sent', sent.value));
    received.addListener(() => _persist('received', received.value));
  }

  static void _persist(String key, List<RequestModel> list) {
    LocalCache.write(LocalCache.requests, key, [
      for (final r in list.take(_cacheLimit)) r.toJson(),
    ]);
  }

  // Posts the request tiles show (name, photo) come from the product
  // store; fetch the missing ones in one query instead of one per tile.
  static void _loadProductsFor(List<RequestModel> list) {
    ProductStore.ensureLoaded(list.map((r) => r.postId));
  }

  /// Starts a live Supabase Realtime subscription that keeps [sent] and
  /// [received] in sync automatically — a new "Give Me" request shows up in
  /// [received], an accept / decline shows up in [sent] — with no manual
  /// refresh. Each INSERT / UPDATE / DELETE is applied to the local lists by
  /// request id, so nothing is refetched or duplicated. Safe to call more
  /// than once; only the first call (per sign-in, see [reset]) actually
  /// starts the subscription.
  static void startRealtimeSync({
    RequestRepository? repository,
    AuthRepository? authRepository,
  }) {
    final userId = (authRepository ?? AuthRepository()).currentUser?.id;
    if (userId == null || _subscription != null) return;

    final repo = repository ?? RequestRepository();
    final auth = authRepository;
    _subscription = repo
        .watchRequests(userId)
        .listen(
          (event) => _onEvent(event, repo, auth),
          onError: (Object e) => realtimeLog('requests stream error: $e'),
        );
  }

  static void _onEvent(
    RealtimeEvent<RequestModel> event,
    RequestRepository repo,
    AuthRepository? auth,
  ) {
    switch (event.type) {
      case RealtimeEventType.subscribed:
        // Initial load, and catch-up after a reconnect.
        _hasSynced = true;
        _syncBoth(repo, auth);
      case RealtimeEventType.error:
        // Realtime is down; still load once so the lists aren't empty.
        if (!_hasSynced) {
          _hasSynced = true;
          _syncBoth(repo, auth);
        }
      case RealtimeEventType.insert:
      case RealtimeEventType.update:
        final request = event.record;
        if (request == null) return;
        if (event.tag == RequestRemoteDataSource.sentTag) {
          final isNew = !sent.value.any((r) => r.id == request.id);
          sent.value = _upsert(sent.value, request);
          // A brand-new row shifts every later page down by one, so the
          // next page fetched from the server must skip one row further.
          if (isNew) _sentOffset++;
        } else if (event.tag == RequestRemoteDataSource.receivedTag) {
          final isNew = !received.value.any((r) => r.id == request.id);
          received.value = _upsert(received.value, request);
          if (isNew) _receivedOffset++;
        }
      case RealtimeEventType.delete:
        // Deletes can't be filtered by user, so ignore ids we don't hold.
        if (sent.value.any((r) => r.id == event.id)) {
          sent.value = sent.value.where((r) => r.id != event.id).toList();
          if (_sentOffset > 0) _sentOffset--;
        }
        if (received.value.any((r) => r.id == event.id)) {
          received.value = received.value
              .where((r) => r.id != event.id)
              .toList();
          if (_receivedOffset > 0) _receivedOffset--;
        }
    }
  }

  static void _syncBoth(RequestRepository repo, AuthRepository? auth) {
    syncSentFromSupabase(
      repository: repo,
      authRepository: auth,
    ).catchError((_) {});
    syncReceivedFromSupabase(
      repository: repo,
      authRepository: auth,
    ).catchError((_) {});
  }

  /// [list] with [request] replaced in place (matched by id), or inserted
  /// at its newest-first position if it is new — never duplicated.
  static List<RequestModel> _upsert(
    List<RequestModel> list,
    RequestModel request,
  ) {
    final index = list.indexWhere((r) => r.id == request.id);
    if (index >= 0) {
      return [...list]..[index] = request;
    }
    final at = list.indexWhere((r) => !r.createdAt.isAfter(request.createdAt));
    return [...list]..insert(at < 0 ? list.length : at, request);
  }

  /// Cancels the realtime subscription and clears the cache — call on
  /// logout so the next sign-in starts fresh, scoped to the new user.
  static void reset() {
    _subscription?.cancel();
    _subscription = null;
    _hasSynced = false;
    sent.value = [];
    received.value = [];
    _sentOffset = 0;
    _receivedOffset = 0;
    hasMoreSent.value = true;
    hasMoreReceived.value = true;
    isLoadingMoreSent.value = false;
    isLoadingMoreReceived.value = false;
  }

  /// Drops every request on [postId] from the local cache — used after the
  /// post is deleted, which removes its requests in Supabase too.
  static void removeForPost(String postId) {
    final removedFromSent = sent.value.where((r) => r.postId == postId).length;
    final removedFromReceived = received.value
        .where((r) => r.postId == postId)
        .length;
    sent.value = sent.value.where((r) => r.postId != postId).toList();
    received.value = received.value.where((r) => r.postId != postId).toList();
    _sentOffset = (_sentOffset - removedFromSent).clamp(0, _sentOffset);
    _receivedOffset = (_receivedOffset - removedFromReceived).clamp(
      0,
      _receivedOffset,
    );
  }

  /// Loads the first page (the most recent [pageSize] requests) for [sent].
  static Future<void> syncSentFromSupabase({
    RequestRepository? repository,
    AuthRepository? authRepository,
  }) async {
    final userId = (authRepository ?? AuthRepository()).currentUser?.id;
    if (userId == null) {
      sent.value = [];
      _sentOffset = 0;
      hasMoreSent.value = false;
      return;
    }
    final page = await (repository ?? RequestRepository())
        .fetchSentRequestsPage(userId, offset: 0, limit: pageSize);
    sent.value = page;
    _sentOffset = page.length;
    hasMoreSent.value = page.length >= pageSize;
    _loadProductsFor(page);
  }

  /// Loads the first page (the most recent [pageSize] requests) for
  /// [received].
  static Future<void> syncReceivedFromSupabase({
    RequestRepository? repository,
    AuthRepository? authRepository,
  }) async {
    final userId = (authRepository ?? AuthRepository()).currentUser?.id;
    if (userId == null) {
      received.value = [];
      _receivedOffset = 0;
      hasMoreReceived.value = false;
      return;
    }
    final page = await (repository ?? RequestRepository())
        .fetchReceivedRequestsPage(userId, offset: 0, limit: pageSize);
    received.value = page;
    _receivedOffset = page.length;
    hasMoreReceived.value = page.length >= pageSize;
    _loadProductsFor(page);
  }

  /// Fetches the next page of [sent] and appends it. Safe to call while
  /// already loading or once the server has no more rows — a no-op then.
  static Future<void> loadMoreSent({
    RequestRepository? repository,
    AuthRepository? authRepository,
  }) async {
    if (isLoadingMoreSent.value || !hasMoreSent.value) return;
    final userId = (authRepository ?? AuthRepository()).currentUser?.id;
    if (userId == null) return;

    isLoadingMoreSent.value = true;
    try {
      final page = await (repository ?? RequestRepository())
          .fetchSentRequestsPage(userId, offset: _sentOffset, limit: pageSize);
      final known = {for (final r in sent.value) r.id};
      sent.value = [...sent.value, ...page.where((r) => !known.contains(r.id))];
      _sentOffset += page.length;
      hasMoreSent.value = page.length >= pageSize;
    } catch (_) {
      // Leave hasMoreSent as-is so the next scroll attempt retries.
    } finally {
      isLoadingMoreSent.value = false;
    }
  }

  /// Fetches the next page of [received] and appends it. Safe to call while
  /// already loading or once the server has no more rows — a no-op then.
  static Future<void> loadMoreReceived({
    RequestRepository? repository,
    AuthRepository? authRepository,
  }) async {
    if (isLoadingMoreReceived.value || !hasMoreReceived.value) return;
    final userId = (authRepository ?? AuthRepository()).currentUser?.id;
    if (userId == null) return;

    isLoadingMoreReceived.value = true;
    try {
      final page = await (repository ?? RequestRepository())
          .fetchReceivedRequestsPage(
            userId,
            offset: _receivedOffset,
            limit: pageSize,
          );
      final known = {for (final r in received.value) r.id};
      received.value = [
        ...received.value,
        ...page.where((r) => !known.contains(r.id)),
      ];
      _receivedOffset += page.length;
      hasMoreReceived.value = page.length >= pageSize;
    } catch (_) {
      // Leave hasMoreReceived as-is so the next scroll attempt retries.
    } finally {
      isLoadingMoreReceived.value = false;
    }
  }

  static Future<RequestModel?> send({
    required String postId,
    required String ownerId,
    RequestRepository? repository,
    AuthRepository? authRepository,
  }) async {
    final userId = (authRepository ?? AuthRepository()).currentUser?.id;
    if (userId == null || userId == ownerId) return null;

    final existing = sent.value.where((r) => r.postId == postId);
    if (existing.isNotEmpty) return existing.first;

    final request = await (repository ?? RequestRepository()).createRequest(
      postId: postId,
      requesterId: userId,
      ownerId: ownerId,
    );
    // The realtime INSERT for this row may land before or after this line;
    // upserting by id makes either order safe.
    sent.value = _upsert(sent.value, request);
    _sentOffset++;
    return request;
  }

  /// Declines [request]; the item stays available for other requests.
  static Future<void> decline(
    RequestModel request, {
    RequestRepository? repository,
  }) async {
    await (repository ?? RequestRepository()).declineRequest(request.id);
    List<RequestModel> mark(List<RequestModel> list) => [
      for (final r in list)
        if (r.id == request.id) r.copyWith(status: 'declined') else r,
    ];
    received.value = mark(received.value);
    sent.value = mark(sent.value);
  }

  /// Accepts [request], marks its post as given away (both in Supabase and
  /// the local product cache), and closes every other pending request on
  /// the same post.
  static Future<void> accept(
    RequestModel request, {
    RequestRepository? repository,
    PostRepository? postRepository,
  }) async {
    await (repository ?? RequestRepository()).acceptRequest(
      requestId: request.id,
      postId: request.postId,
    );
    await (postRepository ?? PostRepository()).markAsGiven(request.postId);
    ProductStore.markAsGiven(request.postId);

    received.value = [
      for (final r in received.value)
        if (r.id == request.id)
          r.copyWith(status: 'accepted')
        else if (r.postId == request.postId && r.isPending)
          r.copyWith(status: 'closed')
        else
          r,
    ];
    sent.value = [
      for (final r in sent.value)
        if (r.id == request.id)
          r.copyWith(status: 'accepted')
        else if (r.postId == request.postId && r.isPending)
          r.copyWith(status: 'closed')
        else
          r,
    ];
  }
}
