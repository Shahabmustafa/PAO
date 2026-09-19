import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pao/features/add_item/presentation/provider/add_item_provider.dart';
import 'package:pao/features/auth/data/model/user_model.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakePostRepository posts;
  late FakeAuthRepository auth;
  late AddItemProvider provider;

  Future<dynamic> submit({List<Uint8List>? images}) => provider.submit(
    title: 'Lamp',
    description: 'Desk lamp',
    category: 'Home & Living',
    condition: 'Old',
    images: images ?? [Uint8List.fromList([1, 2, 3])],
  );

  setUp(() {
    posts = FakePostRepository();
    auth = FakeAuthRepository(user: const UserModel(id: 'u1'));
    provider = AddItemProvider(repository: posts, authRepository: auth);
  });

  test('requires a signed-in user and never calls the repository', () async {
    auth.user = null;

    final post = await submit();

    expect(post, isNull);
    expect(provider.errorMessage, 'You must be logged in to post an item.');
    expect(posts.createCalls, isEmpty);
  });

  test('creates the post for the current user', () async {
    final post = await submit();

    expect(post, isNotNull);
    expect(post.title, 'Lamp');
    expect(provider.errorMessage, isNull);
    final call = posts.createCalls.single;
    expect(call['userId'], 'u1');
    expect(call['category'], 'Home & Living');
    expect(call['condition'], 'Old');
    expect(call['images'], 1);
  });

  test('loading toggles on and off around the request', () async {
    final states = <bool>[];
    provider.addListener(() => states.add(provider.isLoading));

    await submit();

    expect(states, [true, false]);
    expect(provider.isLoading, isFalse);
  });

  test('a failure returns null with a friendly message', () async {
    posts.createError = Exception('storage quota exceeded');

    final post = await submit();

    expect(post, isNull);
    expect(provider.errorMessage, 'Something went wrong. Please try again.');
    expect(provider.errorMessage, isNot(contains('quota')));
    expect(provider.isLoading, isFalse);
  });

  test('a successful retry clears the earlier error', () async {
    posts.createError = Exception('offline');
    await submit();
    expect(provider.errorMessage, isNotNull);

    posts.createError = null;
    await submit();

    expect(provider.errorMessage, isNull);
  });
}
