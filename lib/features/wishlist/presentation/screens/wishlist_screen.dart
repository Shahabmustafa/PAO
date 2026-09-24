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
import '../../../../core/l10n/l10n.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  @override
  void initState() {
    super.initState();
    WishlistStore.syncFromSupabase(force: false).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.wishlist,
          style: const TextStyle(fontWeight: FontWeight.bold),
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

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () =>
                      WishlistStore.syncFromSupabase().catchError((_) {}),
                  child: MasonryGridView.count(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 12,
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      return ProductCard(product: products[index]);
                    },
                  ),
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
            context.l10n.wishlistEmpty,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.wishlistEmptyHint,
            style: TextStyle(fontSize: 13, color: context.appTextSecondary),
          ),
        ],
      ),
    );
  }
}
