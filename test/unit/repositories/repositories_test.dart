import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pao/features/add_item/data/repository/post_repository.dart';
import 'package:pao/features/auth/data/repository/auth_repository.dart';
import 'package:pao/features/chat/data/repository/chat_repository.dart';
import 'package:pao/features/feedback/data/repository/feedback_repository.dart';
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

    test('createPost uploads every image first, in order, then stores the URLs', () async {
      final a = Uint8List.fromList([1]);
      final b = Uint8List.fromList([2]);

      final post = await repo.createPost(
        userId: 'u1',
        title: 'Lamp',
        description: 'Desk lamp',
        category: 'Home & Living',
        condition: 'Old',
        images: [a, b],
      );

      expect(source.uploaded, [a, b]);
      expect(source.createdWith.single['imageUrls'], [
        'https://cdn/u1/1.png',
        'https://cdn/u1/2.png',
      ]);
      expect(post.title, 'Lamp');
      expect(post.imageUrls, hasLength(2));
    });

    test('createPost with no images uploads nothing', () async {
      await repo.createPost(
        userId: 'u1',
        title: 'Lamp',
        description: 'd',
        category: 'c',
        condition: 'New',
        images: const [],
      );

      expect(source.uploaded, isEmpty);
      expect(source.createdWith.single['imageUrls'], isEmpty);
    });

    test('fetchAvailablePosts maps rows to models', () async {
      source.rows = [postJson(id: 'a'), postJson(id: 'b')];

      final posts = await repo.fetchAvailablePosts();

      expect(posts.map((p) => p.id), ['a', 'b']);
    });

    test('streamAvailablePosts maps each emission', () async {
      source.rows = [postJson(id: 'a')];

      final emitted = await repo.streamAvailablePosts().first;

      expect(emitted.single.id, 'a');
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

    test('fetch and stream methods map rows to models', () async {
      source.rows = [requestJson(id: 'a'), requestJson(id: 'b')];

      expect((await repo.fetchSentRequests('me')).map((r) => r.id), ['a', 'b']);
      expect((await repo.fetchReceivedRequests('me')).map((r) => r.id), ['a', 'b']);
      expect((await repo.streamSentRequests('me').first).length, 2);
      expect((await repo.streamReceivedRequests('me').first).length, 2);
    });

    test('acceptRequest accepts first, then closes the competing requests', () async {
      await repo.acceptRequest(requestId: 'r1', postId: 'p1');

      expect(source.calls, ['accept:r1', 'closeOthers:p1:r1']);
    });

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
        {'id': 'w1', 'user_id': 'u', 'post_id': 'p1', 'title': 'Bike', 'note': null},
      ];

      final items = await repo.fetchWishlist('u');

      expect(items.single.postId, 'p1');
      expect(items.single.title, 'Bike');
    });

    test('add and remove delegate with their arguments', () async {
      await repo.addToWishlist(userId: 'u', postId: 'p1', title: 'Bike', note: 'n');
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
    test('streamMessages maps rows and sendMessage delegates', () async {
      final source = FakeChatDataSource()
        ..rows = [
          {
            'id': 'm1',
            'request_id': 'r1',
            'sender_id': 's',
            'body': 'hi',
            'created_at': kCreatedAt.toIso8601String(),
          },
        ];
      final repo = ChatRepository(dataSource: source);

      final messages = await repo.streamMessages('r1').first;
      await repo.sendMessage(requestId: 'r1', senderId: 's', body: 'yo');

      expect(messages.single.body, 'hi');
      expect(source.calls, ['send:r1:s:yo']);
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

    test('uploadAndSetAvatar uploads, then saves the URL on the profile', () async {
      final url = await repo.uploadAndSetAvatar(
        userId: 'u1',
        bytes: Uint8List.fromList([1, 2]),
      );

      expect(url, 'https://cdn/avatar.png');
      expect(source.calls, ['upload:u1', 'updateAvatar:u1:https://cdn/avatar.png']);
    });

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
