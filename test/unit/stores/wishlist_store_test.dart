import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pao/features/auth/data/model/user_model.dart';
import 'package:pao/features/wishlist/data/model/wishlist_item_model.dart';
import 'package:pao/features/wishlist/data/wishlist_store.dart';
import 'package:pao/features/wishlist/domain/wish_item.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeWishlistRepository repo;
  late FakeAuthRepository auth;

  WishItem item(String id, {String title = 'Lamp', String note = 'Home'}) =>
      WishItem(id: id, title: title, note: note);

  setUp(() {
    repo = FakeWishlistRepository();
    auth = FakeAuthRepository(user: const UserModel(id: 'u1'));
    WishlistStore.items.value = [];
  });

  group('syncFromSupabase', () {
    test('clears the list when signed out', () async {
      WishlistStore.items.value = [item('stale')];
      auth.user = null;

      await WishlistStore.syncFromSupabase(
        repository: repo,
        authRepository: auth,
      );

      expect(WishlistStore.items.value, isEmpty);
    });

    test('maps remote rows to wish items (null note becomes empty)', () async {
      repo.remote = [
        const WishlistItemModel(
          id: 'w1',
          userId: 'u1',
          postId: 'p1',
          title: 'Bike',
          note: 'Sports',
        ),
        const WishlistItemModel(
          id: 'w2',
          userId: 'u1',
          postId: 'p2',
          title: 'Lamp',
        ),
      ];

      await WishlistStore.syncFromSupabase(
        repository: repo,
        authRepository: auth,
      );

      final items = WishlistStore.items.value;
      expect(items.map((i) => i.id), ['p1', 'p2'], reason: 'keyed by post id');
      expect(items[0].title, 'Bike');
      expect(items[0].note, 'Sports');
      expect(items[1].note, '');
    });
  });

  group('offline', () {
    test('a change made offline is kept, not rolled back', () async {
      repo.addError = const SocketException('no internet');

      await WishlistStore.add(item('p1'), repository: repo, authRepository: auth);

      expect(WishlistStore.items.value.map((i) => i.id), ['p1']);
    });

    test('a change the server rejects is rolled back', () async {
      repo.addError = Exception('rls');

      await WishlistStore.add(item('p1'), repository: repo, authRepository: auth);

      expect(WishlistStore.items.value, isEmpty);
    });
  });

  group('add', () {
    test('adds optimistically and persists remotely', () async {
      await WishlistStore.add(
        item('p1'),
        repository: repo,
        authRepository: auth,
      );

      expect(WishlistStore.items.value.map((i) => i.id), ['p1']);
      expect(repo.added.single.userId, 'u1');
      expect(repo.added.single.postId, 'p1');
      expect(repo.added.single.title, 'Lamp');
      expect(repo.added.single.note, 'Home');
    });

    test('ignores a duplicate without a second remote call', () async {
      await WishlistStore.add(
        item('p1'),
        repository: repo,
        authRepository: auth,
      );
      await WishlistStore.add(
        item('p1'),
        repository: repo,
        authRepository: auth,
      );

      expect(WishlistStore.items.value, hasLength(1));
      expect(repo.added, hasLength(1));
    });

    test('rolls back when the remote call fails', () async {
      repo.addError = Exception('offline');

      await WishlistStore.add(
        item('p1'),
        repository: repo,
        authRepository: auth,
      );

      expect(WishlistStore.items.value, isEmpty);
    });

    test('keeps the item locally (no remote call) when signed out', () async {
      auth.user = null;

      await WishlistStore.add(
        item('p1'),
        repository: repo,
        authRepository: auth,
      );

      expect(WishlistStore.items.value, hasLength(1));
      expect(repo.added, isEmpty);
    });

    test('notifies listeners immediately (optimistic update)', () async {
      var notified = 0;
      WishlistStore.items.addListener(() => notified++);

      final future = WishlistStore.add(
        item('p1'),
        repository: repo,
        authRepository: auth,
      );
      expect(WishlistStore.items.value, hasLength(1), reason: 'before await');
      await future;

      expect(notified, greaterThanOrEqualTo(1));
    });
  });

  group('remove', () {
    setUp(() {
      WishlistStore.items.value = [item('p1'), item('p2')];
    });

    test('removes optimistically and persists remotely', () async {
      await WishlistStore.remove('p1', repository: repo, authRepository: auth);

      expect(WishlistStore.items.value.map((i) => i.id), ['p2']);
      expect(repo.removed.single.postId, 'p1');
      expect(repo.removed.single.userId, 'u1');
    });

    test('restores the item when the remote call fails', () async {
      repo.removeError = Exception('offline');

      await WishlistStore.remove('p1', repository: repo, authRepository: auth);

      expect(
        WishlistStore.items.value.map((i) => i.id),
        containsAll(['p1', 'p2']),
      );
    });

    test('removing an unknown id makes no remote call', () async {
      await WishlistStore.remove(
        'nope',
        repository: repo,
        authRepository: auth,
      );

      expect(WishlistStore.items.value, hasLength(2));
      expect(repo.removed, isEmpty);
    });

    test('removes locally (no remote call) when signed out', () async {
      auth.user = null;

      await WishlistStore.remove('p1', repository: repo, authRepository: auth);

      expect(WishlistStore.items.value.map((i) => i.id), ['p2']);
      expect(repo.removed, isEmpty);
    });
  });
}
