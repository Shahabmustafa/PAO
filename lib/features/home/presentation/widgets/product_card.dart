import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../wishlist/data/wishlist_store.dart';
import '../../../wishlist/domain/wish_item.dart';
import '../../domain/product.dart';
import '../screens/product_detail_screen.dart';
import '../../../../core/l10n/l10n.dart';
import '../../domain/localized_labels.dart';

class ProductCard extends StatelessWidget {
  final Product product;

  /// Whether the heart button that adds the product to the wishlist is shown.
  final bool showWishlistButton;

  const ProductCard({
    super.key,
    required this.product,
    this.showWishlistButton = true,
  });

  void _toggleWishlist(bool isSaved) {
    if (isSaved) {
      WishlistStore.remove(product.id);
    } else {
      WishlistStore.add(
        WishItem(id: product.id, title: product.name, note: product.category),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(product: product),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.appBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: product.images.isNotEmpty
                        ? Image.memory(product.images.first, fit: BoxFit.cover)
                        : product.imageUrl != null
                        ? AppNetworkImage(
                            imageUrl: product.imageUrl!,
                            errorBuilder: (context) =>
                                _ProductInitial(product: product),
                          )
                        : _ProductInitial(product: product),
                  ),
                  PositionedDirectional(
                    top: 8,
                    start: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: product.condition == 'New'
                            ? AppColors.primary
                            : Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        conditionLabel(context.l10n, product.condition),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: product.condition == 'New'
                              ? AppColors.onPrimary
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                  if (showWishlistButton)
                    PositionedDirectional(
                      top: 8,
                      end: 8,
                      child: ValueListenableBuilder<List<WishItem>>(
                        valueListenable: WishlistStore.items,
                        builder: (context, items, _) {
                          final isSaved = items.any(
                            (item) => item.id == product.id,
                          );
                          return GestureDetector(
                            onTap: () => _toggleWishlist(isSaved),
                            child: SizedBox(
                              height: 22,
                              width: 22,
                              child: AppIcon(
                                isSaved
                                    ? AppIcons.favoriteFilled
                                    : AppIcons.favoriteOutline,
                                size: 12,
                                color: AppColors.primary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.appTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    categoryLabel(context.l10n, product.category),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.appTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductInitial extends StatelessWidget {
  final Product product;

  const _ProductInitial({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: product.color.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Text(
        product.name.substring(0, 1),
        style: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: product.color,
        ),
      ),
    );
  }
}
