import 'package:flutter/foundation.dart';
import '../../auth/data/repository/auth_repository.dart';
import '../domain/wish_item.dart';
import 'repository/wishlist_repository.dart';

/// Local reactive cache of the current user's wishlist, backed by Supabase.
/// Updates are applied optimistically and rolled back if the remote call
/// fails.
class WishlistStore {
  WishlistStore._();

  static final ValueNotifier<List<WishItem>> items =
      ValueNotifier<List<WishItem>>([]);

  static Future<void> syncFromSupabase({
    WishlistRepository? repository,
    AuthRepository? authRepository,
  }) async {
    final userId = (authRepository ?? AuthRepository()).currentUser?.id;
    if (userId == null) {
      items.value = [];
      return;
    }
    final remote = await (repository ?? WishlistRepository()).fetchWishlist(
      userId,
    );
    items.value = [
      for (final entry in remote)
        WishItem(id: entry.postId, title: entry.title, note: entry.note ?? ''),
    ];
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
    } catch (_) {
      items.value = items.value.where((i) => i.id != item.id).toList();
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
    } catch (_) {
      if (!items.value.any((i) => i.id == id)) {
        items.value = [...items.value, removed.first];
      }
    }
  }
}
