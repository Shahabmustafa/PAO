import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pao/core/theme/app_colors.dart';
import 'package:pao/core/widgets/app_icon.dart';
import 'package:pao/features/add_item/data/model/post_model.dart';
import 'package:pao/features/home/data/product_store.dart';
import 'package:pao/features/home/domain/filter_options.dart';
import 'package:pao/features/home/domain/product.dart';
import 'package:pao/features/home/presentation/screens/home_screen.dart';
import 'package:pao/features/home/presentation/screens/product_detail_screen.dart';
import 'package:pao/features/home/presentation/widgets/filter_bottom_sheet.dart';
import 'package:pao/features/home/presentation/widgets/product_card.dart';
import 'package:pao/features/requests/data/request_store.dart';
import 'package:pao/features/wishlist/data/wishlist_store.dart';
import 'package:pao/features/wishlist/domain/wish_item.dart';
import 'package:pao/features/wishlist/presentation/screens/wishlist_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/test_app.dart';

Product product(
  String id,
  String name, {
  String category = 'Electronics',
  String condition = 'New',
  String description = '',
  String? address,
  String? userId = 'someone-else',
  bool isGiven = false,
}) => Product(
  id: id,
  name: name,
  category: category,
  color: AppColors.primary,
  condition: condition,
  description: description,
  address: address,
  userId: userId,
  isGiven: isGiven,
);

