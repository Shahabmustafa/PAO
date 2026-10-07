import '../../../../core/tour/app_tour.dart';
import 'package:flutter/material.dart';
import '../../../../core/update/update_checker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../add_item/data/repository/post_repository.dart';
import '../../../auth/data/repository/auth_repository.dart';
import '../../../profile/presentation/screens/user_profile_screen.dart';
import '../../../wishlist/presentation/screens/wishlist_screen.dart';
import '../../domain/localized_labels.dart';
import '../../domain/product.dart';
import '../provider/home_sections_provider.dart';
import '../widgets/product_card.dart';
import 'category_products_screen.dart';
import '../../../../core/l10n/l10n.dart';

/// The feed, one horizontal row per category. "View all" on a row opens
/// [CategoryProductsScreen] with every product of that category.
class HomeScreen extends StatelessWidget {
  final PostRepository? postRepository;

  const HomeScreen({super.key, this.postRepository});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HomeSectionsProvider(postRepository: postRepository),
      child: _HomeView(postRepository: postRepository),
    );
  }
}

class _HomeView extends StatefulWidget {
  final PostRepository? postRepository;

  const _HomeView({this.postRepository});

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  final _authRepository = AuthRepository();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => UpdateChecker.checkAndPrompt(),
    );
  }

  void _openCategory(String category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryProductsScreen(
          category: category,
          postRepository: widget.postRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sections = context.watch<HomeSectionsProvider>();
    final categories = sections.visibleCategories;
    // Space taken by the floating nav bar (and system insets) below the list.
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: sections.refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: StreamBuilder<AuthState>(
                    stream: _authRepository.authStateChanges,
                    builder: (context, _) {
                      final currentUser = _authRepository.currentUser;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: currentUser == null
                                ? null
                                : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => UserProfileScreen(
                                        userId: currentUser.id,
                                      ),
                                    ),
                                  ),
                            child: AppAvatar(
                              radius: 24,
                              imageUrl: currentUser?.avatarUrl,
                              ring: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.l10n.welcomeBackGreeting,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: context.appTextSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currentUser?.fullName ??
                                      context.l10n.yourName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: context.appTextPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            key: TourKeys.navWishlist,
                            tooltip: context.l10n.wishlist,
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const WishlistScreen(),
                              ),
                            ),
                            icon: const AppIcon(
                              AppIcons.favoriteOutline,
                              size: 24,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              if (sections.isLoading && categories.isEmpty)
                SliverPadding(
                  padding: EdgeInsets.only(bottom: 20 + bottomInset),
                  sliver: SliverList.list(
                    children: const [_SectionShimmer(), _SectionShimmer()],
                  ),
                )
              else if (categories.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, bottomInset),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            height: 56,
                            width: 56,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: AppIcon(
                                AppIcons.search,
                                size: 26,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            context.l10n.noProductsFound,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: context.appTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.only(bottom: 20 + bottomInset),
                  sliver: SliverList.builder(
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      return _CategorySection(
                        key: ValueKey(category),
                        category: category,
                        products: sections.productsOf(category),
                        onViewAll: () => _openCategory(category),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A category title with a "View all" button, above a horizontal row of
/// that category's newest products.
class _CategorySection extends StatelessWidget {
  final String category;
  final List<Product> products;
  final VoidCallback onViewAll;

  const _CategorySection({
    super.key,
    required this.category,
    required this.products,
    required this.onViewAll,
  });

  static const double cardWidth = 150;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 20, end: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    categoryLabel(context.l10n, category),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: context.appTextPrimary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onViewAll,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                  child: Text(context.l10n.viewAll),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // A Row sized by its cards rather than a fixed-height ListView, so
          // larger text sizes never clip the card titles. Rows are short
          // (HomeSectionsProvider.sectionSize), so building them all is fine.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < products.length; i++)
                  Padding(
                    padding: EdgeInsetsDirectional.only(
                      end: i == products.length - 1 ? 0 : 12,
                    ),
                    child: SizedBox(
                      width: cardWidth,
                      child: ProductCard(
                        key: ValueKey(products[i].id),
                        product: products[i],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionShimmer extends StatelessWidget {
  const _SectionShimmer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppShimmer(
            width: 110,
            height: 16,
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Row(
              children: [
                for (var i = 0; i < 3; i++)
                  Container(
                    width: _CategorySection.cardWidth,
                    margin: const EdgeInsetsDirectional.only(end: 12),
                    decoration: BoxDecoration(
                      color: context.appSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.appBorder),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AspectRatio(aspectRatio: 1, child: AppShimmer()),
                        Padding(
                          padding: EdgeInsets.fromLTRB(10, 10, 10, 12),
                          child: AppShimmer(
                            width: 90,
                            height: 12,
                            borderRadius: BorderRadius.all(Radius.circular(4)),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
