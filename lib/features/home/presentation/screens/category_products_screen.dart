import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../add_item/data/repository/post_repository.dart';
import '../../domain/localized_labels.dart';
import '../provider/home_provider.dart';
import '../widgets/product_card.dart';

/// Every available product of one [category], in a paginated grid. Opened
/// from the "View all" button of a home screen row.
class CategoryProductsScreen extends StatelessWidget {
  final String category;
  final PostRepository? postRepository;

  const CategoryProductsScreen({
    super.key,
    required this.category,
    this.postRepository,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          HomeProvider(category: category, postRepository: postRepository),
      child: _CategoryProductsView(category: category),
    );
  }
}

class _CategoryProductsView extends StatefulWidget {
  final String category;

  const _CategoryProductsView({required this.category});

  @override
  State<_CategoryProductsView> createState() => _CategoryProductsViewState();
}

class _CategoryProductsViewState extends State<_CategoryProductsView> {
  final _scrollController = ScrollController();
  final Set<String> _animatedIds = {};

  // Start fetching the next page once the user is this close to the end.
  static const double _loadMoreThreshold = 300;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreIfNearEnd);
  }

  @override
  void dispose() {
    _scrollController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final homeProvider = context.watch<HomeProvider>();
    final products = homeProvider.products;
    final isLoading = homeProvider.isLoading;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    // When a page doesn't fill the screen there is nothing to scroll, so the
    // next page has to be requested without a scroll event.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMoreIfNearEnd());

    return Scaffold(
      appBar: AppBar(
        title: Text(categoryLabel(context.l10n, widget.category)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: homeProvider.refresh,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            if (isLoading && products.isEmpty)
              SliverPadding(
                padding: EdgeInsets.only(bottom: 20 + bottomInset),
                sliver: const SliverToBoxAdapter(child: _ProductGridShimmer()),
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
  /// How many placeholder cards; by default enough to fill the screen.
  final int? itemCount;

  const _ProductGridShimmer({super.key, this.itemCount});

  int _fillScreenCount(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // Two columns inside 20px side padding with a 12px gap; a card is a
    // square image plus ~50px of text, rows 14px apart.
    final cardHeight = (size.width - 40 - 12) / 2 + 50 + 14;
    return 2 * (size.height / cardHeight).ceil().clamp(1, 10);
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = this.itemCount ?? _fillScreenCount(context);
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
