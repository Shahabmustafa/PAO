import '../../../../core/tour/app_tour.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../chat/data/chat_unread_store.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
import '../../../feedback/presentation/widgets/feedback_dialog.dart';
import '../../../home/data/product_store.dart';
import '../../../home/domain/product.dart';
import '../../data/model/request_model.dart';
import '../../data/request_store.dart';
import '../provider/request_tile_provider.dart';
import '../../../../core/l10n/l10n.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  @override
  void initState() {
    super.initState();
    // Loads both lists when the channel joins, then keeps them live.
    RequestStore.startRealtimeSync();
    ChatUnreadStore.startRealtimeSync();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            context.l10n.requests,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Container(
                key: TourKeys.requestsTabs,
                height: 44,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: context.appSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.appBorder),
                ),
                child: TabBar(
                  indicator: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  splashBorderRadius: BorderRadius.circular(9),
                  labelColor: AppColors.onPrimary,
                  unselectedLabelColor: context.appTextSecondary,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: const [_SentTabLabel(), _ReceivedTabLabel()],
                ),
              ),
            ),
          ),
        ),
        body: const SafeArea(
          child: TabBarView(
            children: [_SentRequestsTab(), _ReceivedRequestsTab()],
          ),
        ),
      ),
    );
  }
}

/// "Sent" tab label with a badge counting unread messages across every
/// conversation with an owner appearing in [RequestStore.sent] -- tells the
/// user at a glance that new messages have arrived, and in which tab.
class _SentTabLabel extends StatelessWidget {
  const _SentTabLabel();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<RequestModel>>(
      valueListenable: RequestStore.sent,
      builder: (context, requests, _) {
        return ValueListenableBuilder<Map<String, int>>(
          valueListenable: ChatUnreadStore.unreadBySender,
          builder: (context, unread, _) {
            final otherUserIds = {for (final r in requests) r.ownerId};
            final count = otherUserIds.fold<int>(
              0,
              (sum, id) => sum + (unread[id] ?? 0),
            );
            return _TabLabel(label: context.l10n.tabSent, count: count);
          },
        );
      },
    );
  }
}

/// Same as [_SentTabLabel], for the requesters appearing in
/// [RequestStore.received].
class _ReceivedTabLabel extends StatelessWidget {
  const _ReceivedTabLabel();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<RequestModel>>(
      valueListenable: RequestStore.received,
      builder: (context, requests, _) {
        return ValueListenableBuilder<Map<String, int>>(
          valueListenable: ChatUnreadStore.unreadBySender,
          builder: (context, unread, _) {
            final otherUserIds = {for (final r in requests) r.requesterId};
            final count = otherUserIds.fold<int>(
              0,
              (sum, id) => sum + (unread[id] ?? 0),
            );
            return _TabLabel(label: context.l10n.tabReceived, count: count);
          },
        );
      },
    );
  }
}

class _TabLabel extends StatelessWidget {
  final String label;
  final int count;

  const _TabLabel({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          if (count > 0) ...[
            const SizedBox(width: 6),
            _UnreadBadge(count: count),
          ],
        ],
      ),
    );
  }
}

