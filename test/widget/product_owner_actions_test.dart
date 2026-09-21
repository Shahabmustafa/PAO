import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pao/core/theme/app_colors.dart';
import 'package:pao/features/add_item/presentation/screens/add_item_screen.dart';
import 'package:pao/features/auth/data/model/user_model.dart';
import 'package:pao/features/home/data/product_store.dart';
import 'package:pao/features/home/domain/product.dart';
import 'package:pao/features/home/presentation/provider/product_detail_provider.dart';
import 'package:pao/features/home/presentation/screens/product_detail_screen.dart';
import 'package:pao/features/requests/data/request_store.dart';

import '../helpers/fakes.dart';
import '../helpers/test_app.dart';

Product lamp({bool isGiven = false}) => Product(
  id: 'p1',
  name: 'Lamp',
  category: 'Home & Living',
  color: AppColors.primary,
  description: 'Desk lamp',
  condition: 'Used',
  address: 'House 5, Street 2',
  userId: 'owner-1',
  isGiven: isGiven,
);

void main() {
  late FakeAuthRepository auth;
  late FakePostRepository posts;

  setUpAll(initFakeSupabase);

  setUp(() {
    auth = FakeAuthRepository(user: const UserModel(id: 'owner-1'));
    posts = FakePostRepository();
    ProductStore.items.value = [lamp()];
    RequestStore.reset();
  });

  /// Opens the detail screen on top of a home page, so "back" has somewhere
  /// to go, using a provider wired to the fakes.
  Future<void> openDetail(WidgetTester tester, {Product? product}) async {
    usePhoneSurface(tester);
    final shown = product ?? lamp();
    await tester.pumpWidget(
      testApp(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDetailScreen(
                      product: shown,
                      provider: ProductDetailProvider(
                        product: shown,
                        authRepository: auth,
                        postRepository: posts,
                        // No profile: a poster avatar would wait on the
                        // network forever and stop the test from settling.
                        profileRepository: FakeProfileRepository(),
                      ),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('owner menu', () {
    testWidgets('the owner of a post gets an Edit / Delete menu', (
      tester,
    ) async {
      await openDetail(tester);

      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      await openMenu(tester);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('someone else does not', (tester) async {
      auth.user = const UserModel(id: 'someone-else');
      await openDetail(tester);

      expect(find.byIcon(Icons.more_vert), findsNothing);
    });

    testWidgets('a post that was already given away is locked', (tester) async {
      ProductStore.items.value = [lamp(isGiven: true)];
      await openDetail(tester, product: lamp(isGiven: true));

      expect(find.byIcon(Icons.more_vert), findsNothing);
    });
  });

  group('deleting', () {
    Future<void> tapDelete(WidgetTester tester) async {
      await openMenu(tester);
      await tester.tap(find.text('Delete'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('asks first and does nothing if cancelled', (tester) async {
      await openDetail(tester);

      await tapDelete(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('Delete "Lamp"?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AlertDialog), findsNothing);
      expect(posts.deleteCalls, isEmpty);
      expect(find.byType(ProductDetailScreen), findsOneWidget);
      expect(ProductStore.items.value, hasLength(1));
    });

    testWidgets('confirming deletes the post and leaves the screen', (
      tester,
    ) async {
      await openDetail(tester);

      await tapDelete(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(posts.deleteCalls.single['postId'], 'p1');
      expect(ProductStore.items.value, isEmpty);
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.byType(ProductDetailScreen), findsNothing);
      await pumpUntilToastVisible(tester);
      expect(find.text('Product deleted'), findsOneWidget);
      await settleToasts(tester);
    });

    testWidgets('a failure keeps the screen open and says why', (tester) async {
      posts.deleteError = Exception('offline');
      await openDetail(tester);

      await tapDelete(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await pumpUntilToastVisible(tester);

      expect(find.byType(ProductDetailScreen), findsOneWidget);
      expect(
        find.text('Failed to delete product. Please try again.'),
        findsOneWidget,
      );
      expect(ProductStore.items.value, hasLength(1));
      await settleToasts(tester);
    });
  });

  group('editing', () {
    testWidgets('Edit opens the form for that post', (tester) async {
      await openDetail(tester);

      await openMenu(tester);
      await tester.tap(find.text('Edit'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(AddItemScreen), findsOneWidget);
      expect(find.text('Edit Product'), findsOneWidget);
    });

    testWidgets('the detail screen shows the new version after an edit', (
      tester,
    ) async {
      await openDetail(tester);
      expect(find.text('Lamp'), findsWidgets);

      // What AddItemScreen does once the update succeeds.
      ProductStore.update(
        Product(
          id: 'p1',
          name: 'Reading Lamp',
          category: 'Home & Living',
          color: AppColors.primary,
          condition: 'Old',
          address: 'New address',
          userId: 'owner-1',
        ),
      );
      await tester.pump();

      expect(find.text('Reading Lamp'), findsWidgets);
      expect(find.text('New address'), findsOneWidget);
      expect(find.text('Old'), findsWidgets);
    });
  });

  group('AddItemScreen in edit mode', () {
    Future<void> pumpEdit(WidgetTester tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(testApp(AddItemScreen(product: lamp())));
    }

    testWidgets('is titled "Edit Product" with a Save Changes button', (
      tester,
    ) async {
      await pumpEdit(tester);

      expect(find.text('Edit Product'), findsOneWidget);
      expect(find.text('Add Product'), findsNothing);
      expect(
        find.widgetWithText(ElevatedButton, 'Save Changes'),
        findsOneWidget,
      );
      expect(find.text('Post for Free'), findsNothing);
    });

    testWidgets('is pre-filled with the current details', (tester) async {
      await pumpEdit(tester);

      expect(find.text('Lamp'), findsOneWidget);
      expect(find.text('Desk lamp'), findsOneWidget);
      expect(find.text('House 5, Street 2'), findsOneWidget);

      final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip));
      final selected = [
        for (final chip in chips)
          if (chip.selected) (chip.label as Text).data,
      ];
      expect(selected, unorderedEquals(['Home & Living', 'Used']));
    });

    testWidgets('the address stays required', (tester) async {
      await pumpEdit(tester);

      await tester.enterText(find.text('House 5, Street 2'), '   ');
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pump();

      expect(find.text('Address is required'), findsOneWidget);
    });

    testWidgets('saving while signed out explains why it failed', (
      tester,
    ) async {
      await pumpEdit(tester);

      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await pumpUntilToastVisible(tester);

      expect(
        find.text('You must be logged in to post an item.'),
        findsOneWidget,
      );
      await settleToasts(tester);
    });
  });
}
