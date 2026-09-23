import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pao/core/realtime/realtime_event.dart';
import 'package:pao/features/add_item/data/model/post_model.dart';
import 'package:pao/features/add_item/data/repository/post_repository.dart';
import 'package:pao/features/auth/data/repository/auth_repository.dart';
import 'package:pao/features/chat/data/model/message_model.dart';
import 'package:pao/features/chat/data/repository/chat_repository.dart';
import 'package:pao/features/feedback/data/repository/feedback_repository.dart';
import 'package:pao/features/requests/data/datasource/request_remote_datasource.dart';
import 'package:pao/features/requests/data/model/request_model.dart';
import 'package:pao/features/requests/data/repository/request_repository.dart';
import 'package:pao/features/settings/data/repository/profile_repository.dart';
import 'package:pao/features/wishlist/data/repository/wishlist_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/fakes.dart';

void main() {
  group('AuthRepository', () {
    late FakeAuthDataSource source;
    late AuthRepository repo;

    setUp(() {
      source = FakeAuthDataSource();
      repo = AuthRepository(dataSource: source);
    });

    test('currentUser / isLoggedIn reflect the session', () {
      expect(repo.currentUser, isNull);
      expect(repo.isLoggedIn, isFalse);

      source.user = makeSupabaseUser(
        id: 'u1',
        email: 'a@b.com',
        metadata: {'full_name': 'Ali'},
      );

      expect(repo.isLoggedIn, isTrue);
      expect(repo.currentUser!.id, 'u1');
      expect(repo.currentUser!.fullName, 'Ali');
    });

    test('login returns the signed-in user', () async {
      source.signInResponse = AuthResponse(
        user: makeSupabaseUser(id: 'u1', email: 'a@b.com'),
      );

      final user = await repo.login(email: 'a@b.com', password: 'secret1');

      expect(user!.id, 'u1');
      expect(source.calls, ['signIn:a@b.com']);
    });

    test('login returns null when no user comes back', () async {
      expect(await repo.login(email: 'a@b.com', password: 'x'), isNull);
    });

    test('login rejects and signs out a banned account', () async {
      source.signInResponse = AuthResponse(
        user: makeSupabaseUser(id: 'u1', email: 'a@b.com'),
      );
      source.isBannedResult = true;

      await expectLater(
        () => repo.login(email: 'a@b.com', password: 'secret1'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            'account_banned',
          ),
        ),
      );
      expect(source.calls, ['signIn:a@b.com', 'signOut']);
    });

    test('register returns the user when a session is issued', () async {
      final user = makeSupabaseUser(id: 'new', email: 'n@b.com');
      source.signUpResponse = AuthResponse(
        user: user,
        session: Session(accessToken: 't', tokenType: 'bearer', user: user),
      );

      final created = await repo.register(
        fullName: 'New',
        email: 'n@b.com',
        password: 'secret1',
      );

      expect(created!.id, 'new');
      expect(source.calls, ['signUp:New:n@b.com']);
    });

    test('register returns null when email confirmation is required', () async {
      source.signUpResponse = AuthResponse(
        user: makeSupabaseUser(id: 'new'),
        // no session: Supabase waits for the confirmation link
      );

      final created = await repo.register(
        fullName: 'New',
        email: 'n@b.com',
        password: 'secret1',
      );

      expect(created, isNull);
    });

    test('logout, deleteAccount and password reset delegate', () async {
      await repo.logout();
      await repo.deleteAccount();
      await repo.sendPasswordResetEmail('a@b.com');
      await repo.updatePassword('newsecret');

      expect(source.calls, [
        'signOut',
        'deleteAccount',
        'resetPassword:a@b.com',
        'updatePassword:newsecret',
      ]);
    });
  });

  group('PostRepository', () {
    late FakePostDataSource source;
    late PostRepository repo;

    setUp(() {
      source = FakePostDataSource();
      repo = PostRepository(dataSource: source);
    });

    test(
      'createPost uploads every image first, in order, then stores the URLs',
      () async {
        final a = Uint8List.fromList([1]);
        final b = Uint8List.fromList([2]);

        final post = await repo.createPost(
          userId: 'u1',
          title: 'Lamp',
          description: 'Desk lamp',
          category: 'Home & Living',
          condition: 'Old',
          address: 'House 5, Street 2',
          images: [a, b],
        );

        expect(source.uploaded, [a, b]);
        expect(source.createdWith.single['imageUrls'], [
          'https://cdn/u1/1.png',
          'https://cdn/u1/2.png',
        ]);
        expect(source.createdWith.single['address'], 'House 5, Street 2');
        expect(post.title, 'Lamp');
        expect(post.imageUrls, hasLength(2));
      },
    );

    test('createPost with no images uploads nothing', () async {
      await repo.createPost(
        userId: 'u1',
        title: 'Lamp',
        description: 'd',
        category: 'c',
        condition: 'New',
        address: 'House 5, Street 2',
        images: const [],
      );

      expect(source.uploaded, isEmpty);
      expect(source.createdWith.single['imageUrls'], isEmpty);
    });

    test('updatePost keeps old photos, uploads new ones after them', () async {
      final fresh = Uint8List.fromList([9]);

      final post = await repo.updatePost(
        postId: 'p1',
        userId: 'u1',
        title: 'Lamp v2',
        description: 'd',
        category: 'Books',
        condition: 'Used',
        address: 'New address',
        keptImageUrls: const ['https://cdn/old.png'],
        newImages: [fresh],
      );

      expect(source.uploaded, [fresh]);
      final saved = source.updatedWith.single;
      expect(saved['postId'], 'p1');
      expect(saved['address'], 'New address');
      expect(saved['imageUrls'], ['https://cdn/old.png', 'https://cdn/u1/1.png']);
      expect(post.title, 'Lamp v2');
    });

    test('updatePost removes dropped photos only after the row is saved', () async {
      await repo.updatePost(
        postId: 'p1',
        userId: 'u1',
        title: 't',
        description: 'd',
        category: 'c',
        condition: 'New',
        address: 'a',
        keptImageUrls: const [],
        newImages: const [],
        removedImageUrls: const ['https://cdn/gone.png'],
      );

      expect(source.removedImages.single, ['https://cdn/gone.png']);
    });

    test('updatePost without dropped photos never touches storage', () async {
      await repo.updatePost(
        postId: 'p1',
        userId: 'u1',
        title: 't',
        description: 'd',
        category: 'c',
        condition: 'New',
        address: 'a',
        keptImageUrls: const [],
        newImages: const [],
      );

      expect(source.calls, isNot(contains('deleteImages')));
    });

    test('updatePost still succeeds if cleaning up old photos fails', () async {
      source.deleteImagesError = Exception('storage down');

      final post = await repo.updatePost(
        postId: 'p1',
        userId: 'u1',
        title: 't',
        description: 'd',
        category: 'c',
        condition: 'New',
        address: 'a',
        keptImageUrls: const [],
        newImages: const [],
        removedImageUrls: const ['https://cdn/gone.png'],
      );

      expect(post.title, 't');
    });

    test('deletePost deletes the row first, then its photos', () async {
      await repo.deletePost('p1', imageUrls: const ['https://cdn/a.png']);

      expect(source.calls, ['deletePost:p1', 'deleteImages']);
      expect(source.removedImages.single, ['https://cdn/a.png']);
    });

    test('deletePost leaves the photos alone if the row was not deleted', () async {
      final failing = _FailingDeleteSource();
      final failingRepo = PostRepository(dataSource: failing);

      await expectLater(
        failingRepo.deletePost('p1', imageUrls: const ['https://cdn/a.png']),
        throwsException,
      );
      expect(failing.removedImages, isEmpty);
    });

    test('deletePost still succeeds if removing photos fails', () async {
      source.deleteImagesError = Exception('storage down');

      await repo.deletePost('p1', imageUrls: const ['https://cdn/a.png']);

      expect(source.deletedPosts, ['p1']);
    });

    test('fetchAvailablePosts maps rows to models', () async {
      source.rows = [postJson(id: 'a'), postJson(id: 'b')];

      final posts = await repo.fetchAvailablePosts();

      expect(posts.map((p) => p.id), ['a', 'b']);
    });

    test('fetchAvailablePostsPage passes the query through', () async {
      source.rows = [postJson(id: 'a'), postJson(id: 'b')];

      final posts = await repo.fetchAvailablePostsPage(
        offset: 8,
        limit: 8,
        excludeUserId: 'me',
        category: 'Books',
        condition: 'Old',
        search: 'novel',
      );

      expect(posts.map((p) => p.id), ['a', 'b']);
      expect(source.calls, ['page:8:8:me:Books:Old:novel']);
    });

    test('watchPosts maps row events to models and passes the rest on', () async {
      final events = <RealtimeEvent<PostModel>>[];
      final sub = repo.watchPosts().listen(events.add);
      addTearDown(sub.cancel);

      source.postEvents
        ..add(
          RealtimeEvent(
            type: RealtimeEventType.insert,
            id: 'a',
            record: postJson(id: 'a', title: 'Live'),
          ),
        )
        ..add(const RealtimeEvent(type: RealtimeEventType.delete, id: 'b'))
        ..add(const RealtimeEvent(type: RealtimeEventType.subscribed));
      await pumpEventQueue();

      expect(events.map((e) => e.type), [
        RealtimeEventType.insert,
        RealtimeEventType.delete,
        RealtimeEventType.subscribed,
      ]);
      expect(events.first.record!.title, 'Live');
      expect(events[1].record, isNull);
    });

    test('watchPosts completes an incomplete UPDATE by fetching the row', () async {
      source.row = postJson(id: 'a', title: 'Complete');
      final events = <RealtimeEvent<PostModel>>[];
      final sub = repo.watchPosts().listen(events.add);
      addTearDown(sub.cancel);

      // Realtime leaves out unchanged large columns such as `description`.
      source.postEvents.add(
        const RealtimeEvent(
          type: RealtimeEventType.update,
          id: 'a',
          record: {'id': 'a', 'is_given': true},
        ),
      );
      await pumpEventQueue();

      expect(events.single.type, RealtimeEventType.update);
      expect(events.single.record!.title, 'Complete');
    });

    test('watchPosts drops an incomplete event whose row is gone', () async {
      source.row = null;
      final events = <RealtimeEvent<PostModel>>[];
      final sub = repo.watchPosts().listen(events.add);
      addTearDown(sub.cancel);

      source.postEvents.add(
        const RealtimeEvent(
          type: RealtimeEventType.update,
          id: 'a',
          record: {'id': 'a'},
        ),
      );
      await pumpEventQueue();

      expect(events, isEmpty);
    });

    test('fetchPostById returns null or a model', () async {
      expect(await repo.fetchPostById('x'), isNull);

      source.row = postJson(id: 'x', title: 'Found');
      expect((await repo.fetchPostById('x'))!.title, 'Found');
    });

    test('markAsGiven and fetchDonatedCount delegate', () async {
      source.donated = 7;

      await repo.markAsGiven('p1');

      expect(source.calls, ['markAsGiven:p1']);
      expect(await repo.fetchDonatedCount('u1'), 7);
    });
  });

  group('RequestRepository', () {
    late FakeRequestDataSource source;
    late RequestRepository repo;

    setUp(() {
      source = FakeRequestDataSource();
      repo = RequestRepository(dataSource: source);
    });

    test('createRequest returns the created model', () async {
      final request = await repo.createRequest(
        postId: 'p1',
        requesterId: 'me',
        ownerId: 'owner',
      );

      expect(request.postId, 'p1');
      expect(request.requesterId, 'me');
      expect(request.ownerId, 'owner');
      expect(request.isPending, isTrue);
    });

    test('fetch methods map rows to models', () async {
      source.rows = [requestJson(id: 'a'), requestJson(id: 'b')];

      expect((await repo.fetchSentRequests('me')).map((r) => r.id), ['a', 'b']);
      expect((await repo.fetchReceivedRequests('me')).map((r) => r.id), [
        'a',
        'b',
      ]);
    });

    test('watchRequests maps rows to models and keeps the tag', () async {
      final events = <RealtimeEvent<RequestModel>>[];
      final sub = repo.watchRequests('me').listen(events.add);
      addTearDown(sub.cancel);

      source.events.add(
        RealtimeEvent(
          type: RealtimeEventType.update,
          id: 'a',
          record: requestJson(id: 'a', status: 'accepted'),
          tag: RequestRemoteDataSource.sentTag,
        ),
      );
      await pumpEventQueue();

      expect(events.single.record!.isAccepted, isTrue);
      expect(events.single.tag, 'sent');
    });

    test(
      'acceptRequest accepts first, then closes the competing requests',
      () async {
        await repo.acceptRequest(requestId: 'r1', postId: 'p1');

        expect(source.calls, ['accept:r1', 'closeOthers:p1:r1']);
      },
    );

    test('cancelRequest delegates', () async {
      await repo.cancelRequest('r1');

      expect(source.calls, ['cancel:r1']);
    });
  });

  group('WishlistRepository', () {
    late FakeWishlistDataSource source;
    late WishlistRepository repo;

    setUp(() {
      source = FakeWishlistDataSource();
      repo = WishlistRepository(dataSource: source);
    });

    test('fetchWishlist maps rows', () async {
      source.rows = [
        {
          'id': 'w1',
          'user_id': 'u',
          'post_id': 'p1',
          'title': 'Bike',
          'note': null,
        },
      ];

      final items = await repo.fetchWishlist('u');

      expect(items.single.postId, 'p1');
      expect(items.single.title, 'Bike');
    });

    test('add and remove delegate with their arguments', () async {
      await repo.addToWishlist(
        userId: 'u',
        postId: 'p1',
        title: 'Bike',
        note: 'n',
      );
      await repo.removeFromWishlist(userId: 'u', postId: 'p1');

      expect(source.calls, ['add:u:p1:Bike:n', 'remove:u:p1']);
    });
  });

  group('FeedbackRepository', () {
    late FakeFeedbackDataSource source;
    late FeedbackRepository repo;

    Map<String, dynamic> row(String id) => {
      'id': id,
      'request_id': 'r1',
      'post_id': 'p1',
      'from_user_id': 'a',
      'to_user_id': 'b',
      'rating': 4,
      'comment': null,
      'created_at': kCreatedAt.toIso8601String(),
    };

    setUp(() {
      source = FakeFeedbackDataSource();
      repo = FeedbackRepository(dataSource: source);
    });

    test('fetchForRequest returns null when there is no feedback', () async {
      expect(await repo.fetchForRequest('r1'), isNull);
    });

    test('fetchForRequest and fetchForUser map rows', () async {
      source.row = row('f1');
      source.rows = [row('f1'), row('f2')];

      expect((await repo.fetchForRequest('r1'))!.rating, 4);
      expect((await repo.fetchForUser('b')).map((f) => f.id), ['f1', 'f2']);
    });

    test('submit delegates', () async {
      await repo.submit(
        requestId: 'r1',
        postId: 'p1',
        fromUserId: 'a',
        toUserId: 'b',
        rating: 5,
        comment: 'Great',
      );

      expect(source.calls, ['submit:r1:5:Great']);
    });
  });

  group('ChatRepository', () {
    test('fetchMessages maps rows, sendMessage returns the saved row', () async {
      final source = FakeChatDataSource()
        ..rows = [
          {
            'id': 'm1',
            'request_id': 'r1',
            'sender_id': 's',
            'recipient_id': 'b',
            'body': 'hi',
            'created_at': kCreatedAt.toIso8601String(),
          },
        ];
      final repo = ChatRepository(dataSource: source);

      final messages = await repo.fetchMessages(
        currentUserId: 'b',
        otherUserId: 's',
      );
      final sent = await repo.sendMessage(
        requestId: 'r1',
        senderId: 's',
        recipientId: 'b',
        body: 'yo',
      );

      expect(messages.single.body, 'hi');
      expect(sent.body, 'yo');
      expect(sent.id, 'sent-1');
      expect(source.calls, ['send:r1:s:b:yo']);
    });

    test('watchMessages maps insert and delete events', () async {
      final source = FakeChatDataSource();
      final repo = ChatRepository(dataSource: source);
      final events = <RealtimeEvent<MessageModel>>[];
      final sub = repo.watchMessages('b').listen(events.add);
      addTearDown(sub.cancel);

      source.events
        ..add(
          RealtimeEvent(
            type: RealtimeEventType.insert,
            id: 'm1',
            record: {
              'id': 'm1',
              'request_id': 'r1',
              'sender_id': 's',
              'recipient_id': 'b',
              'body': 'hi',
              'created_at': kCreatedAt.toIso8601String(),
            },
          ),
        )
        ..add(const RealtimeEvent(type: RealtimeEventType.delete, id: 'm1'));
      await pumpEventQueue();

      expect(events.map((e) => e.type), [
        RealtimeEventType.insert,
        RealtimeEventType.delete,
      ]);
      expect(events.first.record!.body, 'hi');
      expect(events.last.record, isNull);
    });
  });

  group('ProfileRepository', () {
    late FakeProfileDataSource source;
    late ProfileRepository repo;

    setUp(() {
      source = FakeProfileDataSource();
      repo = ProfileRepository(dataSource: source);
    });

    test('fetchProfile / fetchPublicProfile return null or a model', () async {
      expect(await repo.fetchProfile('u1'), isNull);
      expect(await repo.fetchPublicProfile('u1'), isNull);

      source.row = {'id': 'u1', 'full_name': 'Ali'};
      expect((await repo.fetchProfile('u1'))!.fullName, 'Ali');
      expect((await repo.fetchPublicProfile('u1'))!.fullName, 'Ali');
    });

    test('fetchPublicProfiles indexes profiles by id', () async {
      source.rows = [
        {'id': 'a', 'full_name': 'Ali'},
        {'id': 'b', 'full_name': 'Bina'},
      ];

      final profiles = await repo.fetchPublicProfiles(['a', 'b']);

      expect(profiles.keys, containsAll(['a', 'b']));
      expect(profiles['b']!.fullName, 'Bina');
    });

    test(
      'uploadAndSetAvatar uploads, then saves the URL on the profile',
      () async {
        final url = await repo.uploadAndSetAvatar(
          userId: 'u1',
          bytes: Uint8List.fromList([1, 2]),
        );

        expect(url, 'https://cdn/avatar.png');
        expect(source.calls, [
          'upload:u1',
          'updateAvatar:u1:https://cdn/avatar.png',
        ]);
      },
    );

    test('saveProfile sends the new email only when it changed', () async {
      await repo.saveProfile(
        userId: 'u1',
        fullName: 'Ali',
        email: 'new@b.com',
        currentEmail: 'old@b.com',
        phone: '0300',
        bio: 'hi',
      );
      await repo.saveProfile(
        userId: 'u1',
        fullName: 'Ali',
        email: 'same@b.com',
        currentEmail: 'same@b.com',
      );

      expect(source.calls, [
        'auth:Ali:new@b.com',
        'row:u1:Ali:new@b.com:0300:hi',
        'auth:Ali:null',
        'row:u1:Ali:same@b.com:null:null',
      ]);
    });
  });
}

/// A data source whose `deletePost` fails, like RLS refusing a non-owner.
class _FailingDeleteSource extends FakePostDataSource {
  @override
  Future<void> deletePost(String postId) async => throw Exception('not allowed');
}
