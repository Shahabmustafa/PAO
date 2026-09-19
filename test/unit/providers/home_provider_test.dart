import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pao/features/auth/data/model/user_model.dart';
import 'package:pao/features/home/data/product_store.dart';
import 'package:pao/features/home/domain/filter_options.dart';
import 'package:pao/features/home/domain/product.dart';
import 'package:pao/features/home/presentation/provider/home_provider.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';

void main() {
  late FakeAuthRepository auth;
  late HomeProvider provider;

  Product product(
    String id,
    String name, {
    String category = 'Electronics',
    String condition = 'New',
    String userId = 'someone-else',
    bool isGiven = false,
  }) => Product(
    id: id,
    name: name,
    category: category,
    color: Colors.green,
    condition: condition,
    userId: userId,
    isGiven: isGiven,
  );

  late List<Product> catalog;

  setUpAll(() async {
    await initFakeSupabase();
    // The provider's constructor starts the realtime sync; prime it with a
    // fake so no real Supabase stream is opened.
    ProductStore.startRealtimeSync(repository: FakePostRepository());
  });

  setUp(() {
    auth = FakeAuthRepository(user: const UserModel(id: 'me'));
    provider = HomeProvider(authRepository: auth);
    catalog = [
      product('1', 'Wireless Headphones'),
      product('2', 'Novel Collection', category: 'Books', condition: 'Old'),
      product('3', 'Football', category: 'Sports'),
      product('4', 'Given Away Lamp', isGiven: true),
      product('5', 'My Own Listing', userId: 'me'),
      product('6', 'Old Phone', condition: 'Old'),
    ];
  });

  List<String> names() => provider.filterProducts(catalog).map((p) => p.name).toList();

  test('starts with no filters and no active search', () {
    expect(provider.selectedCategory, 'All');
    expect(provider.searchQuery, '');
    expect(provider.filters.activeCount, 0);
    expect(provider.hasActiveSearch, isFalse);
  });

  test('hides given-away products and the user\'s own listings', () {
    final visible = names();

    expect(visible, isNot(contains('Given Away Lamp')));
    expect(visible, isNot(contains('My Own Listing')));
    expect(visible, hasLength(4));
  });

  test('shows own listings when signed out (no current user to exclude)', () {
    auth.user = null;

    expect(names(), contains('My Own Listing'));
    expect(names(), isNot(contains('Given Away Lamp')));
  });

  test('search is case-insensitive, trimmed, and matches part of the name', () {
    provider.onSearchChanged('  HEAD ');

    expect(names(), ['Wireless Headphones']);
  });

  test('search with no match returns an empty list', () {
    provider.onSearchChanged('zzz');

    expect(names(), isEmpty);
  });

  test('category filter', () {
    provider.applyFilters(const FilterOptions(category: 'Books'));

    expect(names(), ['Novel Collection']);
    expect(provider.selectedCategory, 'Books');
  });

  test('condition filter', () {
    provider.applyFilters(const FilterOptions(condition: 'Old'));

    expect(names(), ['Novel Collection', 'Old Phone']);
  });

  test('search, category and condition combine (AND)', () {
    provider.onSearchChanged('phone');
    provider.applyFilters(
      const FilterOptions(condition: 'Old', category: 'Electronics'),
    );

    expect(names(), ['Old Phone']);

    provider.onSearchChanged('headphones'); // New, so excluded by "Old"
    expect(names(), isEmpty);
  });

  test('hasActiveSearch reflects any search, category or filter', () {
    provider.onSearchChanged('x');
    expect(provider.hasActiveSearch, isTrue);
    provider.onSearchChanged('   ');
    expect(provider.hasActiveSearch, isFalse, reason: 'whitespace only');

    provider.applyFilters(const FilterOptions(category: 'Toys'));
    expect(provider.hasActiveSearch, isTrue);
  });

  test('clearSearch resets everything', () {
    provider.onSearchChanged('phone');
    provider.applyFilters(
      const FilterOptions(condition: 'Old', category: 'Electronics'),
    );

    provider.clearSearch();

    expect(provider.searchQuery, '');
    expect(provider.selectedCategory, 'All');
    expect(provider.filters.activeCount, 0);
    expect(provider.hasActiveSearch, isFalse);
    expect(names(), hasLength(4));
  });

  test('changes notify listeners', () {
    var notified = 0;
    provider.addListener(() => notified++);

    provider.onSearchChanged('a');
    provider.applyFilters(const FilterOptions(condition: 'New'));
    provider.clearSearch();

    expect(notified, 3);
  });
}
