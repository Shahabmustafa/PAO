import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/cache/local_cache.dart';
import '../../../core/realtime/realtime_event.dart';
import '../../../core/realtime/realtime_log.dart';
import '../../add_item/data/model/post_model.dart';
import '../../add_item/data/repository/post_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/product.dart';

/// In-memory store of products, mirrored to the Hive `products` box so the
/// feed, wishlist and requests can render before the network answers.
///
/// Only the newest page of the feed is fetched by [syncFromSupabase] (never
/// the whole table); posts referenced elsewhere (wishlist, requests) are
/// pulled in by id with [ensureLoaded]. Realtime keeps everything current.
/// New products posted from the Add Product screen are prepended
/// immediately so they show right away.
class ProductStore {
  ProductStore._();

  static final ValueNotifier<List<Product>> items =
      ValueNotifier<List<Product>>([]);

  /// True until the first sync finishes (or fails), so screens can show a
  /// loading skeleton instead of an empty state.
  static final ValueNotifier<bool> isLoading = ValueNotifier<bool>(true);

  /// How many posts the store's background sync asks for.
  static const int syncPageSize = 20;
  static const int _cacheLimit = 200;
  static const String _cacheKey = 'feed';

  static StreamSubscription<RealtimeEvent<PostModel>>? _subscription;
  static Timer? _persistTimer;
  static bool _cacheWired = false;
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

  /// Loads the cached products (if any) and starts mirroring changes back
  /// to the cache. Call once at startup, after [LocalCache.init]; cheap and
  /// synchronous, so cached content is there on the first frame.
  static void hydrateFromCache() {
    if (_cacheWired) return;
    _cacheWired = true;
    final cached = <Product>[];
    for (final json in LocalCache.readList(LocalCache.products, _cacheKey)) {
      try {
        cached.add(productFromPost(PostModel.fromJson(json)));
      } catch (_) {
        // Skip an entry written by an older/newer version.
      }
    }
    if (cached.isNotEmpty) {
      items.value = cached;
      isLoading.value = false;
    }
    items.addListener(_schedulePersist);
  }

  static void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 600), _persist);
  }

  static void _persist() {
    final posts = <Map<String, dynamic>>[];
    for (final p in items.value) {
      final createdAt = p.createdAt;
      // Products that never came from the server (no id/date) aren't cached.
      if (createdAt == null || p.userId == null) continue;
      posts.add(
        PostModel(
          id: p.id,
          userId: p.userId!,
          title: p.name,
          description: p.description,
          category: p.category,
          address: p.address,
          condition: p.condition,
          imageUrls: p.imageUrls,
          isGiven: p.isGiven,
          createdAt: createdAt,
        ).toJson(),
      );
      if (posts.length >= _cacheLimit) break;
    }
    LocalCache.write(LocalCache.products, _cacheKey, posts);
  }

  /// Forgets everything held in memory (logout / account switch). The
  /// on-disk cache is wiped by [LocalCache].
  static void reset() {
    _persistTimer?.cancel();
    items.value = [];
    isLoading.value = true;
    _hasSynced = false;
  }

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

  /// [update] for many products at once, with a single change notification.
  static void upsertAll(List<Product> products) {
    if (products.isEmpty) return;
    final byId = {for (final p in products) p.id: p};
    final merged = [for (final p in items.value) byId.remove(p.id) ?? p];
    items.value = [...byId.values, ...merged];
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

  /// Fetches the newest page of available posts and merges it into the
  /// store: every fetched post replaces its local copy, and a cached post
  /// that falls inside the fetched time window but wasn't returned is gone
  /// (deleted or given away while we weren't listening) and is dropped.
  /// Older cached posts are left alone.
  static Future<void> syncFromSupabase({PostRepository? repository}) async {
    try {
      final posts = await (repository ?? PostRepository())
          .fetchAvailablePostsPage(limit: syncPageSize);
      final remote = posts.map(productFromPost).toList();
      final remoteIds = {for (final p in remote) p.id};
      final windowStart = posts.length >= syncPageSize
          ? posts.last.createdAt
          : null; // short page: the whole table was covered
      final kept = items.value.where((p) {
        if (remoteIds.contains(p.id)) return false;
        final createdAt = p.createdAt;
        if (createdAt == null || p.isGiven) return true;
        // Someone else's available post inside the window but missing from
        // the server's answer no longer exists.
        return windowStart != null && createdAt.isBefore(windowStart);
      });
      items.value = [...remote, ...kept];
    } finally {
      isLoading.value = false;
    }
  }

  /// Makes sure the posts with [ids] are in the store, fetching only the
  /// missing ones, in a single query. Used by screens that show posts
  /// looked up by id (wishlist, requests) so they don't depend on the feed
  /// having loaded them.
  static Future<void> ensureLoaded(
    Iterable<String> ids, {
    PostRepository? repository,
  }) async {
    final known = {for (final p in items.value) p.id};
    final missing = ids.where((id) => !known.contains(id)).toSet().toList();
    if (missing.isEmpty) return;
    try {
      final posts = await (repository ?? PostRepository()).fetchPostsByIds(
        missing,
      );
      if (posts.isEmpty) return;
      final have = {for (final p in items.value) p.id};
      items.value = [
        ...items.value,
        for (final post in posts)
          if (!have.contains(post.id)) productFromPost(post),
      ];
    } catch (_) {
      // Offline: whatever is cached stays.
    }
  }

  /// Re-reads one post (product detail): updates it in place, or removes it
  /// when the server no longer has it.
  static Future<void> refreshOne(
    String id, {
    PostRepository? repository,
  }) async {
    try {
      final post = await (repository ?? PostRepository()).fetchPostById(id);
      if (post == null) {
        remove(id);
      } else {
        update(productFromPost(post));
      }
    } catch (_) {
      // Offline: keep showing the cached copy.
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
      createdAt: post.createdAt,
    );
  }
}
