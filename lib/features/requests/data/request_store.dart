import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../add_item/data/repository/post_repository.dart';
import '../../auth/data/repository/auth_repository.dart';
import '../../home/data/product_store.dart';
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

  static StreamSubscription<List<RequestModel>>? _sentSubscription;
  static StreamSubscription<List<RequestModel>>? _receivedSubscription;

  /// Starts live Supabase Realtime subscriptions that keep [sent] and
  /// [received] in sync automatically — no manual refresh needed. Safe to
  /// call more than once; only the first call (per sign-in, see [reset])
  /// actually starts the subscriptions.
  static void startRealtimeSync({
    RequestRepository? repository,
    AuthRepository? authRepository,
  }) {
    final userId = (authRepository ?? AuthRepository()).currentUser?.id;
    if (userId == null || _sentSubscription != null) return;

    final repo = repository ?? RequestRepository();
    _sentSubscription = repo
        .streamSentRequests(userId)
        .listen((requests) => sent.value = requests, onError: (_) {});
    _receivedSubscription = repo
        .streamReceivedRequests(userId)
        .listen((requests) => received.value = requests, onError: (_) {});
  }

  /// Cancels the realtime subscriptions and clears the cache — call on
  /// logout so the next sign-in starts fresh, scoped to the new user.
  static void reset() {
    _sentSubscription?.cancel();
    _receivedSubscription?.cancel();
    _sentSubscription = null;
    _receivedSubscription = null;
    sent.value = [];
    received.value = [];
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
    sent.value = [request, ...sent.value];
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
