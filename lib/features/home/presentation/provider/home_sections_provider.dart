import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/realtime/realtime_event.dart';
import '../../../../core/realtime/realtime_log.dart';
import '../../../add_item/data/model/post_model.dart';
import '../../../add_item/data/repository/post_repository.dart';
import '../../../auth/data/repository/auth_repository.dart';
import '../../data/product_store.dart';
import '../../domain/category.dart';
import '../../domain/product.dart';

/// Drives the home screen: the newest [sectionSize] products of every
/// category, one horizontal row each. The full list of a category is on
/// its own screen (see [HomeProvider] with a fixed category).
///
/// Local-first like [HomeProvider]: cached products are grouped and shown
/// right away, then every category is refreshed from Supabase in parallel.
class HomeSectionsProvider extends ChangeNotifier {
  HomeSectionsProvider({
    AuthRepository? authRepository,
    PostRepository? postRepository,
  }) : _authRepository = authRepository ?? AuthRepository(),
       _postRepository = postRepository ?? PostRepository() {
    ProductStore.startRealtimeSync();
    _changesSubscription = ProductStore.changes.listen(_applyPostChange);
    _reconnectSubscription = ProductStore.reconnected.listen((_) {
      realtimeLog('home sections: realtime reconnected, reloading');
      refresh();
    });
    _showCached();
    refresh();
  }

  static const int sectionSize = 10;

  /// Every category except the "All" pseudo-category.
  static final List<String> categories = kHomeCategories.skip(1).toList();

  final AuthRepository _authRepository;
  final PostRepository _postRepository;

  final Map<String, List<Product>> _sections = {
    for (final category in categories) category: <Product>[],
  };

  /// The products of [category], newest first (at most [sectionSize]).
  List<Product> productsOf(String category) =>
      List.unmodifiable(_sections[category] ?? const <Product>[]);

  /// Categories that have at least one product, in display order.
  List<String> get visibleCategories =>
      categories.where((c) => _sections[c]!.isNotEmpty).toList();

  /// True until the first load finishes when nothing was cached.
  bool isLoading = true;

  int _generation = 0;
  bool _disposed = false;
  StreamSubscription<RealtimeEvent<PostModel>>? _changesSubscription;
  StreamSubscription<void>? _reconnectSubscription;

  @override
  void dispose() {
    _disposed = true;
    _changesSubscription?.cancel();
    _reconnectSubscription?.cancel();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _showCached() {
    final me = _authRepository.currentUser?.id;
    final cached =
        ProductStore.items.value
            .where((p) => !p.isGiven && p.userId != me && p.createdAt != null)
            .toList()
          ..sort((a, b) {
            final byDate = b.createdAt!.compareTo(a.createdAt!);
            return byDate != 0 ? byDate : b.id.compareTo(a.id);
          });
    for (final product in cached) {
      final section = _sections[product.category];
      if (section != null && section.length < sectionSize) {
        section.add(product);
      }
    }
    isLoading = visibleCategories.isEmpty;
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    final me = _authRepository.currentUser?.id;
    final results = await Future.wait(
      categories.map((category) async {
        try {
          return await _postRepository.fetchAvailablePostsPage(
            limit: sectionSize,
            excludeUserId: me,
            category: category,
          );
        } catch (_) {
          // Offline / server error: keep whatever this row already shows.
          return null;
        }
      }),
    );
    if (_disposed || generation != _generation) return;

    final fresh = <Product>[];
    for (var i = 0; i < categories.length; i++) {
      final posts = results[i];
      if (posts == null) continue;
      final products = posts.map(ProductStore.productFromPost).toList();
      _sections[categories[i]] = products;
      fresh.addAll(products);
    }
    ProductStore.upsertAll(fresh);
    isLoading = false;
    _notify();
  }

  /// Applies one realtime post change to the rows, in place and by id.
  void _applyPostChange(RealtimeEvent<PostModel> event) {
    if (_disposed) return;
    final post = event.record;
    final product =
        event.type != RealtimeEventType.delete &&
            post != null &&
            !post.isGiven &&
            post.userId != _authRepository.currentUser?.id
        ? ProductStore.productFromPost(post)
        : null;

    var changed = false;
    for (final entry in _sections.entries) {
      final section = entry.value;
      final index = section.indexWhere((p) => p.id == event.id);
      if (index < 0) continue;
      if (product != null && product.category == entry.key) {
        section[index] = product; // edited, same row
      } else {
        section.removeAt(index); // deleted, given away or moved category
      }
      changed = true;
    }

    // A new post (or one edited into another category) goes first in its
    // row. An UPDATE for a post not shown is an older one: left alone.
    if (product != null) {
      final section = _sections[product.category];
      final alreadyShown = section?.any((p) => p.id == product.id) ?? true;
      if (!alreadyShown &&
          (changed || event.type == RealtimeEventType.insert)) {
        section!.insert(0, product);
        if (section.length > sectionSize) section.removeLast();
        changed = true;
      }
    }
    if (changed) _notify();
  }
}
