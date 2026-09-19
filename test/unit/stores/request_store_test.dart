import 'package:flutter_test/flutter_test.dart';
import 'package:pao/features/auth/data/model/user_model.dart';
import 'package:pao/features/home/data/product_store.dart';
import 'package:pao/features/home/domain/product.dart';
import 'package:pao/features/requests/data/model/request_model.dart';
import 'package:pao/features/requests/data/request_store.dart';
import 'package:flutter/material.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeRequestRepository repo;
  late FakePostRepository posts;
  late FakeAuthRepository auth;

  setUp(() {
    repo = FakeRequestRepository();
    posts = FakePostRepository();
    auth = FakeAuthRepository(user: const UserModel(id: 'me'));
    RequestStore.reset();
    ProductStore.items.value = [];
  });

  tearDown(RequestStore.reset);

  group('realtime sync', () {
    test('does nothing when signed out', () async {
      auth.user = null;

      RequestStore.startRealtimeSync(repository: repo, authRepository: auth);
      repo.sentController?.add([makeRequest()]);
      await pumpEventQueue();

      expect(repo.sentController, isNull, reason: 'never subscribed');
      expect(RequestStore.sent.value, isEmpty);
    });

    test('streams update sent and received', () async {
      RequestStore.startRealtimeSync(repository: repo, authRepository: auth);

      repo.sentController!.add([makeRequest(id: 's1')]);
      repo.receivedController!.add([makeRequest(id: 'r1'), makeRequest(id: 'r2')]);
      await pumpEventQueue();

      expect(RequestStore.sent.value.map((r) => r.id), ['s1']);
      expect(RequestStore.received.value.map((r) => r.id), ['r1', 'r2']);
    });

    test('a second call does not subscribe again', () async {
      RequestStore.startRealtimeSync(repository: repo, authRepository: auth);
      final firstSent = repo.sentController;

      final other = FakeRequestRepository();
      RequestStore.startRealtimeSync(repository: other, authRepository: auth);

      expect(other.sentController, isNull);
      expect(repo.sentController, same(firstSent));
    });

    test('reset cancels the subscriptions and clears the cache', () async {
      RequestStore.startRealtimeSync(repository: repo, authRepository: auth);
      repo.sentController!.add([makeRequest()]);
      await pumpEventQueue();
      expect(RequestStore.sent.value, hasLength(1));

      RequestStore.reset();
      repo.sentController!.add([makeRequest(id: 'after-reset')]);
      await pumpEventQueue();

      expect(RequestStore.sent.value, isEmpty);
      expect(RequestStore.received.value, isEmpty);
    });

    test('after reset a new sign-in can subscribe again', () async {
      RequestStore.startRealtimeSync(repository: repo, authRepository: auth);
      RequestStore.reset();

      final next = FakeRequestRepository();
      RequestStore.startRealtimeSync(repository: next, authRepository: auth);

      expect(next.sentController, isNotNull);
    });
  });

  group('one-shot sync', () {
    test('sent: empty when signed out, loaded otherwise', () async {
      repo.sent = [makeRequest(id: 's1')];

      auth.user = null;
      await RequestStore.syncSentFromSupabase(repository: repo, authRepository: auth);
      expect(RequestStore.sent.value, isEmpty);

      auth.user = const UserModel(id: 'me');
      await RequestStore.syncSentFromSupabase(repository: repo, authRepository: auth);
      expect(RequestStore.sent.value.map((r) => r.id), ['s1']);
    });

    test('received: empty when signed out, loaded otherwise', () async {
      repo.received = [makeRequest(id: 'r1')];

      auth.user = null;
      await RequestStore.syncReceivedFromSupabase(repository: repo, authRepository: auth);
      expect(RequestStore.received.value, isEmpty);

      auth.user = const UserModel(id: 'me');
      await RequestStore.syncReceivedFromSupabase(repository: repo, authRepository: auth);
      expect(RequestStore.received.value.map((r) => r.id), ['r1']);
    });
  });

  group('send', () {
    test('returns null when signed out', () async {
      auth.user = null;

      final result = await RequestStore.send(
        postId: 'p1',
        ownerId: 'owner',
        repository: repo,
        authRepository: auth,
      );

      expect(result, isNull);
      expect(repo.createCalls, isEmpty);
    });

    test("cannot request one's own item", () async {
      final result = await RequestStore.send(
        postId: 'p1',
        ownerId: 'me',
        repository: repo,
        authRepository: auth,
      );

      expect(result, isNull);
      expect(repo.createCalls, isEmpty);
    });

    test('creates a request and prepends it to sent', () async {
      RequestStore.sent.value = [makeRequest(id: 'older', postId: 'other')];

      final result = await RequestStore.send(
        postId: 'p1',
        ownerId: 'owner',
        repository: repo,
        authRepository: auth,
      );

      expect(result!.id, 'new-req');
      expect(repo.createCalls.single.requesterId, 'me');
      expect(repo.createCalls.single.ownerId, 'owner');
      expect(RequestStore.sent.value.map((r) => r.id), ['new-req', 'older']);
    });

    test('returns the existing request instead of creating a duplicate', () async {
      final existing = makeRequest(id: 'already', postId: 'p1');
      RequestStore.sent.value = [existing];

      final result = await RequestStore.send(
        postId: 'p1',
        ownerId: 'owner',
        repository: repo,
        authRepository: auth,
      );

      expect(result, same(existing));
      expect(repo.createCalls, isEmpty);
    });

    test('propagates a repository failure and leaves sent unchanged', () async {
      repo.createError = Exception('boom');

      await expectLater(
        RequestStore.send(
          postId: 'p1',
          ownerId: 'owner',
          repository: repo,
          authRepository: auth,
        ),
        throwsException,
      );
      expect(RequestStore.sent.value, isEmpty);
    });
  });

  group('accept', () {
    RequestModel req(String id, String postId, String status) =>
        makeRequest(id: id, postId: postId, status: status);

    setUp(() {
      ProductStore.items.value = [
        const Product(id: 'p1', name: 'Lamp', category: 'Home', color: Colors.green),
        const Product(id: 'p2', name: 'Bike', category: 'Sports', color: Colors.green),
      ];
      final all = [
        req('a', 'p1', 'pending'), // the one being accepted
        req('b', 'p1', 'pending'), // competing request on the same post
        req('c', 'p1', 'closed'), // already closed: must stay closed
        req('d', 'p2', 'pending'), // different post: untouched
      ];
      RequestStore.received.value = all;
      RequestStore.sent.value = all;
    });

    test('accepts, closes competing pending requests, leaves others alone', () async {
      await RequestStore.accept(
        req('a', 'p1', 'pending'),
        repository: repo,
        postRepository: posts,
      );

      for (final list in [RequestStore.received.value, RequestStore.sent.value]) {
        final byId = {for (final r in list) r.id: r.status};
        expect(byId['a'], 'accepted');
        expect(byId['b'], 'closed');
        expect(byId['c'], 'closed');
        expect(byId['d'], 'pending');
      }
    });

    test('persists the acceptance and marks the post as given', () async {
      await RequestStore.accept(
        req('a', 'p1', 'pending'),
        repository: repo,
        postRepository: posts,
      );

      expect(repo.acceptCalls.single.requestId, 'a');
      expect(repo.acceptCalls.single.postId, 'p1');
      expect(posts.markedGiven, ['p1']);
      final byId = {for (final p in ProductStore.items.value) p.id: p.isGiven};
      expect(byId, {'p1': true, 'p2': false});
    });

    test('leaves local state untouched when the request fails', () async {
      repo.acceptError = Exception('boom');

      await expectLater(
        RequestStore.accept(
          req('a', 'p1', 'pending'),
          repository: repo,
          postRepository: posts,
        ),
        throwsException,
      );

      expect(RequestStore.received.value.first.status, 'pending');
      expect(posts.markedGiven, isEmpty);
      expect(ProductStore.items.value.every((p) => !p.isGiven), isTrue);
    });
  });
}
