import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pao/core/realtime/realtime_event.dart';
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

  group('update / remove', () {
    test('update replaces the matching product in place', () {
      ProductStore.items.value = [local('a'), local('b'), local('c')];

      ProductStore.update(
        Product(id: 'b', name: 'Renamed', category: 'Toys', color: Colors.red),
      );

      expect(ProductStore.items.value.map((p) => p.id), ['a', 'b', 'c']);
      expect(ProductStore.items.value[1].name, 'Renamed');
      expect(ProductStore.items.value[0].name, 'Local a');
    });

    test('update adds a product the store does not have yet', () {
      ProductStore.items.value = [local('a')];

      ProductStore.update(local('z'));

      expect(ProductStore.items.value.map((p) => p.id), ['z', 'a']);
    });

    test('remove drops only the matching product', () {
      ProductStore.items.value = [local('a'), local('b')];

      ProductStore.remove('a');

      expect(ProductStore.items.value.map((p) => p.id), ['b']);
    });
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

  group('startRealtimeSync', () {
    tearDown(ProductStore.stopRealtimeSync);

    test(
      'loads the posts when the channel joins, then keeps them live',
      () async {
        repo.available = [makePost(id: 'p1', title: 'First')];
        ProductStore.items.value = [local('local-only')];

        ProductStore.startRealtimeSync(repository: repo);
        repo.postsController!.add(subscribedEvent());
        await pumpEventQueue();

        expect(ProductStore.items.value.map((p) => p.id), ['p1', 'local-only']);
        expect(ProductStore.isLoading.value, isFalse);
      },
    );

    test('a new post is added at the top, and announced once', () async {
      ProductStore.items.value = [local('old')];
      ProductStore.startRealtimeSync(repository: repo);
      final announced = <String>[];
      final sub = ProductStore.changes.listen((e) => announced.add(e.id));
      addTearDown(sub.cancel);

      repo.postsController!.add(insertEvent('new', makePost(id: 'new')));
      await pumpEventQueue();

      expect(ProductStore.items.value.map((p) => p.id), ['new', 'old']);
      expect(announced, ['new']);
    });

    test('the same post delivered twice is listed once', () async {
      ProductStore.startRealtimeSync(repository: repo);

      repo.postsController!.add(insertEvent('p1', makePost(id: 'p1')));
      repo.postsController!.add(insertEvent('p1', makePost(id: 'p1')));
      await pumpEventQueue();

      expect(ProductStore.items.value.map((p) => p.id), ['p1']);
    });

    test('an edit replaces the post in place', () async {
      ProductStore.items.value = [local('a'), local('b')];
      ProductStore.startRealtimeSync(repository: repo);

      repo.postsController!.add(
        updateEvent('b', makePost(id: 'b', title: 'Edited b')),
      );
      await pumpEventQueue();

      expect(ProductStore.items.value.map((p) => p.id), ['a', 'b']);
      expect(ProductStore.items.value[1].name, 'Edited b');
    });

    test('a post given away is kept, marked given', () async {
      ProductStore.items.value = [local('a')];
      ProductStore.startRealtimeSync(repository: repo);

      repo.postsController!.add(
        updateEvent('a', makePost(id: 'a', isGiven: true)),
      );
      await pumpEventQueue();

      expect(ProductStore.items.value.single.isGiven, isTrue);
    });

    test('an unknown post that is already given is not added', () async {
      ProductStore.startRealtimeSync(repository: repo);

      repo.postsController!.add(
        updateEvent('x', makePost(id: 'x', isGiven: true)),
      );
      await pumpEventQueue();

      expect(ProductStore.items.value, isEmpty);
    });

    test('a delete removes the post and is announced', () async {
      ProductStore.items.value = [local('a'), local('b')];
      ProductStore.startRealtimeSync(repository: repo);
      final announced = <RealtimeEventType>[];
      final sub = ProductStore.changes.listen((e) => announced.add(e.type));
      addTearDown(sub.cancel);

      repo.postsController!.add(deleteEvent('a'));
      await pumpEventQueue();

      expect(ProductStore.items.value.map((p) => p.id), ['b']);
      expect(announced, [RealtimeEventType.delete]);
    });

    test('a re-join announces a reconnect and reloads', () async {
      ProductStore.startRealtimeSync(repository: repo);
      repo.postsController!.add(subscribedEvent());
      await pumpEventQueue();
      var reconnects = 0;
      final sub = ProductStore.reconnected.listen((_) => reconnects++);
      addTearDown(sub.cancel);

      repo.available = [makePost(id: 'missed')];
      repo.postsController!.add(subscribedEvent(isReconnect: true));
      await pumpEventQueue();

      expect(reconnects, 1);
      expect(ProductStore.items.value.map((p) => p.id), ['missed']);
    });

    test('if realtime cannot connect the posts still load', () async {
      repo.available = [makePost(id: 'p1')];
      ProductStore.startRealtimeSync(repository: repo);

      repo.postsController!.add(errorEvent());
      await pumpEventQueue();

      expect(ProductStore.items.value.map((p) => p.id), ['p1']);
      expect(ProductStore.isLoading.value, isFalse);
    });

    test('only subscribes once, and stopRealtimeSync unsubscribes', () async {
      ProductStore.startRealtimeSync(repository: repo);
      final controller = repo.postsController!;

      final other = FakePostRepository();
      ProductStore.startRealtimeSync(repository: other);
      expect(other.postsController, isNull);

      ProductStore.stopRealtimeSync();
      expect(controller.hasListener, isFalse);

      // ...and a later start subscribes afresh.
      ProductStore.startRealtimeSync(repository: other);
      expect(other.postsController, isNotNull);
    });
  });
}
