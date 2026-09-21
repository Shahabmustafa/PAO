import 'package:flutter_test/flutter_test.dart';
import 'package:pao/core/realtime/realtime_event.dart';
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
    // The channel tags each event with the list it belongs to.
    RealtimeEvent<RequestModel> sentInsert(RequestModel r) =>
        insertEvent(r.id, r, tag: 'sent');
    RealtimeEvent<RequestModel> receivedInsert(RequestModel r) =>
        insertEvent(r.id, r, tag: 'received');

    test('does nothing when signed out', () async {
      auth.user = null;

      RequestStore.startRealtimeSync(repository: repo, authRepository: auth);

      expect(repo.eventsController, isNull, reason: 'never subscribed');
    });

    test('loads both lists when the channel joins', () async {
      repo.sent = [makeRequest(id: 's1')];
      repo.received = [makeRequest(id: 'r1'), makeRequest(id: 'r2')];
      RequestStore.startRealtimeSync(repository: repo, authRepository: auth);

      repo.eventsController!.add(subscribedEvent());
      await pumpEventQueue();

      expect(RequestStore.sent.value.map((r) => r.id), ['s1']);
      expect(RequestStore.received.value.map((r) => r.id), ['r1', 'r2']);
    });

    test('if realtime cannot connect the lists still load, once', () async {
      repo.sent = [makeRequest(id: 's1')];
      RequestStore.startRealtimeSync(repository: repo, authRepository: auth);

      repo.eventsController!.add(errorEvent());
      await pumpEventQueue();
      expect(RequestStore.sent.value.map((r) => r.id), ['s1']);

      repo.sent = [makeRequest(id: 'changed')];
      repo.eventsController!.add(errorEvent());
      await pumpEventQueue();
      expect(
        RequestStore.sent.value.map((r) => r.id),
        ['s1'],
        reason: 'repeated errors do not keep refetching',
      );
    });

    test('a new "Give Me" request appears in Received right away', () async {
      RequestStore.startRealtimeSync(repository: repo, authRepository: auth);
      final controller = repo.eventsController!;

      controller.add(receivedInsert(makeRequest(id: 'r1', ownerId: 'me')));
      await pumpEventQueue();

      expect(RequestStore.received.value.map((r) => r.id), ['r1']);
      expect(RequestStore.sent.value, isEmpty);
    });

    test('an accept / decline updates the sent request in place', () async {
      RequestStore.sent.value = [
        makeRequest(id: 'a', requesterId: 'me'),
        makeRequest(id: 'b', requesterId: 'me'),
      ];
      RequestStore.startRealtimeSync(repository: repo, authRepository: auth);

      repo.eventsController!.add(
        updateEvent(
          'a',
          makeRequest(id: 'a', requesterId: 'me', status: 'accepted'),
          tag: 'sent',
        ),
      );
      repo.eventsController!.add(
        updateEvent(
          'b',
          makeRequest(id: 'b', requesterId: 'me', status: 'declined'),
          tag: 'sent',
        ),
      );
      await pumpEventQueue();

      expect(RequestStore.sent.value.map((r) => r.id), ['a', 'b']);
      expect(RequestStore.sent.value.map((r) => r.status), [
        'accepted',
        'declined',
      ]);
    });

    test('the same request delivered twice is listed once', () async {
      RequestStore.startRealtimeSync(repository: repo, authRepository: auth);
      final controller = repo.eventsController!;

      controller.add(sentInsert(makeRequest(id: 's1')));
      controller.add(sentInsert(makeRequest(id: 's1')));
      await pumpEventQueue();

      expect(RequestStore.sent.value.map((r) => r.id), ['s1']);
    });

    test('a request we just sent is not doubled by its realtime echo', () async {
      RequestStore.startRealtimeSync(repository: repo, authRepository: auth);

      await RequestStore.send(
        postId: 'p1',
        ownerId: 'owner',
        repository: repo,
        authRepository: auth,
      );
      repo.eventsController!.add(
        sentInsert(makeRequest(id: 'new-req', postId: 'p1', requesterId: 'me')),
      );
      await pumpEventQueue();

      expect(RequestStore.sent.value.map((r) => r.id), ['new-req']);
    });

    test('a delete removes the request from both lists, ignoring unknown ids', () async {
      RequestStore.sent.value = [makeRequest(id: 's1')];
      RequestStore.received.value = [makeRequest(id: 'r1')];
      RequestStore.startRealtimeSync(repository: repo, authRepository: auth);
      final controller = repo.eventsController!;
      var notified = 0;
      RequestStore.sent.addListener(() => notified++);
      RequestStore.received.addListener(() => notified++);

      controller.add(deleteEvent('someone-elses'));
      await pumpEventQueue();
      expect(notified, 0);

      controller.add(deleteEvent('s1'));
      controller.add(deleteEvent('r1'));
      await pumpEventQueue();

      expect(RequestStore.sent.value, isEmpty);
      expect(RequestStore.received.value, isEmpty);
    });

    test('newer requests are ordered first', () async {
      RequestStore.startRealtimeSync(repository: repo, authRepository: auth);
      final older = makeRequest(id: 'old');
      final newer = RequestModel(
        id: 'new',
        postId: 'post-1',
        requesterId: 'requester-1',
        ownerId: 'owner-1',
        status: 'pending',
        createdAt: kCreatedAt.add(const Duration(hours: 1)),
      );

      repo.eventsController!.add(receivedInsert(older));
      repo.eventsController!.add(receivedInsert(newer));
      await pumpEventQueue();

      expect(RequestStore.received.value.map((r) => r.id), ['new', 'old']);
    });

    test('a second call does not subscribe again', () async {
      RequestStore.startRealtimeSync(repository: repo, authRepository: auth);
      final first = repo.eventsController;

      final other = FakeRequestRepository();
      RequestStore.startRealtimeSync(repository: other, authRepository: auth);

      expect(other.eventsController, isNull);
      expect(repo.eventsController, same(first));
    });

    test('reset cancels the subscription and clears the cache', () async {
      RequestStore.startRealtimeSync(repository: repo, authRepository: auth);
      repo.eventsController!.add(sentInsert(makeRequest()));
      await pumpEventQueue();
      expect(RequestStore.sent.value, hasLength(1));

      RequestStore.reset();
      repo.eventsController!.add(sentInsert(makeRequest(id: 'after-reset')));
      await pumpEventQueue();

      expect(repo.eventsController!.hasListener, isFalse);
      expect(RequestStore.sent.value, isEmpty);
      expect(RequestStore.received.value, isEmpty);
    });

    test('after reset a new sign-in can subscribe again', () async {
      RequestStore.startRealtimeSync(repository: repo, authRepository: auth);
      RequestStore.reset();

      final next = FakeRequestRepository();
      RequestStore.startRealtimeSync(repository: next, authRepository: auth);

      expect(next.eventsController, isNotNull);
    });
  });

  group('removeForPost', () {
    test('drops sent and received requests for that post only', () {
      RequestStore.sent.value = [
        makeRequest(id: 's1', postId: 'gone'),
        makeRequest(id: 's2', postId: 'kept'),
      ];
      RequestStore.received.value = [
        makeRequest(id: 'r1', postId: 'gone'),
        makeRequest(id: 'r2', postId: 'kept'),
      ];

      RequestStore.removeForPost('gone');

      expect(RequestStore.sent.value.map((r) => r.id), ['s2']);
      expect(RequestStore.received.value.map((r) => r.id), ['r2']);
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
