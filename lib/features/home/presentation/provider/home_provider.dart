import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../../../../core/realtime/realtime_event.dart';
import '../../../../core/realtime/realtime_log.dart';
import '../../../add_item/data/model/post_model.dart';
import '../../../add_item/data/repository/post_repository.dart';
import '../../../auth/data/repository/auth_repository.dart';
import '../../data/product_store.dart';
import '../../domain/category.dart';
import '../../domain/filter_options.dart';
import '../../domain/product.dart';

/// Drives the home grid with server-side pagination: products are fetched
/// [pageSize] at a time, and search / category / condition are applied by the
/// server so every page is full of matching products.
class HomeProvider extends ChangeNotifier {
  HomeProvider({
    AuthRepository? authRepository,
    PostRepository? postRepository,
    Duration searchDebounce = const Duration(milliseconds: 400),
  }) : _authRepository = authRepository ?? AuthRepository(),
       _postRepository = postRepository ?? PostRepository(),
       _searchDebounce = searchDebounce {
    // Wishlist and Requests look products up in [ProductStore], and it is
    // also what feeds the live changes applied to the grid below.
    ProductStore.startRealtimeSync();
    _changesSubscription = ProductStore.changes.listen(_onPostChange);
    _reconnectSubscription = ProductStore.reconnected.listen((_) {
      realtimeLog('home feed: realtime reconnected, reloading first page');
      refresh();
    });
    refresh();
  }

  static const int pageSize = 8;

  final AuthRepository _authRepository;
  final PostRepository _postRepository;
  final Duration _searchDebounce;

  String selectedCategory = kHomeCategories.first;
  FilterOptions filters = const FilterOptions();
  String searchQuery = '';

  final List<Product> _products = [];
  UnmodifiableListView<Product> get products => UnmodifiableListView(_products);

  /// True while the first page of the current query is loading.
  bool isLoading = true;

  /// True while a following page is loading (the grid shows a spinner).
  bool isLoadingMore = false;

  /// False once the server has returned a page shorter than [pageSize].
  bool hasMore = true;

  /// The last attempt to load a following page failed; [loadMore] retries.
  bool loadMoreFailed = false;

  // Rows already fetched for the current query; the next page starts here.
  int _nextOffset = 0;
  // Bumped whenever the query changes, so a slow response for an old query
  // can't overwrite the results of the new one.
  int _generation = 0;
  String? _activeKey;
  Timer? _searchTimer;
  bool _disposed = false;
  StreamSubscription<RealtimeEvent<PostModel>>? _changesSubscription;
  StreamSubscription<void>? _reconnectSubscription;

  // Live changes that arrive while the first page is loading. The response
  // may predate them, so they are replayed once it is in.
  final List<RealtimeEvent<PostModel>> _changesDuringLoad = [];
  bool _loadingFirstPage = false;

