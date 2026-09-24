import 'package:flutter/foundation.dart';
import '../../../core/cache/local_cache.dart';
import '../../../core/cache/network_errors.dart';
import '../../auth/data/repository/auth_repository.dart';
import '../../home/data/product_store.dart';
import '../domain/wish_item.dart';
import 'repository/wishlist_repository.dart';

/// Local reactive cache of the current user's wishlist, backed by Supabase
/// and mirrored to Hive.
///
/// Taps apply instantly (memory + Hive) and are then sent to Supabase:
///  * success: nothing more to do;
///  * the server rejected it: the change is rolled back;
///  * the device is offline: the change stays and is queued in the
///    `sync_queue` box, then replayed by [flushPending] when a sync next
///    succeeds. [pendingIds] tells the UI which entries aren't confirmed.
class WishlistStore {
  WishlistStore._();

  static final ValueNotifier<List<WishItem>> items =
      ValueNotifier<List<WishItem>>([]);

  static const Duration _maxAge = Duration(minutes: 10);
  static const String _itemsKey = 'items';
  static const String _queueKey = 'wishlist';
  static bool _cacheWired = false;
  static bool _flushing = false;

  /// Post ids whose wishlist change hasn't reached the server yet.
  static Set<String> get pendingIds => {
    for (final op in _queue()) op['id'] as String,
  };

  /// Loads the cached wishlist; call once at startup after [LocalCache.init].
  static void hydrateFromCache() {
    if (_cacheWired) return;
    _cacheWired = true;
    items.value = [
      for (final json in LocalCache.readList(LocalCache.wishlist, _itemsKey))
        if (json['id'] is String)
          WishItem(
            id: json['id'] as String,
            title: (json['title'] as String?) ?? '',
            note: (json['note'] as String?) ?? '',
          ),
    ];
    items.addListener(_persist);
  }

  static void _persist() {
    LocalCache.write(LocalCache.wishlist, _itemsKey, [
      for (final i in items.value)
        {'id': i.id, 'title': i.title, 'note': i.note},
    ]);
  }

  static List<Map<String, dynamic>> _queue() =>
      LocalCache.readList(LocalCache.syncQueue, _queueKey);

  static void _enqueue(String op, WishItem item) {
    // A newer change to the same post supersedes an older queued one.
    final queue = _queue()..removeWhere((e) => e['id'] == item.id);
    queue.add({
      'op': op,
      'id': item.id,
      'title': item.title,
      'note': item.note,
    });
    LocalCache.write(LocalCache.syncQueue, _queueKey, queue);
  }

  static void _dequeue(String id) {
    final queue = _queue()..removeWhere((e) => e['id'] == id);
    LocalCache.write(LocalCache.syncQueue, _queueKey, queue);
  }

  /// Wipes memory state on logout / account switch.
  static void reset() {
    items.value = [];
  }

  /// Replays wishlist changes made while offline, oldest first. Stops at the
  /// first connectivity failure; a change the server rejects is dropped and
  /// undone locally by the following [syncFromSupabase].
  static Future<void> flushPending({
    WishlistRepository? repository,
    AuthRepository? authRepository,
  }) async {
    final userId = (authRepository ?? AuthRepository()).currentUser?.id;
    if (userId == null || _flushing) return;
    _flushing = true;
    try {
      final repo = repository ?? WishlistRepository();
      for (final op in _queue()) {
        final id = op['id'] as String;
        try {
          if (op['op'] == 'add') {
            await repo.addToWishlist(
              userId: userId,
              postId: id,
              title: (op['title'] as String?) ?? '',
              note: op['note'] as String?,
            );
          } else {
            await repo.removeFromWishlist(userId: userId, postId: id);
          }
          _dequeue(id);
        } catch (e) {
          if (isConnectivityError(e)) return;
          _dequeue(id); // rejected by the server: give up on this change
        }
      }
    } finally {
      _flushing = false;
    }
  }

  static Future<void> syncFromSupabase({
    WishlistRepository? repository,
    AuthRepository? authRepository,
    bool force = true,
  }) async {
    final userId = (authRepository ?? AuthRepository()).currentUser?.id;
    if (userId == null) {
      items.value = [];
      return;
    }
    // The cached list is already on screen; only go to Supabase when it is
    // stale (or the caller insists, e.g. pull to refresh).
    if (!force && LocalCache.isFresh('wishlist', _maxAge)) return;
    await flushPending(repository: repository, authRepository: authRepository);
    final remote = await (repository ?? WishlistRepository()).fetchWishlist(
      userId,
    );
    var merged = [
      for (final entry in remote)
        WishItem(id: entry.postId, title: entry.title, note: entry.note ?? ''),
    ];
    // Changes still waiting to be sent are newer than the server's answer.
    for (final op in _queue()) {
      final id = op['id'] as String;
      if (op['op'] == 'add') {
        if (!merged.any((i) => i.id == id)) {
          merged = [
            ...merged,
            WishItem(
              id: id,
              title: (op['title'] as String?) ?? '',
              note: (op['note'] as String?) ?? '',
            ),
          ];
        }
      } else {
        merged = merged.where((i) => i.id != id).toList();
      }
    }
    items.value = merged;
    LocalCache.markSynced('wishlist');
    // The wishlist grid shows product cards; load any not in the store yet
    // in one query.
    ProductStore.ensureLoaded(merged.map((i) => i.id));
  }

  static Future<void> add(
    WishItem item, {
    WishlistRepository? repository,
    AuthRepository? authRepository,
  }) async {
    if (items.value.any((i) => i.id == item.id)) return;
    items.value = [...items.value, item];

    final userId = (authRepository ?? AuthRepository()).currentUser?.id;
    if (userId == null) return;
    try {
      await (repository ?? WishlistRepository()).addToWishlist(
        userId: userId,
        postId: item.id,
        title: item.title,
        note: item.note,
      );
      _dequeue(item.id);
    } catch (e) {
      if (isConnectivityError(e)) {
        _enqueue('add', item); // keep it and send when back online
      } else {
        items.value = items.value.where((i) => i.id != item.id).toList();
      }
    }
  }

  static Future<void> remove(
    String id, {
    WishlistRepository? repository,
    AuthRepository? authRepository,
  }) async {
    final removed = items.value.where((i) => i.id == id).toList();
    items.value = items.value.where((item) => item.id != id).toList();

    final userId = (authRepository ?? AuthRepository()).currentUser?.id;
    if (userId == null || removed.isEmpty) return;
    try {
      await (repository ?? WishlistRepository()).removeFromWishlist(
        userId: userId,
        postId: id,
      );
      _dequeue(id);
    } catch (e) {
      if (isConnectivityError(e)) {
        _enqueue('remove', removed.first);
      } else if (!items.value.any((i) => i.id == id)) {
        items.value = [...items.value, removed.first];
      }
    }
  }
}
