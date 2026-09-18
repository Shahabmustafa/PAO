import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../home/data/product_store.dart';
import '../../../home/domain/product.dart';
import '../../../home/presentation/widgets/product_card.dart';
import '../../data/wishlist_store.dart';
import '../../domain/wish_item.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  @override
  void initState() {
    super.initState();
    WishlistStore.syncFromSupabase().catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Wishlist',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: ValueListenableBuilder<List<WishItem>>(
          valueListenable: WishlistStore.items,
          builder: (context, wishItems, _) {
            if (wishItems.isEmpty) {
              return const _EmptyWishlist();
            }
            return ValueListenableBuilder<List<Product>>(
              valueListenable: ProductStore.items,
              builder: (context, allProducts, _) {
                final wishedIds = wishItems.map((item) => item.id).toSet();
                final products = allProducts
                    .where(
                      (product) =>
                          wishedIds.contains(product.id) && !product.isGiven,
                    )
                    .toList();

                if (products.isEmpty) {
                  return const _EmptyWishlist();
                }

                return MasonryGridView.count(
                  padding: const EdgeInsets.all(20),
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 0,
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    return ProductCard(product: products[index]);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _EmptyWishlist extends StatelessWidget {
  const _EmptyWishlist();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 80,
            width: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: AppIcon(
                AppIcons.favoriteOutline,
                size: 36,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Your wishlist is empty',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap the Add button to save something',
            style: TextStyle(fontSize: 13, color: context.appTextSecondary),
          ),
        ],
      ),
    );
  }
}
