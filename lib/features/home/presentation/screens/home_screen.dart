import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
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
import '../provider/home_provider.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/product_card.dart';
import '../../../../core/l10n/l10n.dart';

class HomeScreen extends StatelessWidget {
  final bool autofocusSearch;
  final PostRepository? postRepository;

  const HomeScreen({
    super.key,
    this.autofocusSearch = false,
    this.postRepository,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HomeProvider(postRepository: postRepository),
      child: _HomeView(autofocusSearch: autofocusSearch),
    );
  }
}

class _HomeView extends StatefulWidget {
  final bool autofocusSearch;

  const _HomeView({required this.autofocusSearch});

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _authRepository = AuthRepository();
  final _scrollController = ScrollController();

  // Start fetching the next page once the user is this close to the end.
  static const double _loadMoreThreshold = 300;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreIfNearEnd);
    if (widget.autofocusSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _loadMoreIfNearEnd() {
    if (!mounted || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (!position.hasContentDimensions) return;
    final provider = context.read<HomeProvider>();
    // After a failure the footer's retry button decides, not the scroll.
    if (provider.loadMoreFailed) return;
    if (position.extentAfter < _loadMoreThreshold) provider.loadMore();
  }

  Future<void> _onFilterTapped() async {
    final homeProvider = context.read<HomeProvider>();
    final result = await showFilterBottomSheet(
      context,
      initial: homeProvider.filters.copyWith(
        category: homeProvider.selectedCategory,
      ),
    );
    if (result != null) homeProvider.applyFilters(result);
  }

  @override
  Widget build(BuildContext context) {
    final homeProvider = context.watch<HomeProvider>();
    final activeFilterCount = homeProvider.filters.activeCount;

    final products = homeProvider.products;
    final isLoading = homeProvider.isLoading;
    // Space taken by the floating nav bar (and system insets) below the grid.
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    // When a page doesn't fill the screen there is nothing to scroll, so the
    // next page has to be requested without a scroll event.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMoreIfNearEnd());

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: homeProvider.refresh,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.only(top: 20),
                sliver: SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
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
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
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
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.textPrimary.withValues(
                                  alpha: 0.06,
                                ),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            onChanged: homeProvider.onSearchChanged,
                            style: TextStyle(
                              fontSize: 15,
                              color: context.appTextPrimary,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: context.l10n.searchHint,
                              hintStyle: TextStyle(
                                fontSize: 15,
                                color: context.appTextSecondary,
                              ),
                              filled: true,
                              fillColor: context.appSurface,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              prefixIcon: const Padding(
                                padding: EdgeInsets.all(12),
                                child: AppIcon(
                                  AppIcons.search,
                                  size: 20,
                                  color: AppColors.primary,
                                ),
                              ),
                              suffixIcon: homeProvider.hasActiveSearch
                                  ? IconButton(
                                      icon: Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                        color: context.appTextSecondary,
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        homeProvider.clearSearch();
                                      },
                                    )
                                  : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(28),
                                borderSide: BorderSide(
                                  color: context.appBorder,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(28),
                                borderSide: BorderSide(
                                  color: context.appBorder,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(28),
                                borderSide: const BorderSide(
                                  color: AppColors.primary,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _FilterButton(
                        activeCount: activeFilterCount,
                        onTap: _onFilterTapped,
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              if (isLoading && products.isEmpty)
                SliverPadding(
                  padding: EdgeInsets.only(bottom: 20 + bottomInset),
                  sliver: const SliverToBoxAdapter(
                    child: _ProductGridShimmer(),
                  ),
                )
              else if (products.isEmpty)
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
                          const SizedBox(height: 6),
                          Text(
                            context.l10n.tryDifferentSearch,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: context.appTextSecondary,
                            ),
                          ),
                          if (homeProvider.hasActiveSearch) ...[
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () {
                                _searchController.clear();
                                homeProvider.clearSearch();
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                              ),
                              child: Text(context.l10n.clearSearch),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverMasonryGrid.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 12,
                    childCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return ProductCard(
                        key: ValueKey(product.id),
                        product: product,
                      );
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: _LoadMoreFooter(
                    isLoading: homeProvider.isLoadingMore,
                    failed: homeProvider.loadMoreFailed,
                    onRetry: homeProvider.loadMore,
                    bottomInset: bottomInset,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom of the grid: placeholder cards while the next page loads, or a
/// retry button if that request failed.
class _LoadMoreFooter extends StatelessWidget {
  final bool isLoading;
  final bool failed;
  final VoidCallback onRetry;
  final double bottomInset;

  const _LoadMoreFooter({
    required this.isLoading,
    required this.failed,
    required this.onRetry,
    required this.bottomInset,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Padding(
        padding: EdgeInsets.only(top: 14, bottom: 20 + bottomInset),
        child: const _ProductGridShimmer(
          key: Key('home-load-more-skeleton'),
          itemCount: 2,
        ),
      );
    }
    if (failed) {
      return Padding(
        padding: EdgeInsets.only(top: 12, bottom: 12 + bottomInset),
        child: Center(
          child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(context.l10n.somethingWentWrong),
            style: TextButton.styleFrom(
              foregroundColor: context.appTextSecondary,
            ),
          ),
        ),
      );
    }
    return SizedBox(height: 20 + bottomInset);
  }
}

class _ProductGridShimmer extends StatelessWidget {
  final int itemCount;

  const _ProductGridShimmer({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return MasonryGridView.count(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 14,
      crossAxisSpacing: 12,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Container(
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
              const AspectRatio(aspectRatio: 1, child: AppShimmer()),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    AppShimmer(
                      width: 90,
                      height: 12,
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                    SizedBox(height: 6),
                    AppShimmer(
                      width: 60,
                      height: 10,
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FilterButton extends StatelessWidget {
  final int activeCount;
  final VoidCallback onTap;

  const _FilterButton({required this.activeCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isActive = activeCount > 0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Container(
        height: 52,
        width: 52,
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : context.appSurface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: isActive ? AppColors.primary : context.appBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: AppIcon(
                AppIcons.filter,
                size: 20,
                color: isActive ? AppColors.onPrimary : AppColors.primary,
              ),
            ),
            if (activeCount > 0)
              PositionedDirectional(
                top: -4,
                end: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$activeCount',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
