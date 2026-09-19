import 'package:flutter_test/flutter_test.dart';
import 'package:pao/features/auth/data/model/user_model.dart';
import 'package:pao/features/feedback/data/model/feedback_model.dart';
import 'package:pao/features/requests/data/model/request_model.dart';
import 'package:pao/features/requests/presentation/provider/request_tile_provider.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeProfileRepository profiles;
  late FakeFeedbackRepository feedback;
  late FakePostRepository posts;
  late FakeAuthRepository auth;

  RequestTileProvider build({
    RequestModel? request,
    bool isSentTab = true,
    String? productName,
    String? productImageUrl,
  }) => RequestTileProvider(
    request: request ?? makeRequest(),
    otherUserId: 'owner-1',
    isSentTab: isSentTab,
    productName: productName,
    productImageUrl: productImageUrl,
    profileRepository: profiles,
    feedbackRepository: feedback,
    postRepository: posts,
    authRepository: auth,
  );

  setUp(() {
    profiles = FakeProfileRepository()..publicProfile = kOtherProfile;
    feedback = FakeFeedbackRepository();
    posts = FakePostRepository();
    auth = FakeAuthRepository(user: const UserModel(id: 'requester-1'));
  });

  group('other user profile', () {
    test('loads the profile', () async {
      final provider = build(productName: 'Lamp');
      expect(provider.isLoadingProfile, isTrue);

      await pumpEventQueue();

      expect(provider.isLoadingProfile, isFalse);
      expect(provider.profile!.fullName, 'Ayesha Khan');
    });

    test('keeps the fallback when the lookup fails', () async {
      profiles.fetchError = Exception('offline');

      final provider = build(productName: 'Lamp');
      await pumpEventQueue();

      expect(provider.isLoadingProfile, isFalse);
      expect(provider.profile, isNull);
    });
  });

  group('product details', () {
    test('uses the name it was given, without a lookup', () async {
      posts.byId = {'post-1': makePost(title: 'Should not be used')};

      final provider = build(productName: 'Lamp', productImageUrl: 'img');
      await pumpEventQueue();

      expect(provider.productName, 'Lamp');
      expect(provider.productImageUrl, 'img');
      expect(provider.isLoadingProduct, isFalse);
    });

    test('looks the post up when no name is given', () async {
      posts.byId = {
        'post-1': makePost(title: 'Bicycle', imageUrls: ['https://img/b.png']),
      };

      final provider = build();
      await pumpEventQueue();

      expect(provider.productName, 'Bicycle');
      expect(provider.productImageUrl, 'https://img/b.png');
      expect(provider.isLoadingProduct, isFalse);
    });

    test('a post with no photos has no image', () async {
      posts.byId = {'post-1': makePost(imageUrls: const [])};

      final provider = build();
      await pumpEventQueue();

      expect(provider.productImageUrl, isNull);
    });

    test('falls back to "PAO item" when the post is gone', () async {
      final provider = build();
      await pumpEventQueue();

      expect(provider.productName, 'PAO item');
    });

    test('falls back to "PAO item" when the lookup fails', () async {
      posts.fetchError = Exception('offline');

      final provider = build();
      await pumpEventQueue();

      expect(provider.productName, 'PAO item');
      expect(provider.isLoadingProduct, isFalse);
    });
  });

  group('feedback', () {
    FeedbackModel given() => FeedbackModel(
      id: 'f1',
      requestId: 'req-1',
      postId: 'post-1',
      fromUserId: 'requester-1',
      toUserId: 'owner-1',
      rating: 5,
      createdAt: kCreatedAt,
    );

    test('checked on the sent tab for an accepted request', () async {
      feedback.existing = given();

      final provider = build(
        request: makeRequest(status: 'accepted'),
        productName: 'Lamp',
      );
      await pumpEventQueue();

      expect(provider.feedbackGiven, isTrue);
    });

    test('not checked on the received tab', () async {
      feedback.existing = given();

      final provider = build(
        request: makeRequest(status: 'accepted'),
        isSentTab: false,
        productName: 'Lamp',
      );
      await pumpEventQueue();

      expect(provider.feedbackGiven, isFalse);
    });

    test('not checked for a request that was not accepted', () async {
      feedback.existing = given();

      final provider = build(
        request: makeRequest(status: 'pending'),
        productName: 'Lamp',
      );
      await pumpEventQueue();

      expect(provider.feedbackGiven, isFalse);
    });

    test('markFeedbackGiven notifies listeners', () async {
      final provider = build(productName: 'Lamp');
      await pumpEventQueue();
      var notified = 0;
      provider.addListener(() => notified++);

      provider.markFeedbackGiven();

      expect(provider.feedbackGiven, isTrue);
      expect(notified, 1);
    });
  });

  test('currentUserId comes from auth', () async {
    final provider = build(productName: 'Lamp');

    expect(provider.currentUserId, 'requester-1');
  });
}
