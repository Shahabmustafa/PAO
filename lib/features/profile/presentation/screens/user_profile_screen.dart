import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../add_item/data/model/post_model.dart';
import '../../../add_item/data/repository/post_repository.dart';
import '../../../feedback/data/model/feedback_model.dart';
import '../../../feedback/data/repository/feedback_repository.dart';
import '../../../home/data/product_store.dart';
import '../../../home/domain/product.dart';
import '../../../home/presentation/widgets/product_card.dart';
import '../../../settings/data/model/profile_model.dart';
import '../../../settings/data/repository/profile_repository.dart';
import '../../../../core/l10n/l10n.dart';

/// Profile of a user: name/photo, how many items they've donated, their
/// overall feedback rating, and tabs for the items they've posted, the
/// items they've given away, and the feedback they've received.
class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _profileRepository = ProfileRepository();
  final _postRepository = PostRepository();
  final _feedbackRepository = FeedbackRepository();

  bool _isLoading = true;
  ProfileModel? _profile;
  int _donatedCount = 0;
  List<Product> _posted = const [];
  List<Product> _givenAway = const [];
  List<FeedbackModel> _feedback = const [];
  Map<String, ProfileModel> _reviewerProfiles = const {};

  @override
  void initState() {
    super.initState();
    _load();
    _storeSignature = _signatureOfThisUsersPosts();
    ProductStore.items.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    ProductStore.items.removeListener(_onStoreChanged);
    super.dispose();
  }

  String _storeSignature = '';

  // The store changes for every post anyone creates, edits or deletes
  // (realtime). Only a change to this user's own posts — e.g. edited,
  // deleted or given away from a product screen opened on top of this one —
  // is worth reloading the tabs for.
  String _signatureOfThisUsersPosts() {
    final mine = ProductStore.items.value.where(
      (p) => p.userId == widget.userId,
    );
    return [
      for (final p in mine)
        '${p.id}|${p.isGiven}|${p.name}|${p.description}|${p.category}|'
            '${p.condition}|${p.address}|${p.imageUrls.join(',')}',
    ].join('\n');
  }

  void _onStoreChanged() {
    final signature = _signatureOfThisUsersPosts();
    if (signature == _storeSignature) return;
    _storeSignature = signature;
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _profileRepository.fetchPublicProfile(widget.userId),
        _postRepository.fetchDonatedCount(widget.userId),
        _feedbackRepository.fetchForUser(widget.userId),
        _postRepository.fetchPostsByUser(widget.userId),
      ]);
      final profile = results[0] as ProfileModel?;
      final donatedCount = results[1] as int;
      final feedback = results[2] as List<FeedbackModel>;
      final products = (results[3] as List<PostModel>)
          .map(ProductStore.productFromPost)
          .toList();

      final reviewerIds = feedback.map((f) => f.fromUserId).toSet().toList();
      final reviewerProfiles = await _profileRepository.fetchPublicProfiles(
        reviewerIds,
      );

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _donatedCount = donatedCount;
        _posted = products.where((p) => !p.isGiven).toList();
        _givenAway = products.where((p) => p.isGiven).toList();
        _feedback = feedback;
        _reviewerProfiles = reviewerProfiles;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  double get _averageRating {
    if (_feedback.isEmpty) return 0;
    final total = _feedback.fold<int>(0, (sum, f) => sum + f.rating);
    return total / _feedback.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.profile,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const _UserProfileShimmer()
            : DefaultTabController(
                length: 3,
                child: NestedScrollView(
                  headerSliverBuilder: (context, _) => [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            AppAvatar(
                              radius: 44,
                              imageUrl: _profile?.avatarUrl,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _profile?.fullName ?? context.l10n.paoUser,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: context.appTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: _StatCard(
                                    value: '$_donatedCount',
                                    label: context.l10n.donated,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _StatCard(
                                    value: _feedback.isEmpty
                                        ? '—'
                                        : _averageRating.toStringAsFixed(1),
                                    label: _feedback.isEmpty
                                        ? context.l10n.noRatings
                                        : context.l10n.reviewCount(
                                            _feedback.length,
                                          ),
                                    icon: _feedback.isEmpty
                                        ? null
                                        : Icons.star_rounded,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _TabBarDelegate(
                        background: context.appBackground,
                        tabBar: TabBar(
                          indicatorColor: AppColors.primary,
                          labelColor: context.appTextPrimary,
                          unselectedLabelColor: context.appTextSecondary,
                          dividerColor: context.appBorder,
                          labelStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          tabs: [
                            Tab(text: context.l10n.tabPosts),
                            Tab(text: context.l10n.tabGivenAway),
                            Tab(text: context.l10n.feedback),
                          ],
                        ),
                      ),
                    ),
                  ],
                  body: TabBarView(
                    children: [
                      _ProductsTab(
                        products: _posted,
                        emptyText: context.l10n.noPostsYet,
                      ),
                      _ProductsTab(
                        products: _givenAway,
                        emptyText: context.l10n.nothingGivenAwayYet,
                      ),
                      _FeedbackTab(
                        feedback: _feedback,
                        reviewerProfiles: _reviewerProfiles,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color background;

  const _TabBarDelegate({required this.tabBar, required this.background});

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: background, child: tabBar);
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) {
    return oldDelegate.tabBar != tabBar || oldDelegate.background != background;
  }
}

class _ProductsTab extends StatelessWidget {
  final List<Product> products;
  final String emptyText;

  const _ProductsTab({required this.products, required this.emptyText});

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Center(
        child: Text(
          emptyText,
          style: TextStyle(color: context.appTextSecondary),
        ),
      );
    }
    return MasonryGridView.count(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      crossAxisCount: 2,
      mainAxisSpacing: 14,
      crossAxisSpacing: 12,
      itemCount: products.length,
      itemBuilder: (context, index) =>
          ProductCard(product: products[index], showWishlistButton: false),
    );
  }
}

class _FeedbackTab extends StatelessWidget {
  final List<FeedbackModel> feedback;
  final Map<String, ProfileModel> reviewerProfiles;

  const _FeedbackTab({required this.feedback, required this.reviewerProfiles});

  @override
  Widget build(BuildContext context) {
    if (feedback.isEmpty) {
      return Center(
        child: Text(
          context.l10n.noFeedbackYet,
          style: TextStyle(color: context.appTextSecondary),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      itemCount: feedback.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _FeedbackTile(
        feedback: feedback[index],
        reviewer: reviewerProfiles[feedback[index].fromUserId],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData? icon;

  const _StatCard({required this.value, required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: const Color(0xFFFFB020)),
                const SizedBox(width: 4),
              ],
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.appTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: context.appTextSecondary),
          ),
        ],
      ),
    );
  }
}

class _FeedbackTile extends StatelessWidget {
  final FeedbackModel feedback;
  final ProfileModel? reviewer;

  const _FeedbackTile({required this.feedback, required this.reviewer});

  String _timeAgo(BuildContext context, DateTime date) {
    final l10n = context.l10n;
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 30) return l10n.timeMonthsAgo((diff.inDays / 30).floor());
    if (diff.inDays >= 1) return l10n.timeDaysAgo(diff.inDays);
    if (diff.inHours >= 1) return l10n.timeHoursAgo(diff.inHours);
    if (diff.inMinutes >= 1) return l10n.timeMinutesAgo(diff.inMinutes);
    return l10n.timeJustNow;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(radius: 16, imageUrl: reviewer?.avatarUrl),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  reviewer?.fullName ?? context.l10n.paoUser,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                ),
              ),
              Text(
                _timeAgo(context, feedback.createdAt),
                style: TextStyle(fontSize: 11, color: context.appTextSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (index) {
              return Icon(
                index < feedback.rating
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                size: 16,
                color: const Color(0xFFFFB020),
              );
            }),
          ),
          if (feedback.comment != null && feedback.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              feedback.comment!,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: context.appTextSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UserProfileShimmer extends StatelessWidget {
  const _UserProfileShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Center(
          child: Column(
            children: [
              AppShimmer(
                width: 88,
                height: 88,
                borderRadius: BorderRadius.all(Radius.circular(44)),
              ),
              SizedBox(height: 12),
              AppShimmer(
                width: 140,
                height: 18,
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Row(
          children: [
            Expanded(
              child: AppShimmer(
                height: 70,
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: AppShimmer(
                height: 70,
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const AppShimmer(
          width: 90,
          height: 14,
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          const AppShimmer(
            height: 80,
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
        ],
      ],
    );
  }
}
