import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/realtime/realtime_event.dart';
import '../../../core/realtime/realtime_log.dart';
import '../../add_item/data/model/post_model.dart';
import '../../add_item/data/repository/post_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/product.dart';

/// In-memory store of products. Real posts are pulled in from Supabase via
/// [syncFromSupabase] or kept live via [startRealtimeSync]; new products
/// posted from the Add Product screen are prepended immediately so they
/// show right away.
class ProductStore {
  ProductStore._();

  static final ValueNotifier<List<Product>> items =
      ValueNotifier<List<Product>>([]);

  /// True until the first sync finishes (or fails), so screens can show a
  /// loading skeleton instead of an empty state.
  static final ValueNotifier<bool> isLoading = ValueNotifier<bool>(true);

  static StreamSubscription<RealtimeEvent<PostModel>>? _subscription;
  static bool _hasSynced = false;

  static final StreamController<RealtimeEvent<PostModel>> _changes =
      StreamController<RealtimeEvent<PostModel>>.broadcast();
  static final StreamController<void> _reconnects =
      StreamController<void>.broadcast();

  /// Every post INSERT / UPDATE / DELETE that arrived over Realtime, emitted
  /// after [items] has already been updated. Lets a screen that keeps its
  /// own (paginated) list apply the same change without refetching.
  static Stream<RealtimeEvent<PostModel>> get changes => _changes.stream;

  /// Fires when the channel re-joins after a dropped connection — events
  /// were missed in between, so listeners should reload.
  static Stream<void> get reconnected => _reconnects.stream;

  /// Starts a live Supabase Realtime subscription that keeps [items] in
  /// sync automatically whenever any post is created, edited, marked as
  /// given or deleted — no manual refresh needed. Safe to call more than
  /// once; only the first call actually starts the subscription.
  static void startRealtimeSync({PostRepository? repository}) {
    if (_subscription != null) return;
    final repo = repository ?? PostRepository();
    _subscription = repo.watchPosts().listen(
      (event) => _onEvent(event, repo),
      onError: (Object e) {
        realtimeLog('posts stream error: $e');
        isLoading.value = false;
      },
    );
  }

  /// Cancels the subscription (removing the Realtime channel). A later
  /// [startRealtimeSync] starts a fresh one.
  static void stopRealtimeSync() {
    _subscription?.cancel();
    _subscription = null;
    _hasSynced = false;
  }

  static void _onEvent(RealtimeEvent<PostModel> event, PostRepository repo) {
    switch (event.type) {
      case RealtimeEventType.subscribed:
        // Initial load, and catch-up after a reconnect.
        if (event.isReconnect) _reconnects.add(null);
        _hasSynced = true;
        syncFromSupabase(repository: repo).catchError((_) {});
      case RealtimeEventType.error:
        // Realtime is down; still load once so the UI isn't stuck loading.
        if (!_hasSynced) {
          _hasSynced = true;
          syncFromSupabase(repository: repo).catchError((_) {});
        }
      case RealtimeEventType.insert:
      case RealtimeEventType.update:
        final post = event.record;
        if (post == null) return;
        final known = items.value.any((p) => p.id == post.id);
        // A post the store has never seen is only worth adding while it is
        // still available; a given-away one is just history.
        if (known || !post.isGiven) update(productFromPost(post));
        _changes.add(event);
      case RealtimeEventType.delete:
        remove(event.id);
        _changes.add(event);
    }
  }

  static void add(Product product) {
    items.value = [product, ...items.value];
  }

  /// Replaces the stored copy of [product] (matched by id), or adds it if
  /// the store doesn't have it yet.
  static void update(Product product) {
    final exists = items.value.any((p) => p.id == product.id);
    items.value = exists
        ? [for (final p in items.value) p.id == product.id ? product : p]
        : [product, ...items.value];
  }

  static void remove(String id) {
    items.value = items.value.where((p) => p.id != id).toList();
  }

  static void markAsGiven(String id) {
    items.value = [
      for (final product in items.value)
        if (product.id == id) product.copyWith(isGiven: true) else product,
    ];
  }

  /// Fetches every post that hasn't been given away yet and merges it into
  /// the store, replacing any stale local copy of the same post.
  static Future<void> syncFromSupabase({PostRepository? repository}) async {
    try {
      final posts = await (repository ?? PostRepository())
          .fetchAvailablePosts();
      final remoteProducts = posts.map(productFromPost).toList();
      final remoteIds = remoteProducts.map((p) => p.id).toSet();
      final localOnly = items.value
          .where((p) => !remoteIds.contains(p.id))
          .toList();
      items.value = [...remoteProducts, ...localOnly];
    } finally {
      isLoading.value = false;
    }
  }

  static Product productFromPost(PostModel post) {
    return Product(
      id: post.id,
      name: post.title,
      category: post.category ?? 'Other',
      color: AppColors.primary,
      description: post.description ?? '',
      condition: post.condition,
      address: post.address,
      imageUrls: post.imageUrls,
      userId: post.userId,
      isGiven: post.isGiven,
    );
  }
}
