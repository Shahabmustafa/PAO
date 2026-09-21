import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pao/core/theme/app_colors.dart';
import 'package:pao/core/theme/app_icons.dart';
import 'package:pao/core/widgets/app_icon.dart';
import 'package:pao/features/home/domain/product.dart';
import 'package:pao/features/home/presentation/widgets/product_card.dart';
import 'package:pao/features/wishlist/data/wishlist_store.dart';

import '../helpers/test_app.dart';

void main() {
  setUpAll(initFakeSupabase);
  setUp(() => WishlistStore.items.value = []);

  final lamp = Product(
    id: 'p1',
    name: 'Lamp',
    category: 'Home & Living',
    color: AppColors.primary,
  );

  Finder heart() => find.byWidgetPredicate(
    (w) =>
        w is AppIcon &&
        (w.asset == AppIcons.favoriteOutline ||
            w.asset == AppIcons.favoriteFilled),
  );

  Future<void> pumpCard(WidgetTester tester, {bool? showWishlistButton}) async {
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: SizedBox(
            width: 200,
            child: showWishlistButton == null
                ? ProductCard(product: lamp)
                : ProductCard(
                    product: lamp,
                    showWishlistButton: showWishlistButton,
                  ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the wishlist heart by default', (tester) async {
    await pumpCard(tester);

    expect(heart(), findsOneWidget);
  });

  testWidgets('the heart can be hidden, e.g. on profile lists', (tester) async {
    await pumpCard(tester, showWishlistButton: false);

    expect(heart(), findsNothing);
    // The rest of the card is unaffected.
    expect(find.text('Lamp'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
  });
}