  @override
  void dispose() {
    _disposed = true;
    _searchTimer?.cancel();
    _changesSubscription?.cancel();
    _reconnectSubscription?.cancel();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Reloads the first page. The current products stay on screen until the
  /// new ones arrive, which is what pull-to-refresh wants.
  Future<void> refresh() => _loadFirstPage(clear: false);

  Future<void> loadMore() async {
    if (isLoading || isLoadingMore || !hasMore) return;
    final generation = _generation;
    isLoadingMore = true;
    loadMoreFailed = false;
    _notify();

    try {
      final posts = await _fetch(offset: _nextOffset);
      if (generation != _generation) return;
      _nextOffset += posts.length;
      // New posts pushed onto the top shift later pages, so a page can
      // repeat a product that was already loaded.
      final known = {for (final product in _products) product.id};
      _products.addAll(
        posts
            .where((post) => !known.contains(post.id))
            .map(ProductStore.productFromPost),
      );
      hasMore = posts.length >= pageSize;
    } catch (_) {
      if (generation != _generation) return;
      loadMoreFailed = true;
    }
    isLoadingMore = false;
    _notify();
  }

  Future<void> _loadFirstPage({required bool clear}) async {
    final generation = ++_generation;
    _activeKey = _queryKey;
    _loadingFirstPage = true;
    _changesDuringLoad.clear();
    if (clear) _products.clear();
    _nextOffset = 0;
    isLoading = true;
    isLoadingMore = false;
    loadMoreFailed = false;
    hasMore = true;
    _notify();

    try {
      final posts = await _fetch(offset: 0);
      if (generation != _generation) return;
      _products
        ..clear()
        ..addAll(posts.map(ProductStore.productFromPost));
      _nextOffset = posts.length;
      hasMore = posts.length >= pageSize;
      _loadingFirstPage = false;
      _changesDuringLoad
        ..forEach(_applyPostChange)
        ..clear();
    } catch (_) {
      if (generation != _generation) return;
      _loadingFirstPage = false;
      hasMore = false;
      // Let the same query be retried by the next search / filter change.
      _activeKey = null;
    }
    isLoading = false;
    _notify();
  }

  void _onPostChange(RealtimeEvent<PostModel> event) {
    if (_disposed) return;
    if (_loadingFirstPage) {
      _changesDuringLoad.add(event);
      return;
    }
    _applyPostChange(event);
  }

  /// Applies one realtime post change to the loaded products, in place and
  /// by id, so nothing is refetched and a post is never listed twice.
  void _applyPostChange(RealtimeEvent<PostModel> event) {
    final index = _products.indexWhere((p) => p.id == event.id);
    final post = event.record;

    if (event.type == RealtimeEventType.delete ||
        post == null ||
        !_matchesQuery(post)) {
      // Deleted, given away, or edited so it no longer fits the search or
      // filters: drop it. Every row after it moves up one place, so the
      // next page starts one row earlier.
      if (index < 0) return;
      _products.removeAt(index);
      if (_nextOffset > 0) _nextOffset--;
      realtimeLog('home feed: removed ${event.id}');
      _notify();
      return;
    }

    final product = ProductStore.productFromPost(post);
    if (index >= 0) {
      _products[index] = product;
      realtimeLog('home feed: updated ${event.id}');
      _notify();
    } else if (event.type == RealtimeEventType.insert) {
      // Newest first, so a new post goes on top; the next page starts one
      // row later. (An UPDATE for a post that isn't loaded is left alone: it
      // is an older one from a page that hasn't been fetched yet.)
      _products.insert(0, product);
      _nextOffset++;
      realtimeLog('home feed: added ${event.id}');
      _notify();
    }
  }

  /// Whether [post] belongs in the grid for the current search / category /
  /// condition — the same rules [_fetch] asks the server to apply.
  bool _matchesQuery(PostModel post) {
    if (post.isGiven) return false;
    if (post.userId == _authRepository.currentUser?.id) return false;

    if (selectedCategory != kHomeCategories.first) {
      // A post without a category is shown as "Other".
      if ((post.category ?? 'Other') != selectedCategory) return false;
    }
    if (filters.condition != 'All' && post.condition != filters.condition) {
      return false;
    }
    final search = searchQuery.trim().toLowerCase();
    if (search.isNotEmpty && !post.title.toLowerCase().contains(search)) {
      return false;
    }
    return true;
  }

  Future<List<PostModel>> _fetch({required int offset}) {
    final search = searchQuery.trim();
    return _postRepository.fetchAvailablePostsPage(
      offset: offset,
      limit: pageSize,
      excludeUserId: _authRepository.currentUser?.id,
      category: selectedCategory == kHomeCategories.first
          ? null
          : selectedCategory,
      condition: filters.condition == 'All' ? null : filters.condition,
      search: search.isEmpty ? null : search,
    );
  }

  String get _queryKey =>
      '${searchQuery.trim().toLowerCase()}|$selectedCategory|'
      '${filters.condition}';

  void _reloadIfQueryChanged() {
    if (_queryKey == _activeKey) return;
    _loadFirstPage(clear: true);
  }

  void onSearchChanged(String value) {
    searchQuery = value;
    _notify();
    // Wait for a pause in typing instead of querying on every keystroke.
    _searchTimer?.cancel();
    _searchTimer = Timer(_searchDebounce, _reloadIfQueryChanged);
  }

  void applyFilters(FilterOptions result) {
    filters = result;
    selectedCategory = result.category;
    _searchTimer?.cancel();
    _reloadIfQueryChanged();
    _notify();
  }

  bool get hasActiveSearch =>
      searchQuery.trim().isNotEmpty ||
      selectedCategory != kHomeCategories.first ||
      filters.activeCount > 0;

  void clearSearch() {
    searchQuery = '';
    filters = const FilterOptions();
    selectedCategory = kHomeCategories.first;
    _searchTimer?.cancel();
    _reloadIfQueryChanged();
    _notify();
  }
}
