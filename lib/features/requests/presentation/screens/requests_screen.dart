import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
import '../../../feedback/presentation/widgets/feedback_dialog.dart';
import '../../../home/data/product_store.dart';
import '../../../home/domain/product.dart';
import '../../data/model/request_model.dart';
import '../../data/request_store.dart';
import '../provider/request_tile_provider.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  @override
  void initState() {
    super.initState();
    RequestStore.startRealtimeSync();
    RequestStore.syncSentFromSupabase().catchError((_) {});
    RequestStore.syncReceivedFromSupabase().catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Requests',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Container(
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
                  tabs: const [
                    Tab(text: 'Sent'),
                    Tab(text: 'Received'),
                  ],
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

class _SentRequestsTab extends StatelessWidget {
  const _SentRequestsTab();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<RequestModel>>(
      valueListenable: RequestStore.sent,
      builder: (context, requests, _) {
        if (requests.isEmpty) {
          return const _EmptyState(
            message: 'Tap "Give Me" on a product to request it',
          );
        }
        return ValueListenableBuilder<List<Product>>(
          valueListenable: ProductStore.items,
          builder: (context, products, _) {
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
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
  }
}

class _ReceivedRequestsTab extends StatelessWidget {
  const _ReceivedRequestsTab();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<RequestModel>>(
      valueListenable: RequestStore.received,
      builder: (context, requests, _) {
        if (requests.isEmpty) {
          return const _EmptyState(
            message: 'Requests for the items you post will show up here',
          );
        }
        return ValueListenableBuilder<List<Product>>(
          valueListenable: ProductStore.items,
          builder: (context, products, _) {
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
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
  }
}

class _RequestTile extends StatelessWidget {
  final RequestModel request;
  final String? productName;
  final String? productImageUrl;
  final String otherUserId;
  final bool isSentTab;

  const _RequestTile({
    required this.request,
    required this.productName,
    required this.productImageUrl,
    required this.otherUserId,
    required this.isSentTab,
  });

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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          request: provider.request,
          otherUserId: provider.otherUserId,
          productName: provider.productName ?? 'PAO item',
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
      provider.errorMessage ?? 'Failed to update. Please try again.',
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

  String _statusLabel(String status) {
    switch (status) {
      case 'accepted':
        return 'Given to you';
      case 'closed':
        return 'Not selected';
      case 'declined':
        return 'Declined';
      default:
        return 'Pending';
    }
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
                              provider.productName ?? 'PAO item',
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
                                        ? 'to ${provider.profile?.fullName ?? 'PAO User'}'
                                        : 'from ${provider.profile?.fullName ?? 'PAO User'}',
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
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _statusLabel(request.status),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _statusColor(request.status),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const AppIcon(
                      AppIcons.chevronRight,
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
                    : const Text('Accept & Give'),
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
                child: const Text('Leave Feedback'),
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
            'No requests yet',
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
