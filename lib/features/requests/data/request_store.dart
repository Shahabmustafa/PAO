import 'dart:async';
import 'package:flutter/foundation.dart';
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

  static StreamSubscription<RealtimeEvent<RequestModel>>? _subscription;
  static bool _hasSynced = false;

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
          sent.value = _upsert(sent.value, request);
        } else if (event.tag == RequestRemoteDataSource.receivedTag) {
          received.value = _upsert(received.value, request);
        }
      case RealtimeEventType.delete:
        // Deletes can't be filtered by user, so ignore ids we don't hold.
        if (sent.value.any((r) => r.id == event.id)) {
          sent.value = sent.value.where((r) => r.id != event.id).toList();
        }
        if (received.value.any((r) => r.id == event.id)) {
          received.value = received.value
              .where((r) => r.id != event.id)
              .toList();
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
  }

  /// Drops every request on [postId] from the local cache — used after the
  /// post is deleted, which removes its requests in Supabase too.
  static void removeForPost(String postId) {
    sent.value = sent.value.where((r) => r.postId != postId).toList();
    received.value = received.value.where((r) => r.postId != postId).toList();
  }

  static Future<void> syncSentFromSupabase({
    RequestRepository? repository,
    AuthRepository? authRepository,
  }) async {
    final userId = (authRepository ?? AuthRepository()).currentUser?.id;
    if (userId == null) {
      sent.value = [];
      return;
    }
    sent.value = await (repository ?? RequestRepository()).fetchSentRequests(
      userId,
    );
  }

  static Future<void> syncReceivedFromSupabase({
    RequestRepository? repository,
    AuthRepository? authRepository,
  }) async {
    final userId = (authRepository ?? AuthRepository()).currentUser?.id;
    if (userId == null) {
      received.value = [];
      return;
    }
    received.value = await (repository ?? RequestRepository())
        .fetchReceivedRequests(userId);
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
    return request;
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