void main() {
  setUpAll(() async {
    await initFakeSupabase();
    // HomeProvider / HomeScreen start the realtime sync; prime it so no
    // real Supabase stream is opened.
    ProductStore.startRealtimeSync(repository: FakePostRepository());
  });

  setUp(() {
    ProductStore.items.value = [];
    ProductStore.isLoading.value = false;
    WishlistStore.items.value = [];
    RequestStore.reset();
  });

  group('ProductCard', () {
    Future<void> pumpCard(WidgetTester tester, Product p) async {
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: SizedBox(width: 200, child: ProductCard(product: p)),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('shows the name, category and condition', (tester) async {
      await pumpCard(tester, product('1', 'Headphones', condition: 'Old'));

      expect(find.text('Headphones'), findsOneWidget);
      expect(find.text('Electronics'), findsOneWidget);
      expect(find.text('Old'), findsOneWidget);
    });

    testWidgets('decodes the photo at thumbnail size, not full size', (
      tester,
    ) async {
      await pumpCard(
        tester,
        Product(
          id: '1',
          name: 'Lamp',
          category: 'Electronics',
          color: AppColors.primary,
          imageUrls: const ['https://img/1.png'],
        ),
      );

      final image = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      // A card is about half the screen wide; uploads are up to 1600 px.
      expect(image.memCacheWidth, tester.view.physicalSize.width ~/ 2);
    });

    testWidgets('without a photo it shows the first letter', (tester) async {
      await pumpCard(tester, product('1', 'Headphones'));

      expect(find.text('H'), findsOneWidget);
    });

    testWidgets('the "New" badge uses the brand color, "Old" a dark one', (
      tester,
    ) async {
      Color? badgeColor(String label) {
        final container = tester.widget<Container>(
          find
              .ancestor(of: find.text(label), matching: find.byType(Container))
              .first,
        );
        return (container.decoration as BoxDecoration).color;
      }

      await pumpCard(tester, product('1', 'A', condition: 'New'));
      expect(badgeColor('New'), AppColors.primary);

      await pumpCard(tester, product('2', 'B', condition: 'Old'));
      expect(badgeColor('Old'), isNot(AppColors.primary));
    });

    testWidgets(
      'the heart saves the item to the wishlist, and again removes it',
      (tester) async {
        await pumpCard(
          tester,
          product('p1', 'Lamp', category: 'Home & Living'),
        );
        final heart = find.byType(AppIcon);

        await tester.tap(heart);
        await tester.pump();

        expect(WishlistStore.items.value.map((i) => i.id), ['p1']);
        expect(WishlistStore.items.value.single.note, 'Home & Living');

        await tester.tap(heart);
        await tester.pump();

        expect(WishlistStore.items.value, isEmpty);
      },
    );

    testWidgets('an already-saved item shows as saved', (tester) async {
      WishlistStore.items.value = [
        WishItem(id: 'p1', title: 'Lamp', note: 'n'),
      ];
      await pumpCard(tester, product('p1', 'Lamp'));

      // Tapping a saved item's heart removes it (proves it rendered as saved).
      await tester.tap(find.byType(AppIcon));
      await tester.pump();
      expect(WishlistStore.items.value, isEmpty);
    });

    testWidgets('tapping the card opens the product detail screen', (
      tester,
    ) async {
      usePhoneSurface(tester);
      await pumpCard(
        tester,
        product('1', 'Headphones', description: 'Barely used'),
      );

      await tester.tap(find.text('Headphones'));
      await tester.pumpAndSettle();

      expect(find.byType(ProductDetailScreen), findsOneWidget);
      expect(find.text('Barely used'), findsOneWidget);
    });
  });

  group('FilterBottomSheet', () {
    testWidgets('lists categories, sort and condition options', (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        testApp(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showFilterBottomSheet(
                  context,
                  initial: const FilterOptions(),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Sort By'), findsOneWidget);
      expect(find.text('Condition'), findsOneWidget);
      expect(find.text('Books'), findsOneWidget);
      expect(find.text('Newest'), findsOneWidget);
      expect(find.text('Old'), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
    });

    testWidgets('Apply returns the chosen filters', (tester) async {
      usePhoneSurface(tester);
      FilterOptions? result;
      await tester.pumpWidget(
        testApp(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => result = await showFilterBottomSheet(
                  context,
                  initial: const FilterOptions(),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Books'));
      await tester.tap(find.text('Old'));
      await tester.pump();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(result!.category, 'Books');
      expect(result!.condition, 'Old');
      expect(result!.activeCount, 2);
    });

    testWidgets('Reset clears back to the defaults before applying', (
      tester,
    ) async {
      usePhoneSurface(tester);
      FilterOptions? result;
      await tester.pumpWidget(
        testApp(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => result = await showFilterBottomSheet(
                  context,
                  initial: const FilterOptions(
                    category: 'Toys',
                    condition: 'Old',
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reset'));
      await tester.pump();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(result!.category, 'All');
      expect(result!.condition, 'All');
      expect(result!.activeCount, 0);
    });

    testWidgets('closing without applying returns null', (tester) async {
      usePhoneSurface(tester);
      FilterOptions? result = const FilterOptions(category: 'sentinel');
      await tester.pumpWidget(
        testApp(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => result = await showFilterBottomSheet(
                  context,
                  initial: const FilterOptions(),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });
  });

  group('WishlistScreen', () {
    testWidgets('empty state', (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(testApp(const WishlistScreen()));
      await tester.pump();

      expect(find.text('Your wishlist is empty'), findsOneWidget);
    });

    testWidgets('shows only wished products that are still available', (
      tester,
    ) async {
      usePhoneSurface(tester);
      ProductStore.items.value = [
        product('1', 'Lamp'),
        product('2', 'Bike'),
        product('3', 'Given Sofa', isGiven: true),
      ];

      await tester.pumpWidget(testApp(const WishlistScreen()));
      await tester.pump();
      // initState syncs with Supabase and (signed out) empties the list, so
      // the wishlist is filled in after the first frame.
      WishlistStore.items.value = [
        WishItem(id: '1', title: 'Lamp', note: ''),
        WishItem(id: '3', title: 'Given Sofa', note: ''),
      ];
      await tester.pump();

      expect(find.text('Lamp'), findsOneWidget);
      expect(find.text('Bike'), findsNothing, reason: 'not wished');
      expect(find.text('Given Sofa'), findsNothing, reason: 'given away');
    });

    testWidgets('empty when every wished product was given away', (
      tester,
    ) async {
      usePhoneSurface(tester);
      ProductStore.items.value = [product('3', 'Given Sofa', isGiven: true)];

      await tester.pumpWidget(testApp(const WishlistScreen()));
      await tester.pump();
      WishlistStore.items.value = [
        WishItem(id: '3', title: 'Given Sofa', note: ''),
      ];
      await tester.pump();

      expect(find.text('Your wishlist is empty'), findsOneWidget);
    });
  });

  group('HomeScreen', () {
    late FakePostRepository repo;

    setUp(() => repo = FakePostRepository());

    /// [count] available posts: "Item 1" .. "Item N", newest first.
    List<PostModel> items(int count) => [
      for (var i = 1; i <= count; i++)
        makePost(id: 'p$i', title: 'Item $i', condition: 'New'),
    ];

    Future<void> pumpHome(
      WidgetTester tester, {
      Size size = const Size(600, 1400),
      ThemeMode themeMode = ThemeMode.light,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        testApp(HomeScreen(postRepository: repo), themeMode: themeMode),
      );
      await tester.pump();
    }

    // A screen too short to show all 8 cards of a page, so more products
    // only load once the user scrolls.
    const shortScreen = Size(600, 800);

    // The grid's own scrollable, not the search field's horizontal one.
    Finder scrollArea() => find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );

    /// The grid lays out lazily, so one long drag can stop short of the
    /// footer; drag until the bottom is really reached.
    Future<void> scrollToEnd(WidgetTester tester) async {
      for (var i = 0; i < 4; i++) {
        await tester.drag(scrollArea().first, const Offset(0, -20000));
        await tester.pump();
      }
    }

    testWidgets('shows the greeting, search and the product grid', (
      tester,
    ) async {
      repo.available = [
        makePost(id: '1', title: 'Headphones'),
        makePost(id: '2', title: 'Novel', category: 'Books'),
      ];

      await pumpHome(tester);

      expect(find.text('Welcome back 👋'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Headphones'), findsOneWidget);
      expect(find.text('Novel'), findsOneWidget);
    });

    testWidgets('search narrows the grid', (tester) async {
      repo.available = [
        makePost(id: '1', title: 'Headphones'),
        makePost(id: '2', title: 'Novel', category: 'Books'),
      ];
      await pumpHome(tester);

      await tester.enterText(find.byType(TextField), 'nov');
      await tester.pump(const Duration(milliseconds: 500)); // debounce
      await tester.pump();

      expect(repo.pageCalls.last.search, 'nov');
      expect(find.text('Novel'), findsOneWidget);
      expect(find.text('Headphones'), findsNothing);
    });

    testWidgets('no match shows the empty state, and Clear search restores', (
      tester,
    ) async {
      repo.available = [makePost(id: '1', title: 'Headphones')];
      await pumpHome(tester);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.text('No products found'), findsOneWidget);
      expect(
        find.text('Try a different search term or clear your filters'),
        findsOneWidget,
      );

      await tester.tap(find.text('Clear search'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Headphones'), findsOneWidget);
      expect(find.text('No products found'), findsNothing);
    });

    testWidgets('given-away products never appear', (tester) async {
      repo.available = [
        makePost(id: '1', title: 'Available'),
        makePost(id: '2', title: 'Gone', isGiven: true),
      ];

      await pumpHome(tester);

      expect(find.text('Available'), findsOneWidget);
      expect(find.text('Gone'), findsNothing);
    });

    testWidgets('shows a loading skeleton until the first page arrives', (
      tester,
    ) async {
      repo.available = items(3);
      repo.pageGate = Completer<void>();

      await pumpHome(tester);
      expect(find.byType(ProductCard), findsNothing);
      expect(find.text('No products found'), findsNothing);

      repo.pageGate!.complete();
      await tester.pump();
      await tester.pump();

      expect(find.byType(ProductCard), findsNWidgets(3));
    });

    testWidgets('loads only one page of products at first', (tester) async {
      repo.available = items(100);

      await pumpHome(tester, size: shortScreen);

      expect(repo.pageCalls, hasLength(1));
      expect(repo.pageCalls.single.limit, 20);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 41'), findsNothing);
    });

    testWidgets('scrolling to the end shows a loader, then more products', (
      tester,
    ) async {
      repo.available = items(100);
      await pumpHome(tester, size: shortScreen);
      repo.pageGate = Completer<void>();

      await scrollToEnd(tester);

      expect(repo.pageCalls, hasLength(2));
      expect(repo.pageCalls.last.afterId, 'p20');
      expect(find.byKey(const Key('home-load-more-skeleton')), findsOneWidget);

      repo.pageGate!.complete();
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('home-load-more-skeleton')), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Item 25'),
        300,
        scrollable: scrollArea(),
      );
      expect(find.text('Item 25'), findsOneWidget);
    });

    testWidgets('keeps loading pages until the last one, then stops', (
      tester,
    ) async {
      repo.available = items(25);
      await pumpHome(tester, size: shortScreen);

      await tester.drag(scrollArea().first, const Offset(0, -20000));
      await tester.pump();
      await tester.pump();
      expect(repo.pageCalls, hasLength(2));

      await tester.drag(scrollArea().first, const Offset(0, -20000));
      await tester.pump();
      await tester.pump();

      expect(repo.pageCalls, hasLength(2), reason: 'page of 5 was the last');
      expect(find.text('Item 25'), findsOneWidget);
      expect(find.byKey(const Key('home-load-more-skeleton')), findsNothing);
    });

    testWidgets('loads the next page by itself when the screen is not full', (
      tester,
    ) async {
      repo.available = items(20);

      await pumpHome(tester, size: const Size(600, 4000));
      await tester.pump();

      expect(repo.pageCalls.length, greaterThan(1));
      expect(find.text('Item 9'), findsOneWidget);
    });

    testWidgets('a failed page can be retried', (tester) async {
      repo.available = items(100);
      await pumpHome(tester, size: shortScreen);
      repo.pageError = Exception('offline');

      await scrollToEnd(tester);
      await tester.pump();

      final retry = find.text('Something went wrong. Please try again.');
      expect(retry, findsOneWidget);
      expect(repo.pageCalls, hasLength(2), reason: 'no automatic retry loop');

      repo.pageError = null;
      // The taller skeleton was just replaced by the short retry row, which
      // can sit just below the fold.
      await tester.ensureVisible(retry);
      await tester.pump();
      await tester.tap(retry);
      await tester.pump();
      await tester.pump();

      expect(retry, findsNothing);
      await tester.scrollUntilVisible(
        find.text('Item 25'),
        300,
        scrollable: scrollArea(),
      );
      expect(find.text('Item 25'), findsOneWidget);
    });

    testWidgets('renders in dark mode without layout errors', (tester) async {
      repo.available = [makePost(id: '1', title: 'Headphones')];

      await pumpHome(tester, themeMode: ThemeMode.dark);

      expect(find.text('Headphones'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('ProductDetailScreen', () {
    Future<void> pumpDetail(WidgetTester tester, Product p) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(testApp(ProductDetailScreen(product: p)));
      await tester.pump();
    }

    testWidgets('shows the item details and the "Give Me" action', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        product(
          '1',
          'Headphones',
          condition: 'Old',
          description: 'Barely used',
        ),
      );

      expect(find.text('Headphones'), findsWidgets);
      expect(find.text('Description'), findsOneWidget);
      expect(find.text('Barely used'), findsOneWidget);
      expect(find.text('Old'), findsWidgets);
      expect(find.widgetWithText(ElevatedButton, 'Give Me'), findsOneWidget);
    });

    testWidgets('shows the address next to condition and category', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        product('1', 'Headphones', address: 'House 5, Street 2'),
      );

      expect(find.text('Address'), findsOneWidget);
      expect(find.text('House 5, Street 2'), findsOneWidget);
    });

    testWidgets('a post without an address hides the address row', (
      tester,
    ) async {
      await pumpDetail(tester, product('1', 'Headphones'));

      expect(find.text('Condition'), findsOneWidget);
      expect(find.text('Address'), findsNothing);
    });

    testWidgets('an empty description shows a placeholder', (tester) async {
      await pumpDetail(tester, product('1', 'Headphones'));

      expect(
        find.text('No description available for this product.'),
        findsOneWidget,
      );
    });

    testWidgets('an item already requested offers "Message Owner"', (
      tester,
    ) async {
      RequestStore.sent.value = [makeRequest(postId: '1')];

      await pumpDetail(tester, product('1', 'Headphones'));

      expect(
        find.widgetWithText(ElevatedButton, 'Message Owner'),
        findsOneWidget,
      );
      expect(find.widgetWithText(ElevatedButton, 'Give Me'), findsNothing);
    });

    testWidgets('"Give Me" while signed out reports the failure', (
      tester,
    ) async {
      await pumpDetail(tester, product('1', 'Headphones'));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Give Me'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await pumpUntilToastVisible(tester);

      expect(
        find.text('Failed to send request. Please try again.'),
        findsOneWidget,
      );
      await settleToasts(tester);
    });
  });
}
