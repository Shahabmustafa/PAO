import '../../../../core/tour/app_tour.dart';
import 'package:flutter/material.dart';
import '../../../../core/update/update_checker.dart';
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
import '../../../wishlist/presentation/screens/wishlist_screen.dart';
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

  static const double _greetingHeight = 92;
  static const double _searchBarHeight = 68;
  bool _collapsed = false;
  final Set<String> _animatedIds = {};

  // Start fetching the next page once the user is this close to the end.
  static const double _loadMoreThreshold = 300;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreIfNearEnd);
    UpdateChecker.check();
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
    final collapsed = _scrollController.offset > _greetingHeight - 8;
    if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
    final position = _scrollController.position;
    if (!position.hasContentDimensions) return;
    final provider = context.read<HomeProvider>();
    // After a failure the footer's retry button decides, not the scroll.
    if (provider.loadMoreFailed) return;
    if (position.extentAfter < _loadMoreThreshold) provider.loadMore();
  }

  Widget _buildProfileAvatar() {
    final currentUser = _authRepository.currentUser;
    return GestureDetector(
      onTap: currentUser == null
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UserProfileScreen(userId: currentUser.id),
              ),
            ),
      child: AppAvatar(
        radius: 20,
        imageUrl: currentUser?.avatarUrl,
        ring: true,
      ),
    );
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
              // Greeting collapses away on scroll; the search row stays
              // pinned, gaining the profile avatar while collapsed.
              SliverAppBar(
                pinned: true,
                toolbarHeight: 0,
                expandedHeight: _greetingHeight + _searchBarHeight,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                surfaceTintColor: Colors.transparent,
                scrolledUnderElevation: 0,
                automaticallyImplyLeading: false,
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.pin,
                  background: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
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
                                  // Shrink-wrap: the header now has a bounded
                                  // height, so a max-sized Column would stretch
                                  // the whole Row and push the avatar down.
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
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(_searchBarHeight),
                  child: Container(
                    height: _searchBarHeight,
                    color: Theme.of(context).scaffoldBackgroundColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          child: _collapsed
                              ? Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    start: 4,
                                    end: 10,
                                  ),
                                  child: _buildProfileAvatar(),
                                )
                              : const SizedBox.shrink(),
                        ),
                        Expanded(
                          child: Container(
                            key: TourKeys.homeSearch,
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
                          key: TourKeys.homeFilter,
                          activeCount: activeFilterCount,
                          onTap: _onFilterTapped,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: ValueListenableBuilder<bool>(
                  valueListenable: UpdateChecker.updateAvailable,
                  builder: (context, available, _) => AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: available
                          ? const Padding(
                              key: ValueKey('update'),
                              padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                              child: _UpdateBanner(),
                            )
                          : const SizedBox.shrink(key: ValueKey('none')),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
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
                      return _FadeSlideIn(
                        key: ValueKey(product.id),
                        // Only the first appearance animates; cards that
                        // scroll back into view just show.
                        animate: _animatedIds.add(product.id),
                        delay: Duration(milliseconds: 60 * (index % 8)),
                        child: ProductCard(product: product),
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

  const _FilterButton({
    super.key,
    required this.activeCount,
    required this.onTap,
  });

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

/// Tappable "Update your App" pill shown while a newer Play Store version
/// exists.
class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: UpdateChecker.startUpdate,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.system_update_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.updateYourApp,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fades and slides its child up a little when it first appears, after an
/// optional [delay] so a row of cards ripples in.
class _FadeSlideIn extends StatefulWidget {
  const _FadeSlideIn({
    super.key,
    required this.child,
    required this.animate,
    this.delay = Duration.zero,
  });

  final Widget child;
  final bool animate;
  final Duration delay;

  @override
  State<_FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<_FadeSlideIn>
    with SingleTickerProviderStateMixin {
  static const _fadeMs = 420;

  // The delay is part of the timeline (an Interval), not a Timer, so nothing
  // is left pending if the card is disposed early.
  late final int _totalMs = _fadeMs + widget.delay.inMilliseconds;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _totalMs),
    value: widget.animate ? 0 : 1,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      widget.delay.inMilliseconds / _totalMs,
      1,
      curve: Curves.easeOutCubic,
    ),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - _curve.value)),
          child: child,
        ),
      ),
    );
  }
}
