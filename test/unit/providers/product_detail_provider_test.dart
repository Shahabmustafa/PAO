import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pao/features/auth/data/model/user_model.dart';
import 'package:pao/features/home/data/product_store.dart';
import 'package:pao/features/home/domain/product.dart';
import 'package:pao/features/home/presentation/provider/product_detail_provider.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';

void main() {
  late FakeAuthRepository auth;
  late FakePostRepository posts;
  late FakeProfileRepository profiles;

  Product product({String? userId = 'owner-1'}) => Product(
    id: 'p1',
    name: 'Lamp',
    category: 'Home & Living',
    color: Colors.green,
    userId: userId,
  );

  ProductDetailProvider build({String? userId = 'owner-1'}) =>
      ProductDetailProvider(
        product: product(userId: userId),
        authRepository: auth,
        postRepository: posts,
        profileRepository: profiles,
      );

  setUpAll(initFakeSupabase);

  setUp(() {
    auth = FakeAuthRepository(user: const UserModel(id: 'me'));
    posts = FakePostRepository();
    profiles = FakeProfileRepository()..publicProfile = kOtherProfile;
    ProductStore.items.value = [product()];
  });

  group('poster profile', () {
    test('loads the poster and stops loading', () async {
      final provider = build();
      expect(provider.isLoadingPoster, isTrue);

      await pumpEventQueue();

      expect(provider.isLoadingPoster, isFalse);
      expect(provider.posterProfile!.fullName, 'Ayesha Khan');
    });

    test('keeps going (no profile) when the lookup fails', () async {
      profiles.fetchError = Exception('offline');

      final provider = build();
      await pumpEventQueue();

      expect(provider.isLoadingPoster, isFalse);
      expect(provider.posterProfile, isNull);
    });

    test('a product with no owner skips the lookup', () async {
      final provider = build(userId: null);
      await pumpEventQueue();

      expect(provider.isLoadingPoster, isFalse);
      expect(provider.posterProfile, isNull);
    });
  });

  group('isOwner', () {
    test('true only when the current user posted it', () async {
      auth.user = const UserModel(id: 'owner-1');
      expect(build().isOwner, isTrue);

      auth.user = const UserModel(id: 'me');
      expect(build().isOwner, isFalse);

      auth.user = null;
      expect(build().isOwner, isFalse);

      expect(build(userId: null).isOwner, isFalse);
    });
  });

  group('sendRequest', () {
    test('returns false when the product has no owner', () async {
      final provider = build(userId: null);

      expect(await provider.sendRequest(), isFalse);
      expect(provider.errorMessage, isNull);
    });

    test("owners cannot request their own item", () async {
      auth.user = const UserModel(id: 'owner-1');
      final provider = build();

      final ok = await provider.sendRequest();

      expect(ok, isFalse);
      expect(provider.errorMessage, "You can't request your own item.");
      expect(provider.isRequesting, isFalse);
    });

    test('reports failure when nobody is signed in', () async {
      // RequestStore.send uses the real (signed-out) auth client here.
      final provider = build();

      final ok = await provider.sendRequest();

      expect(ok, isFalse);
      expect(
        provider.errorMessage,
        'Failed to send request. Please try again.',
      );
      expect(provider.isRequesting, isFalse);
    });
  });

  group('markAsGiven', () {
    test('marks the post in the database and the local store', () async {
      auth.user = const UserModel(id: 'owner-1');
      final provider = build();

      final ok = await provider.markAsGiven();

      expect(ok, isTrue);
      expect(posts.markedGiven, ['p1']);
      expect(ProductStore.items.value.single.isGiven, isTrue);
      expect(provider.isMarkingGiven, isFalse);
    });

    test('a failure leaves the store unchanged and shows a message', () async {
      posts.markGivenError = Exception('offline');
      final provider = build();

      final ok = await provider.markAsGiven();

      expect(ok, isFalse);
      expect(provider.errorMessage, 'Failed to update. Please try again.');
      expect(ProductStore.items.value.single.isGiven, isFalse);
      expect(provider.isMarkingGiven, isFalse);
    });
  });
}
