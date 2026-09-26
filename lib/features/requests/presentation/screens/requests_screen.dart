import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../chat/data/chat_activity_store.dart';
import '../../../chat/data/chat_unread_store.dart';
import '../../../chat/presentation/widgets/chat_media_widgets.dart'
    show messagePreview;
import '../../../chat/presentation/screens/chat_screen.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.navChats,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: const SafeArea(child: _ChatsList()),
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

/// Every conversation -- requests the user sent and received -- newest
/// first. Accepting and giving happens inside each chat.
class _ChatsList extends StatefulWidget {
  const _ChatsList();

  @override
  State<_ChatsList> createState() => _ChatsListState();
}

class _ChatsListState extends State<_ChatsList> {
  final _scrollController = ScrollController();

  late final Listenable _sources = Listenable.merge([
    RequestStore.sent,
    RequestStore.received,
    ProductStore.items,
    ChatActivityStore.lastActivity,
    RequestStore.hasMoreSent,
    RequestStore.hasMoreReceived,
    RequestStore.isLoadingMoreSent,
    RequestStore.isLoadingMoreReceived,
  ]);

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
      RequestStore.loadMoreSent();
      RequestStore.loadMoreReceived();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _sources,
      builder: (context, _) {
        final entries = [
          for (final r in RequestStore.sent.value) (request: r, isSent: true),
          for (final r in RequestStore.received.value)
            (request: r, isSent: false),
        ];
        // Most recent conversation first: the latest message with that
        // person, or the request itself when nobody has written yet.
        final activity = ChatActivityStore.lastActivity.value;
        DateTime sortKey(({RequestModel request, bool isSent}) e) {
          final other = e.isSent ? e.request.ownerId : e.request.requesterId;
          final last = activity[other];
          return last != null && last.isAfter(e.request.createdAt)
              ? last
              : e.request.createdAt;
        }

        entries.sort((a, b) {
          final byActivity = sortKey(b).compareTo(sortKey(a));
          return byActivity != 0
              ? byActivity
              : b.request.createdAt.compareTo(a.request.createdAt);
        });
        // One chat per person: their most recent request.
        final seen = <String>{};
        entries.retainWhere((e) {
          final other = e.isSent ? e.request.ownerId : e.request.requesterId;
          return seen.add(other);
        });
        if (entries.isEmpty) {
          return _EmptyState(message: context.l10n.emptyChatsMessage);
        }
        final products = ProductStore.items.value;
        final hasMore =
            RequestStore.hasMoreSent.value ||
            RequestStore.hasMoreReceived.value;
        final isLoadingMore =
            RequestStore.isLoadingMoreSent.value ||
            RequestStore.isLoadingMoreReceived.value;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _loadMoreIfNearEnd(),
        );
        return ListView.separated(
          controller: _scrollController,
          padding: const EdgeInsets.all(20),
          itemCount: entries.length + (hasMore ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index >= entries.length) {
              return _LoadMoreFooter(isLoading: isLoadingMore);
            }
            final (:request, :isSent) = entries[index];
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
              otherUserId: isSent ? request.ownerId : request.requesterId,
              isSentTab: isSent,
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

  Future<void> _openChat(
    BuildContext context,
    RequestTileProvider provider,
  ) async {
    // Clear the badge right away -- ChatScreen also marks the messages read
    // server-side once it loads.
    ChatUnreadStore.markSeen(provider.otherUserId);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          request: provider.request,
          otherUserId: provider.otherUserId,
          productName: provider.productName ?? context.l10n.paoItem,
        ),
      ),
    );
    // Messages sent from inside the chat change the preview.
    provider.loadLastMessage();
  }

  static final Listenable _badgeSources = Listenable.merge([
    ChatUnreadStore.unreadBySender,
    RequestStore.received,
  ]);

  /// Unread messages from [otherUserId] plus their requests still waiting
  /// for an answer -- what the Chats tab badge adds up.
  int _badgeCount(String otherUserId) =>
      (ChatUnreadStore.unreadBySender.value[otherUserId] ?? 0) +
      RequestStore.received.value
          .where((r) => r.requesterId == otherUserId && r.isPending)
          .length;

  String _timeLabel(BuildContext context, DateTime dateTime) {
    final local = dateTime.toLocal();
    final now = DateTime.now();
    final days = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(local.year, local.month, local.day)).inDays;
    if (days == 0) return DateFormat.Hm().format(local);
    if (days == 1) return context.l10n.yesterday;
    return DateFormat.MMMd(
      Localizations.localeOf(context).toString(),
    ).format(local);
  }

  String? _previewText(BuildContext context, RequestTileProvider provider) {
    final message = provider.lastMessage;
    if (message == null) return null;
    final text = messagePreview(context, message);
    return message.senderId == provider.currentUserId
        ? '${context.l10n.you}: $text'
        : text;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RequestTileProvider>();

    return InkWell(
      onTap: () => _openChat(context, provider),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.appBorder),
        ),
        child: Row(
          children: [
            provider.isLoadingProfile
                ? const AppShimmer(
                    width: 48,
                    height: 48,
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                  )
                : AppAvatar(radius: 24, imageUrl: provider.profile?.avatarUrl),
            const SizedBox(width: 14),
            Expanded(
              child: ListenableBuilder(
                listenable: _badgeSources,
                builder: (context, _) {
                  final count = _badgeCount(provider.otherUserId);
                  final preview = _previewText(context, provider);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      provider.isLoadingProfile
                          ? const AppShimmer(
                              width: 120,
                              height: 14,
                              borderRadius: BorderRadius.all(
                                Radius.circular(4),
                              ),
                            )
                          : Text(
                              provider.profile?.fullName ??
                                  context.l10n.paoUser,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: context.appTextPrimary,
                              ),
                            ),
                      if (preview != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: count > 0
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: count > 0
                                ? context.appTextPrimary
                                : context.appTextSecondary,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            ListenableBuilder(
              listenable: _badgeSources,
              builder: (context, _) {
                final count = _badgeCount(provider.otherUserId);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _timeLabel(
                        context,
                        provider.lastMessage?.createdAt ??
                            provider.request.createdAt,
                      ),
                      style: TextStyle(
                        fontSize: 11,
                        color: count > 0
                            ? AppColors.primary
                            : context.appTextSecondary,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(height: 6),
                      _UnreadBadge(count: count),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
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
              child: AppIcon(AppIcons.chat, size: 36, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.noChatsYet,
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
