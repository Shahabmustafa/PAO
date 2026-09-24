import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pao/core/realtime/realtime_event.dart';
import 'package:pao/features/add_item/data/model/post_model.dart';
import 'package:pao/features/auth/data/model/user_model.dart';
import 'package:pao/features/home/data/product_store.dart';
import 'package:pao/features/home/domain/filter_options.dart';
import 'package:pao/features/home/presentation/provider/home_provider.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';

void main() {
  late FakeAuthRepository auth;
  late FakePostRepository posts;
  late HomeProvider provider;
  // The channel ProductStore listens to; tests push realtime events into it.
  final realtime = FakePostRepository();

  setUpAll(() async {
    await initFakeSupabase();
    // The provider's constructor starts the realtime sync; prime it with a
    // fake so no real Supabase stream is opened.
    ProductStore.startRealtimeSync(repository: realtime);
  });

  tearDownAll(ProductStore.stopRealtimeSync);

  setUp(() {
    auth = FakeAuthRepository(user: const UserModel(id: 'me'));
    posts = FakePostRepository();
    ProductStore.items.value = []; // nothing cached from an earlier test
  });

  tearDown(() => provider.dispose());

  /// [count] available posts named "Item 1" .. "Item N", newest first.
  void seed(int count, {String category = 'Electronics'}) {
    posts.available = [
      for (var i = 1; i <= count; i++)
        makePost(id: 'p$i', title: 'Item $i', category: category),
    ];
  }

  Future<HomeProvider> create() async {
    provider = HomeProvider(
      authRepository: auth,
      postRepository: posts,
      searchDebounce: Duration.zero,
    );
    await pumpEventQueue();
    return provider;
  }

  List<String> names() => provider.products.map((p) => p.name).toList();

  group('first page', () {
    test(
      'loads only one page of products and knows more are available',
      () async {
        seed(50);

        await create();

        expect(provider.products, hasLength(20));
        expect(names().first, 'Item 1');
        expect(names().last, 'Item 20');
        expect(provider.isLoading, isFalse);
        expect(provider.hasMore, isTrue);
        expect(posts.pageCalls.single.afterId, isNull);
        expect(posts.pageCalls.single.limit, 20);
      },
    );

    test('is loading until the server answers', () async {
      seed(3);
      posts.pageGate = Completer<void>();

      provider = HomeProvider(authRepository: auth, postRepository: posts);
      await pumpEventQueue();
      expect(provider.isLoading, isTrue);
      expect(provider.products, isEmpty);

      posts.pageGate!.complete();
      await pumpEventQueue();
      expect(provider.isLoading, isFalse);
      expect(provider.products, hasLength(3));
    });

    test('a short page means there is nothing more to load', () async {
      seed(5);

      await create();
      await provider.loadMore();

      expect(provider.products, hasLength(5));
      expect(provider.hasMore, isFalse);
      expect(posts.pageCalls, hasLength(1), reason: 'no extra request');
    });

    test('asks the server to leave out the user\'s own listings', () async {
      seed(3);
      posts.available = [
        makePost(id: 'mine', userId: 'me', title: 'My Own Listing'),
        ...posts.available,
      ];

      await create();

      expect(posts.pageCalls.single.excludeUserId, 'me');
      expect(names(), isNot(contains('My Own Listing')));
    });

    test('signed out, nothing is excluded', () async {
      auth.user = null;
      seed(3);

      await create();

      expect(posts.pageCalls.single.excludeUserId, isNull);
    });

    test('a failed first load leaves an empty list and stops paging', () async {
      posts.pageError = Exception('offline');

      await create();

      expect(provider.products, isEmpty);
      expect(provider.isLoading, isFalse);
      expect(provider.hasMore, isFalse);
    });
  });

  group('loadMore', () {
    test('appends the next page, using the last row as the cursor', () async {
      seed(50);
      await create();

      await provider.loadMore();

      expect(provider.products, hasLength(40));
      expect(names()[20], 'Item 21');
      expect(posts.pageCalls.last.afterId, 'p20');
      expect(provider.hasMore, isTrue);

      await provider.loadMore();

      expect(provider.products, hasLength(50));
      expect(posts.pageCalls.last.afterId, 'p40');
      expect(provider.hasMore, isFalse, reason: 'last page had only 10');
    });

    test('shows the loading state while a page is in flight', () async {
      seed(50);
      await create();
      posts.pageGate = Completer<void>();

      final pending = provider.loadMore();
      await pumpEventQueue();
      expect(provider.isLoadingMore, isTrue);

      posts.pageGate!.complete();
      await pending;
      expect(provider.isLoadingMore, isFalse);
      expect(provider.products, hasLength(40));
    });

    test('ignores calls while a page is already loading', () async {
      seed(50);
      await create();
      posts.pageGate = Completer<void>();

      final first = provider.loadMore();
      await provider.loadMore();
      await provider.loadMore();
      posts.pageGate!.complete();
      await first;

      expect(posts.pageCalls, hasLength(2), reason: 'initial + one page');
      expect(provider.products, hasLength(40));
    });

    test('a post added above does not shift or repeat later pages', () async {
      seed(50);
      await create();
      // Offset paging would now repeat "Item 20" on the second page.
      posts.available = [makePost(id: 'new', title: 'New'), ...posts.available];

      await provider.loadMore();

      final ids = provider.products.map((p) => p.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      expect(ids, hasLength(40));
      expect(names()[20], 'Item 21');
    });

    test('a failure keeps the products and can be retried', () async {
      seed(50);
      await create();
      posts.pageError = Exception('offline');

      await provider.loadMore();

      expect(provider.loadMoreFailed, isTrue);
      expect(provider.isLoadingMore, isFalse);
      expect(provider.products, hasLength(20));

      posts.pageError = null;
      await provider.loadMore();

      expect(provider.loadMoreFailed, isFalse);
      expect(provider.products, hasLength(40));
    });
  });

  group('search and filters', () {
    setUp(() {
      posts.available = [
        makePost(id: '1', title: 'Wireless Headphones', condition: 'New'),
        makePost(
          id: '2',
          title: 'Novel Collection',
          category: 'Books',
          condition: 'Old',
        ),
        makePost(
          id: '3',
          title: 'Football',
          category: 'Sports',
          condition: 'New',
        ),
        makePost(id: '4', title: 'Old Phone', condition: 'Old'),
      ];
    });

    test('starts with no filters and no active search', () async {
      await create();

      expect(provider.selectedCategory, 'All');
      expect(provider.searchQuery, '');
      expect(provider.filters.activeCount, 0);
      expect(provider.hasActiveSearch, isFalse);
      final call = posts.pageCalls.single;
      expect(call.category, isNull);
      expect(call.condition, isNull);
      expect(call.search, isNull);
    });

    test('search is sent trimmed and reloads from the first page', () async {
      await create();

      provider.onSearchChanged('  head ');
      await pumpEventQueue();

      expect(posts.pageCalls.last.search, 'head');
      expect(posts.pageCalls.last.afterId, isNull);
      expect(names(), ['Wireless Headphones']);
    });

    test('typing quickly sends a single request', () async {
      await create();

      provider.onSearchChanged('h');
      provider.onSearchChanged('he');
      provider.onSearchChanged('hea');
      await pumpEventQueue();

      expect(posts.pageCalls, hasLength(2), reason: 'initial + one search');
      expect(posts.pageCalls.last.search, 'hea');
    });

    test('whitespace-only or unchanged text does not refetch', () async {
      await create();

      provider.onSearchChanged('   ');
      await pumpEventQueue();

      expect(posts.pageCalls, hasLength(1));
    });

    test('search with no match gives an empty list', () async {
      await create();

      provider.onSearchChanged('zzz');
      await pumpEventQueue();

      expect(provider.products, isEmpty);
      expect(provider.isLoading, isFalse);
    });

    test('category filter is applied by the server', () async {
      await create();

      provider.applyFilters(const FilterOptions(category: 'Books'));
      await pumpEventQueue();

      expect(posts.pageCalls.last.category, 'Books');
      expect(names(), ['Novel Collection']);
      expect(provider.selectedCategory, 'Books');
    });

    test('condition filter is applied by the server', () async {
      await create();

      provider.applyFilters(const FilterOptions(condition: 'Old'));
      await pumpEventQueue();

      expect(posts.pageCalls.last.condition, 'Old');
      expect(names(), ['Novel Collection', 'Old Phone']);
    });

    test('search, category and condition combine (AND)', () async {
      await create();

      provider.onSearchChanged('phone');
      provider.applyFilters(
        const FilterOptions(condition: 'Old', category: 'Electronics'),
      );
      await pumpEventQueue();

      expect(names(), ['Old Phone']);
      final call = posts.pageCalls.last;
      expect(
        (call.search, call.category, call.condition),
        ('phone', 'Electronics', 'Old'),
      );
    });

    test('changing the query starts again from the first page', () async {
      seed(50);
      await create();
      await provider.loadMore();
      expect(provider.products, hasLength(40));

      provider.applyFilters(const FilterOptions(category: 'Electronics'));
      await pumpEventQueue();

      expect(posts.pageCalls.last.afterId, isNull);
      expect(provider.products, hasLength(20));
    });

    test('a slow answer for an old query is ignored', () async {
      await create();
      posts.pageGate = Completer<void>();
      provider.onSearchChanged('head');
      await pumpEventQueue(); // request for "head" is now held

      final held = posts.pageGate!;
      posts.pageGate = null;
      provider.onSearchChanged('novel');
      await pumpEventQueue(); // "novel" answers first
      expect(names(), ['Novel Collection']);

      held.complete(); // the stale "head" answer arrives late
      await pumpEventQueue();

      expect(names(), ['Novel Collection']);
    });

    test('hasActiveSearch reflects any search, category or filter', () async {
      await create();

      provider.onSearchChanged('x');
      expect(provider.hasActiveSearch, isTrue);
      provider.onSearchChanged('   ');
      expect(provider.hasActiveSearch, isFalse, reason: 'whitespace only');

      provider.applyFilters(const FilterOptions(category: 'Toys'));
      expect(provider.hasActiveSearch, isTrue);
    });

    test('clearSearch resets everything and reloads', () async {
      await create();
      provider.onSearchChanged('phone');
      provider.applyFilters(
        const FilterOptions(condition: 'Old', category: 'Electronics'),
      );
      await pumpEventQueue();

      provider.clearSearch();
      await pumpEventQueue();

      expect(provider.searchQuery, '');
      expect(provider.selectedCategory, 'All');
      expect(provider.filters.activeCount, 0);
      expect(provider.hasActiveSearch, isFalse);
      expect(names(), hasLength(4));
    });

    test('changes notify listeners', () async {
      await create();
      var notified = 0;
      provider.addListener(() => notified++);

      provider.onSearchChanged('a');
      expect(notified, greaterThan(0));
    });
  });

  group('live posts', () {
    void push(RealtimeEvent<PostModel> event) =>
        realtime.postsController!.add(event);

    test('a new post appears at the top without refetching', () async {
      seed(3);
      await create();
      final calls = posts.pageCalls.length;

      push(
        insertEvent('new', makePost(id: 'new', title: 'Fresh', userId: 'u2')),
      );
      await pumpEventQueue();

      expect(names(), ['Fresh', 'Item 1', 'Item 2', 'Item 3']);
      expect(posts.pageCalls, hasLength(calls), reason: 'no refetch');
    });

    test('the same post delivered twice is listed once', () async {
      seed(2);
      await create();
      final post = makePost(id: 'new', title: 'Fresh', userId: 'u2');

      push(insertEvent('new', post));
      push(insertEvent('new', post));
      await pumpEventQueue();

      expect(provider.products.where((p) => p.id == 'new'), hasLength(1));
    });

    test('a post that is already loaded is not added again', () async {
      seed(2);
      await create();

      push(
        insertEvent('p1', makePost(id: 'p1', title: 'Item 1', userId: 'u2')),
      );
      await pumpEventQueue();

      expect(names(), ['Item 1', 'Item 2']);
    });

    test('my own new post is not shown in the feed', () async {
      seed(2);
      await create();

      push(insertEvent('mine', makePost(id: 'mine', userId: 'me')));
      await pumpEventQueue();

      expect(provider.products.map((p) => p.id), ['p1', 'p2']);
    });

    test('an edit updates the post in place', () async {
      seed(3);
      await create();

      push(updateEvent('p2', makePost(id: 'p2', title: 'Item 2 (edited)')));
      await pumpEventQueue();

      expect(names(), ['Item 1', 'Item 2 (edited)', 'Item 3']);
    });

    test('a post that is given away leaves the feed', () async {
      seed(3);
      await create();

      push(updateEvent('p2', makePost(id: 'p2', isGiven: true)));
      await pumpEventQueue();

      expect(names(), ['Item 1', 'Item 3']);
    });

    test('a deleted post leaves the feed', () async {
      seed(3);
      await create();

      push(deleteEvent('p1'));
      await pumpEventQueue();

      expect(names(), ['Item 2', 'Item 3']);
    });

    test('a delete for a post that is not loaded changes nothing', () async {
      seed(3);
      await create();
      var notified = 0;
      provider.addListener(() => notified++);

      push(deleteEvent('unknown'));
      await pumpEventQueue();

      expect(notified, 0);
      expect(provider.products, hasLength(3));
    });

    test(
      'an edit that no longer fits the category filter removes it',
      () async {
        seed(3, category: 'Electronics');
        await create();
        provider.applyFilters(const FilterOptions(category: 'Electronics'));
        await pumpEventQueue();

        push(updateEvent('p1', makePost(id: 'p1', category: 'Sports')));
        await pumpEventQueue();

        expect(names(), ['Item 2', 'Item 3']);
      },
    );

    test('a new post is only shown if it matches the active filters', () async {
      seed(2);
      await create();
      provider.applyFilters(
        const FilterOptions(category: 'Electronics', condition: 'New'),
      );
      provider.onSearchChanged('phone');
      await pumpEventQueue();

      push(
        insertEvent(
          'a',
          makePost(id: 'a', title: 'Old Phone', condition: 'Old'),
        ),
      );
      push(
        insertEvent(
          'b',
          makePost(id: 'b', title: 'Football', condition: 'New'),
        ),
      );
      push(
        insertEvent(
          'c',
          makePost(
            id: 'c',
            title: 'Phone',
            category: 'Sports',
            condition: 'New',
          ),
        ),
      );
      push(
        insertEvent(
          'd',
          makePost(id: 'd', title: 'SMART PHONE', condition: 'New'),
        ),
      );
      await pumpEventQueue();

      expect(provider.products.map((p) => p.id), ['d']);
    });

    test('a post without a category matches the "Other" filter', () async {
      await create();
      provider.applyFilters(const FilterOptions(category: 'Other'));
      await pumpEventQueue();

      push(insertEvent('n', makePost(id: 'n', category: null)));
      await pumpEventQueue();

      expect(provider.products.map((p) => p.id), ['n']);
    });

    test('paging stays aligned after live inserts and removals', () async {
      seed(50);
      await create();

      // One new post on top, one loaded post removed: net zero.
      push(insertEvent('new', makePost(id: 'new', title: 'New', userId: 'u2')));
      push(deleteEvent('p3'));
      await pumpEventQueue();
      await provider.loadMore();

      expect(posts.pageCalls.last.afterId, 'p20');
      final ids = provider.products.map((p) => p.id).toList();
      expect(ids.toSet(), hasLength(ids.length), reason: 'no duplicates');
    });

    test('a change that arrives during the first load is not lost', () async {
      seed(2);
      posts.pageGate = Completer<void>();
      provider = HomeProvider(
        authRepository: auth,
        postRepository: posts,
        searchDebounce: Duration.zero,
      );
      await pumpEventQueue();
      expect(provider.isLoading, isTrue);

      push(
        insertEvent('new', makePost(id: 'new', title: 'Fresh', userId: 'u2')),
      );
      await pumpEventQueue();
      posts.pageGate!.complete();
      await pumpEventQueue();

      expect(names(), ['Fresh', 'Item 1', 'Item 2']);
    });

    test('a reconnect reloads the first page', () async {
      seed(3);
      await create();
      final calls = posts.pageCalls.length;

      seed(4);
      push(subscribedEvent(isReconnect: true));
      await pumpEventQueue();

      expect(posts.pageCalls, hasLength(calls + 1));
      expect(provider.products, hasLength(4));
    });

    test('stops listening once disposed', () async {
      seed(2);
      await create();
      final other = HomeProvider(
        authRepository: auth,
        postRepository: posts,
        searchDebounce: Duration.zero,
      );
      await pumpEventQueue();
      var notified = 0;
      other.addListener(() => notified++);
      other.dispose();

      push(insertEvent('late', makePost(id: 'late', userId: 'u2')));
      await pumpEventQueue();

      // A disposed ChangeNotifier throws if it is notified; reaching here
      // means the event was ignored.
      expect(notified, 0);
    });
  });
}
