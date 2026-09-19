import 'dart:async';
import 'package:flutter/foundation.dart';
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

  static StreamSubscription<List<PostModel>>? _subscription;

  /// Starts a live Supabase Realtime subscription that keeps [items] in
  /// sync automatically whenever any post is created, edited, or marked as
  /// given — no manual refresh needed. Safe to call more than once; only
  /// the first call actually starts the subscription.
  static void startRealtimeSync({PostRepository? repository}) {
    if (_subscription != null) return;
    _subscription = (repository ?? PostRepository())
        .streamAvailablePosts()
        .listen((posts) {
          final remoteProducts = posts.map(productFromPost).toList();
          final remoteIds = remoteProducts.map((p) => p.id).toSet();
          final localOnly = items.value
              .where((p) => !remoteIds.contains(p.id))
              .toList();
          items.value = [...remoteProducts, ...localOnly];
          isLoading.value = false;
        }, onError: (_) => isLoading.value = false);
  }

  static void add(Product product) {
    items.value = [product, ...items.value];
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
      imageUrls: post.imageUrls,
      userId: post.userId,
      isGiven: post.isGiven,
    );
  }
}
