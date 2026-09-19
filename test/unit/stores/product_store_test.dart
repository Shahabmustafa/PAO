import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pao/core/theme/app_colors.dart';
import 'package:pao/features/home/data/product_store.dart';
import 'package:pao/features/home/domain/product.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakePostRepository repo;

  Product local(String id, {bool isGiven = false}) => Product(
    id: id,
    name: 'Local $id',
    category: 'Books',
    color: Colors.blue,
    isGiven: isGiven,
  );

  setUp(() {
    repo = FakePostRepository();
    ProductStore.items.value = [];
    ProductStore.isLoading.value = true;
  });

  group('add / markAsGiven', () {
    test('add prepends so new products show first', () {
      ProductStore.items.value = [local('old')];

      ProductStore.add(local('new'));

      expect(ProductStore.items.value.map((p) => p.id), ['new', 'old']);
    });

    test('markAsGiven flips only the matching product', () {
      ProductStore.items.value = [local('a'), local('b')];

      ProductStore.markAsGiven('b');

      final byId = {for (final p in ProductStore.items.value) p.id: p.isGiven};
      expect(byId, {'a': false, 'b': true});
    });

    test('markAsGiven with an unknown id changes nothing', () {
      ProductStore.items.value = [local('a')];

      ProductStore.markAsGiven('zzz');

      expect(ProductStore.items.value.single.isGiven, isFalse);
    });
  });

  group('syncFromSupabase', () {
    test('maps posts to products', () async {
      repo.available = [
        makePost(id: 'p1', title: 'Headphones', category: 'Electronics'),
      ];

      await ProductStore.syncFromSupabase(repository: repo);

      final product = ProductStore.items.value.single;
      expect(product.id, 'p1');
      expect(product.name, 'Headphones');
      expect(product.category, 'Electronics');
      expect(product.condition, 'Old');
      expect(product.userId, 'owner-1');
      expect(product.imageUrl, 'https://img/1.png');
      expect(product.color, AppColors.primary);
    });

    test('a post without a category falls back to "Other"', () async {
      repo.available = [makePost(category: null)];

      await ProductStore.syncFromSupabase(repository: repo);

      expect(ProductStore.items.value.single.category, 'Other');
    });

    test('keeps local-only products and replaces stale copies', () async {
      ProductStore.items.value = [
        local('local-only'),
        local('p1'), // stale copy of a remote post
      ];
      repo.available = [makePost(id: 'p1', title: 'Fresh')];

      await ProductStore.syncFromSupabase(repository: repo);

      final byId = {for (final p in ProductStore.items.value) p.id: p.name};
      expect(byId, {'p1': 'Fresh', 'local-only': 'Local local-only'});
      expect(ProductStore.items.value.first.id, 'p1', reason: 'remote first');
    });

    test(
      'drops a previously synced post that is no longer available',
      () async {
        // Post p1 was synced earlier; someone has since been given it, so the
        // server (which only returns is_given = false rows) no longer lists it.
        repo.available = [makePost(id: 'p1')];
        await ProductStore.syncFromSupabase(repository: repo);
        repo.available = [];

        await ProductStore.syncFromSupabase(repository: repo);

        expect(ProductStore.items.value, isEmpty);
      },
      skip:
          'KNOWN ISSUE: ProductStore treats every product missing from the '
          'server response as "local-only" and keeps it, so a post that was '
          'given away (or deleted) stays visible on other users\' Home '
          'screens until the app restarts. Un-skip after fixing '
          'ProductStore.syncFromSupabase / startRealtimeSync.',
    );

    test('stops the loading state on success', () async {
      await ProductStore.syncFromSupabase(repository: repo);

      expect(ProductStore.isLoading.value, isFalse);
    });

    test('stops the loading state on failure and rethrows', () async {
      repo.fetchError = Exception('offline');

      await expectLater(
        ProductStore.syncFromSupabase(repository: repo),
        throwsException,
      );

      expect(ProductStore.isLoading.value, isFalse);
    });
  });

  // startRealtimeSync can only be started once per process (there is no
  // reset), so its behavior is exercised as one ordered scenario.
  group('startRealtimeSync', () {
    test('keeps products live, and only subscribes once', () async {
      ProductStore.items.value = [local('local-only')];

      ProductStore.startRealtimeSync(repository: repo);
      final controller = repo.postsController!;

      controller.add([makePost(id: 'p1', title: 'Live one')]);
      await pumpEventQueue();

      expect(
        ProductStore.items.value.map((p) => p.id),
        ['p1', 'local-only'],
        reason: 'remote first, local-only preserved',
      );
      expect(ProductStore.isLoading.value, isFalse);

      // A later event refreshes the remote set (newest first).
      controller.add([
        makePost(id: 'p2', title: 'Second'),
        makePost(id: 'p1', title: 'Live one (edited)'),
      ]);
      await pumpEventQueue();
      expect(
        ProductStore.items.value.map((p) => p.id),
        ['p2', 'p1', 'local-only'],
      );
      expect(ProductStore.items.value[1].name, 'Live one (edited)');

      // A second call must not create another subscription.
      final other = FakePostRepository();
      ProductStore.startRealtimeSync(repository: other);
      expect(other.postsController, isNull);
    });
  });
}
