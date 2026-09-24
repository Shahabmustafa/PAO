import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/config/app_links.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../add_item/presentation/screens/add_item_screen.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
import '../../../profile/presentation/screens/user_profile_screen.dart';
import '../../../requests/data/model/request_model.dart';
import '../../../requests/data/request_store.dart';
import '../../../wishlist/data/wishlist_store.dart';
import '../../../wishlist/domain/wish_item.dart';
import '../../data/product_store.dart';
import '../../domain/product.dart';
import '../provider/product_detail_provider.dart';
import '../../../../core/l10n/l10n.dart';
import '../../domain/localized_labels.dart';

class ProductDetailScreen extends StatelessWidget {
  final Product product;

  /// Lets a test supply a provider wired to fakes; the app builds its own.
  @visibleForTesting
  final ProductDetailProvider? provider;

  const ProductDetailScreen({super.key, required this.product, this.provider});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => provider ?? ProductDetailProvider(product: product),
      // After the owner edits the post, the store holds the new version.
      child: ValueListenableBuilder<List<Product>>(
        valueListenable: ProductStore.items,
        builder: (context, items, _) => _ProductDetailView(
          product: items.firstWhere(
            (p) => p.id == product.id,
            orElse: () => product,
          ),
        ),
      ),
    );
  }
}

class _ProductDetailView extends StatelessWidget {
  final Product product;

  const _ProductDetailView({required this.product});

  void _toggleWishlist(bool isSaved) {
    if (isSaved) {
      WishlistStore.remove(product.id);
    } else {
      WishlistStore.add(
        WishItem(id: product.id, title: product.name, note: product.category),
      );
    }
  }

  void _onSharePressed(BuildContext context) {
    SharePlus.instance.share(
      ShareParams(
        text:
            '${context.l10n.shareProduct(product.name)}\n${AppLinks.playStore}',
      ),
    );
  }

  Future<void> _onGiveMePressed(BuildContext context) async {
    final provider = context.read<ProductDetailProvider>();
    final success = await provider.sendRequest();
    if (!context.mounted) return;

    if (success) {
      // Continue in the conversation with the owner, where they can accept.
      final request = RequestStore.sent.value
          .where((r) => r.postId == product.id)
          .firstOrNull;
      if (request != null) _onOpenChatPressed(context, request);
    } else {
      AppSnackbar.show(
        context,
        provider.errorMessage ?? context.l10n.failedToSendRequest,
        icon: Icons.error_outline,
        color: AppColors.error,
      );
    }
  }

