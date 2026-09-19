import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pao/core/theme/app_colors.dart';
import 'package:pao/core/widgets/app_icon.dart';
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
  String? userId = 'someone-else',
  bool isGiven = false,
}) => Product(
  id: id,
  name: name,
  category: category,
  color: AppColors.primary,
  condition: condition,
  description: description,
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

    testWidgets('without a photo it shows the first letter', (tester) async {
      await pumpCard(tester, product('1', 'Headphones'));

      expect(find.text('H'), findsOneWidget);
    });

    testWidgets('the "New" badge uses the brand color, "Old" a dark one', (
      tester,
    ) async {
      Color? badgeColor(String label) {
        final container = tester.widget<Container>(
          find.ancestor(of: find.text(label), matching: find.byType(Container)).first,
        );
        return (container.decoration as BoxDecoration).color;
      }

      await pumpCard(tester, product('1', 'A', condition: 'New'));
      expect(badgeColor('New'), AppColors.primary);

      await pumpCard(tester, product('2', 'B', condition: 'Old'));
      expect(badgeColor('Old'), isNot(AppColors.primary));
    });

    testWidgets('the heart saves the item to the wishlist, and again removes it', (
      tester,
    ) async {
      await pumpCard(tester, product('p1', 'Lamp', category: 'Home & Living'));
      final heart = find.byType(AppIcon);

      await tester.tap(heart);
      await tester.pump();

      expect(WishlistStore.items.value.map((i) => i.id), ['p1']);
      expect(WishlistStore.items.value.single.note, 'Home & Living');

      await tester.tap(heart);
      await tester.pump();

      expect(WishlistStore.items.value, isEmpty);
    });

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
      await pumpCard(tester, product('1', 'Headphones', description: 'Barely used'));

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
                onPressed: () =>
                    showFilterBottomSheet(context, initial: const FilterOptions()),
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
                  initial: const FilterOptions(category: 'Toys', condition: 'Old'),
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
    Future<void> pumpHome(WidgetTester tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(testApp(const HomeScreen()));
      await tester.pump();
    }

    testWidgets('shows the greeting, search and the product grid', (
      tester,
    ) async {
      ProductStore.items.value = [
        product('1', 'Headphones'),
        product('2', 'Novel', category: 'Books'),
      ];

      await pumpHome(tester);

      expect(find.text('Welcome back 👋'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Headphones'), findsOneWidget);
      expect(find.text('Novel'), findsOneWidget);
    });

    testWidgets('search narrows the grid', (tester) async {
      ProductStore.items.value = [
        product('1', 'Headphones'),
        product('2', 'Novel', category: 'Books'),
      ];
      await pumpHome(tester);

      await tester.enterText(find.byType(TextField), 'nov');
      await tester.pump();

      expect(find.text('Novel'), findsOneWidget);
      expect(find.text('Headphones'), findsNothing);
    });

    testWidgets('no match shows the empty state, and Clear search restores', (
      tester,
    ) async {
      ProductStore.items.value = [product('1', 'Headphones')];
      await pumpHome(tester);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();

      expect(find.text('No products found'), findsOneWidget);
      expect(
        find.text('Try a different search term or clear your filters'),
        findsOneWidget,
      );

      await tester.tap(find.text('Clear search'));
      await tester.pump();

      expect(find.text('Headphones'), findsOneWidget);
      expect(find.text('No products found'), findsNothing);
    });

    testWidgets('given-away products never appear', (tester) async {
      ProductStore.items.value = [
        product('1', 'Available'),
        product('2', 'Gone', isGiven: true),
      ];

      await pumpHome(tester);

      expect(find.text('Available'), findsOneWidget);
      expect(find.text('Gone'), findsNothing);
    });

    testWidgets('renders in dark mode without layout errors', (tester) async {
      usePhoneSurface(tester);
      ProductStore.items.value = [product('1', 'Headphones')];

      await tester.pumpWidget(
        testApp(const HomeScreen(), themeMode: ThemeMode.dark),
      );
      await tester.pump();

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
        product('1', 'Headphones', condition: 'Old', description: 'Barely used'),
      );

      expect(find.text('Headphones'), findsWidgets);
      expect(find.text('Description'), findsOneWidget);
      expect(find.text('Barely used'), findsOneWidget);
      expect(find.text('Old'), findsWidgets);
      expect(find.widgetWithText(ElevatedButton, 'Give Me'), findsOneWidget);
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

      expect(find.widgetWithText(ElevatedButton, 'Message Owner'), findsOneWidget);
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