/// Small red pill showing how many unread messages a conversation has,
/// capped at "9+" so it never stretches the tile or tab it sits on.
class _UnreadBadge extends StatelessWidget {
  final int count;

  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      constraints: const BoxConstraints(minWidth: 18),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _SentRequestsTab extends StatefulWidget {
  const _SentRequestsTab();

  @override
  State<_SentRequestsTab> createState() => _SentRequestsTabState();
}

class _SentRequestsTabState extends State<_SentRequestsTab> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreIfNearEnd);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_loadMoreIfNearEnd);
    _scrollController.dispose();
    super.dispose();
  }

  void _loadMoreIfNearEnd() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (!position.hasContentDimensions) return;
    if (position.extentAfter < _loadMoreThreshold) RequestStore.loadMoreSent();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<RequestModel>>(
      valueListenable: RequestStore.sent,
      builder: (context, requests, _) {
        if (requests.isEmpty) {
          return _EmptyState(message: context.l10n.emptySentMessage);
        }
        return ValueListenableBuilder<List<Product>>(
          valueListenable: ProductStore.items,
          builder: (context, products, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: RequestStore.hasMoreSent,
              builder: (context, hasMore, _) {
                return ValueListenableBuilder<bool>(
                  valueListenable: RequestStore.isLoadingMoreSent,
                  builder: (context, isLoadingMore, _) {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _loadMoreIfNearEnd(),
                    );
                    final itemCount = requests.length + (hasMore ? 1 : 0);
                    return ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(20),
                      itemCount: itemCount,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        if (index >= requests.length) {
                          return _LoadMoreFooter(isLoading: isLoadingMore);
                        }
                        final request = requests[index];
                        Product? product;
                        for (final p in products) {
                          if (p.id == request.postId) {
                            product = p;
                            break;
                          }
                        }
                        return _RequestTile(
                          request: request,
                          productName: product?.name,
                          productImageUrl: product?.imageUrl,
                          otherUserId: request.ownerId,
                          isSentTab: true,
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ReceivedRequestsTab extends StatefulWidget {
  const _ReceivedRequestsTab();

  @override
  State<_ReceivedRequestsTab> createState() => _ReceivedRequestsTabState();
}

class _ReceivedRequestsTabState extends State<_ReceivedRequestsTab> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreIfNearEnd);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_loadMoreIfNearEnd);
    _scrollController.dispose();
    super.dispose();
  }

  void _loadMoreIfNearEnd() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (!position.hasContentDimensions) return;
    if (position.extentAfter < _loadMoreThreshold) {
      RequestStore.loadMoreReceived();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<RequestModel>>(
      valueListenable: RequestStore.received,
      builder: (context, requests, _) {
        if (requests.isEmpty) {
          return _EmptyState(message: context.l10n.emptyReceivedMessage);
        }
        return ValueListenableBuilder<List<Product>>(
          valueListenable: ProductStore.items,
          builder: (context, products, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: RequestStore.hasMoreReceived,
              builder: (context, hasMore, _) {
                return ValueListenableBuilder<bool>(
                  valueListenable: RequestStore.isLoadingMoreReceived,
                  builder: (context, isLoadingMore, _) {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _loadMoreIfNearEnd(),
                    );
                    final itemCount = requests.length + (hasMore ? 1 : 0);
                    return ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(20),
                      itemCount: itemCount,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        if (index >= requests.length) {
                          return _LoadMoreFooter(isLoading: isLoadingMore);
                        }
                        final request = requests[index];
                        Product? product;
                        for (final p in products) {
                          if (p.id == request.postId) {
                            product = p;
                            break;
                          }
                        }
                        return _RequestTile(
                          request: request,
                          productName: product?.name,
                          productImageUrl: product?.imageUrl,
                          otherUserId: request.requesterId,
                          isSentTab: false,
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

/// How close to the bottom (in pixels) a tab's list must be before the next
/// page is requested.
const double _loadMoreThreshold = 300;

class _LoadMoreFooter extends StatelessWidget {
  final bool isLoading;

  const _LoadMoreFooter({required this.isLoading});

  @override
  Widget build(BuildContext context) {
    if (!isLoading) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  final RequestModel request;
  final String? productName;
  final String? productImageUrl;
  final String otherUserId;
  final bool isSentTab;

  // Keyed by id *and* status: the tile's provider is created once with the
  // request it's given, so a status change (accepted / closed) has to
  // rebuild the tile or it keeps showing the old status and buttons.
  _RequestTile({
    required this.request,
    required this.productName,
    required this.productImageUrl,
    required this.otherUserId,
    required this.isSentTab,
  }) : super(key: ValueKey('${request.id}:${request.status}'));

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RequestTileProvider(
        request: request,
        otherUserId: otherUserId,
        isSentTab: isSentTab,
        productName: productName,
        productImageUrl: productImageUrl,
      ),
      child: const _RequestTileView(),
    );
  }
}

class _RequestTileView extends StatelessWidget {
  const _RequestTileView();

  void _openChat(BuildContext context, RequestTileProvider provider) {
    // Clear the badge right away -- ChatScreen also marks the messages read
    // server-side once it loads.
    ChatUnreadStore.markSeen(provider.otherUserId);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          request: provider.request,
          otherUserId: provider.otherUserId,
          productName: provider.productName ?? context.l10n.paoItem,
        ),
      ),
    );
  }

  Future<void> _onAcceptPressed(
    BuildContext context,
    RequestTileProvider provider,
  ) async {
    final success = await provider.accept();
    if (!context.mounted || success) return;
    AppSnackbar.show(
      context,
      provider.errorMessage ?? context.l10n.failedToUpdate,
      icon: Icons.error_outline,
      color: AppColors.error,
    );
  }

  Future<void> _onLeaveFeedbackPressed(
    BuildContext context,
    RequestTileProvider provider,
  ) async {
    final userId = provider.currentUserId;
    if (userId == null) return;
    final submitted = await showFeedbackDialog(
      context,
      requestId: provider.request.id,
      postId: provider.request.postId,
      fromUserId: userId,
      toUserId: provider.request.ownerId,
    );
    if (submitted == true) {
      provider.markFeedbackGiven();
    }
  }

  String _statusLabel(BuildContext context, String status) {
    final l10n = context.l10n;
    switch (status) {
      case 'accepted':
        return l10n.statusGivenToYou;
      case 'closed':
        return l10n.statusNotSelected;
      case 'declined':
        return l10n.statusDeclined;
      default:
        return l10n.statusPending;
    }
  }

  String _formattedDateTime(DateTime date) {
    return DateFormat('d MMM yyyy • h:mm a').format(date.toLocal());
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'closed':
      case 'declined':
        return AppColors.textSecondary;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RequestTileProvider>();
    final request = provider.request;

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
          InkWell(
            onTap: () => _openChat(context, provider),
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 44,
                      width: 44,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: provider.isLoadingProduct
                          ? const AppShimmer()
                          : provider.productImageUrl != null
                          ? AppNetworkImage(imageUrl: provider.productImageUrl!)
                          : const Icon(
                              Icons.inventory_2_outlined,
                              color: AppColors.primary,
                            ),
                    ),
                    // How many unread messages this user has sent -- so a
                    // new message is visible (and attributable to them,
                    // via the name shown alongside) without opening the
                    // chat.
                    ValueListenableBuilder<Map<String, int>>(
                      valueListenable: ChatUnreadStore.unreadBySender,
                      builder: (context, unread, _) {
                        final count = unread[provider.otherUserId] ?? 0;
                        if (count <= 0) return const SizedBox.shrink();
                        return PositionedDirectional(
                          top: -6,
                          end: -6,
                          child: _UnreadBadge(count: count),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      provider.isLoadingProduct
                          ? const AppShimmer(
                              width: 120,
                              height: 12,
                              borderRadius: BorderRadius.all(
                                Radius.circular(4),
                              ),
                            )
                          : Text(
                              provider.productName ?? context.l10n.paoItem,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: context.appTextPrimary,
                              ),
                            ),
                      const SizedBox(height: 4),
                      provider.isLoadingProfile
                          ? const Row(
                              children: [
                                AppShimmer(
                                  width: 16,
                                  height: 16,
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(8),
                                  ),
                                ),
                                SizedBox(width: 6),
                                AppShimmer(
                                  width: 90,
                                  height: 10,
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(4),
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                AppAvatar(
                                  radius: 8,
                                  imageUrl: provider.profile?.avatarUrl,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    provider.isSentTab
                                        ? context.l10n.requestTo(
                                            provider.profile?.fullName ??
                                                context.l10n.paoUser,
                                          )
                                        : context.l10n.requestFrom(
                                            provider.profile?.fullName ??
                                                context.l10n.paoUser,
                                          ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.appTextSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                      const SizedBox(height: 4),
                      Text(
                        _formattedDateTime(request.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: context.appTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _statusLabel(context, request.status),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _statusColor(request.status),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const AppIcon(
                      AppIcons.chevronRight,
                      mirrorInRtl: true,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!provider.isSentTab && request.isPending) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: provider.isAccepting
                    ? null
                    : () => _onAcceptPressed(context, provider),
                child: provider.isAccepting
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.l10n.acceptAndGive),
              ),
            ),
          ],
          if (provider.isSentTab &&
              request.isAccepted &&
              !provider.feedbackGiven) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _onLeaveFeedbackPressed(context, provider),
                child: Text(context.l10n.leaveFeedback),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

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
                AppIcons.checkCircle,
                size: 36,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.noRequestsYet,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: context.appTextSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