  void _onOpenChatPressed(BuildContext context, RequestModel request) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          request: request,
          otherUserId: request.ownerId,
          productName: product.name,
        ),
      ),
    );
  }

  Future<void> _onEditPressed(BuildContext context) async {
    final updated = await Navigator.push<Product>(
      context,
      MaterialPageRoute(builder: (_) => AddItemScreen(product: product)),
    );
    if (updated == null || !context.mounted) return;
    AppSnackbar.show(context, context.l10n.productUpdated);
  }

  Future<void> _onDeletePressed(BuildContext context) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: context.l10n.delete,
      message: context.l10n.deleteProductConfirm(product.name),
      confirmText: context.l10n.delete,
      cancelText: context.l10n.cancel,
      isDestructive: true,
      icon: AppIcons.delete,
    );
    if (!confirmed || !context.mounted) return;

    final provider = context.read<ProductDetailProvider>();
    final success = await provider.deleteProduct();
    if (!context.mounted) return;

    if (success) {
      Navigator.pop(context);
      AppSnackbar.show(context, context.l10n.productDeleted);
    } else {
      AppSnackbar.show(
        context,
        provider.errorMessage ?? context.l10n.failedToDeleteProduct,
        icon: Icons.error_outline,
        color: AppColors.error,
      );
    }
  }

  Future<void> _onMarkAsGivenPressed(BuildContext context) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: context.l10n.markAsGiven,
      message: context.l10n.markAsGivenConfirm(product.name),
      confirmText: context.l10n.yesGiven,
      cancelText: context.l10n.cancel,
      icon: AppIcons.checkCircle,
    );
    if (!confirmed) return;
    if (!context.mounted) return;

    final provider = context.read<ProductDetailProvider>();
    final success = await provider.markAsGiven();
    if (!context.mounted) return;

    if (success) {
      Navigator.pop(context);
    } else {
      AppSnackbar.show(
        context,
        provider.errorMessage ?? context.l10n.failedToUpdate,
        icon: Icons.error_outline,
        color: AppColors.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductDetailProvider>();

    return Scaffold(
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: provider.isOwner
              ? PrimaryButton(
                  label: context.l10n.markAsGiven,
                  isLoading: provider.isMarkingGiven,
                  onPressed: () => _onMarkAsGivenPressed(context),
                )
              : ValueListenableBuilder<List<RequestModel>>(
                  valueListenable: RequestStore.sent,
                  builder: (context, sent, _) {
                    final existing = sent.where((r) => r.postId == product.id);
                    if (existing.isNotEmpty) {
                      return PrimaryButton(
                        label: context.l10n.messageOwner,
                        onPressed: () =>
                            _onOpenChatPressed(context, existing.first),
                      );
                    }
                    return PrimaryButton(
                      label: context.l10n.giveMe,
                      isLoading: provider.isRequesting,
                      onPressed: () => _onGiveMePressed(context),
                    );
                  },
                ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: _ProductGallery(product: product),
                ),
                PositionedDirectional(
                  top: 8,
                  start: 8,
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      height: 36,
                      width: 36,
                      decoration: BoxDecoration(
                        color: context.appSurface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                PositionedDirectional(
                  top: 8,
                  end: 52,
                  child: InkWell(
                    onTap: () => _onSharePressed(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      height: 36,
                      width: 36,
                      decoration: BoxDecoration(
                        color: context.appSurface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.share,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                PositionedDirectional(
                  top: 8,
                  end: 8,
                  child: provider.isOwner && !product.isGiven
                      ? _OwnerMenu(
                          isBusy: provider.isDeleting,
                          onEdit: () => _onEditPressed(context),
                          onDelete: () => _onDeletePressed(context),
                        )
                      : ValueListenableBuilder<List<WishItem>>(
                          valueListenable: WishlistStore.items,
                          builder: (context, items, _) {
                            final isSaved = items.any(
                              (item) => item.id == product.id,
                            );
                            return InkWell(
                              onTap: () => _toggleWishlist(isSaved),
                              borderRadius: BorderRadius.circular(20),
                              child: SizedBox(
                                height: 36,
                                width: 36,
                                child: AppIcon(
                                  isSaved
                                      ? AppIcons.favoriteFilled
                                      : AppIcons.favoriteOutline,
                                  size: 22,
                                  color: AppColors.primary,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: context.appTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: context.appSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.appBorder),
                    ),
                    child: Column(
                      children: [
                        _DetailRow(
                          label: context.l10n.condition,
                          value: conditionLabel(
                            context.l10n,
                            product.condition,
                          ),
                        ),
                        Divider(height: 1, color: context.appBorder),
                        _DetailRow(
                          label: context.l10n.category,
                          value: categoryLabel(context.l10n, product.category),
                        ),
                        if (product.address?.isNotEmpty ?? false) ...[
                          Divider(height: 1, color: context.appBorder),
                          _DetailRow(
                            label: context.l10n.address,
                            value: product.address!,
                          ),
                        ],
                        if (product.createdAt != null) ...[
                          Divider(height: 1, color: context.appBorder),
                          _DetailRow(
                            label: context.l10n.postedOn,
                            value: DateFormat(
                              'd MMM yyyy',
                            ).format(product.createdAt!.toLocal()),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: provider.isLoadingPoster || product.userId == null
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  UserProfileScreen(userId: product.userId!),
                            ),
                          ),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.appSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: context.appBorder),
                      ),
                      child: provider.isLoadingPoster
                          ? const Row(
                              children: [
                                AppShimmer(
                                  width: 44,
                                  height: 44,
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(22),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      AppShimmer(
                                        width: 70,
                                        height: 10,
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(4),
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      AppShimmer(
                                        width: 120,
                                        height: 14,
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(4),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                AppAvatar(
                                  radius: 22,
                                  imageUrl: provider.posterProfile?.avatarUrl,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        context.l10n.postedBy,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: context.appTextSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        provider.posterProfile?.fullName ??
                                            context.l10n.paoUser,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: context.appTextPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const AppIcon(
                                  AppIcons.chevronRight,
                                  mirrorInRtl: true,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    context.l10n.description,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: context.appTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.description.isNotEmpty
                        ? product.description
                        : context.l10n.noDescription,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
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

/// Edit / Delete menu shown to the owner of a post, in the corner of the
/// photo (where other users get the wishlist heart).
class _OwnerMenu extends StatelessWidget {
  final bool isBusy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _OwnerMenu({
    required this.isBusy,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      width: 36,
      decoration: BoxDecoration(
        color: context.appSurface,
        shape: BoxShape.circle,
      ),
      child: isBusy
          ? const Padding(
              padding: EdgeInsets.all(9),
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : PopupMenuButton<VoidCallback>(
              padding: EdgeInsets.zero,
              tooltip: '',
              icon: const Icon(
                Icons.more_vert,
                size: 20,
                color: AppColors.primary,
              ),
              onSelected: (action) => action(),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: onEdit,
                  child: Row(
                    children: [
                      const Icon(Icons.edit_outlined, size: 20),
                      const SizedBox(width: 12),
                      Text(context.l10n.edit),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: onDelete,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        context.l10n.delete,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: context.appTextSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.appTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductGallery extends StatefulWidget {
  final Product product;

  const _ProductGallery({required this.product});

  @override
  State<_ProductGallery> createState() => _ProductGalleryState();
}

class _ProductGalleryState extends State<_ProductGallery> {
  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final useLocal = product.images.isNotEmpty;
    final count = useLocal ? product.images.length : product.imageUrls.length;

    if (count == 0) {
      return _ProductInitial(product: product);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: count,
          onPageChanged: (index) => setState(() => _page = index),
          itemBuilder: (context, index) {
            return useLocal
                ? Image.memory(product.images[index], fit: BoxFit.cover)
                : AppNetworkImage(
                    imageUrl: product.imageUrls[index],
                    memCacheWidth: AppNetworkImage.pixelWidth(
                      context,
                      MediaQuery.sizeOf(context).width,
                    ),
                    errorBuilder: (context) =>
                        _ProductInitial(product: product),
                  );
          },
        ),
        if (count > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < count; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    height: 6,
                    width: i == _page ? 18 : 6,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
      ],
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
          fontSize: 56,
          fontWeight: FontWeight.bold,
          color: product.color,
        ),
      ),
    );
  }
}
