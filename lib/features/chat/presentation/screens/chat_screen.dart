import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../feedback/presentation/widgets/feedback_dialog.dart';
import '../../../requests/data/model/request_model.dart';
import '../provider/chat_provider.dart';

class ChatScreen extends StatelessWidget {
  final RequestModel request;
  final String otherUserId;
  final String productName;

  const ChatScreen({
    super.key,
    required this.request,
    required this.otherUserId,
    required this.productName,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatProvider(request: request, otherUserId: otherUserId),
      child: _ChatView(productName: productName),
    );
  }
}

class _ChatView extends StatefulWidget {
  final String productName;

  const _ChatView({required this.productName});

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _onAcceptPressed(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Give this item'),
        content: Text(
          'Give "${widget.productName}" to this person? Other requests for it will be closed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Yes, Give'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    final provider = context.read<ChatProvider>();
    final success = await provider.acceptRequest();
    if (!context.mounted) return;

    if (success) {
      AppSnackbar.show(context, 'Item marked as given');
    } else {
      AppSnackbar.show(
        context,
        provider.errorMessage ?? 'Failed to update. Please try again.',
        icon: Icons.error_outline,
        color: AppColors.error,
      );
    }
  }

  Future<void> _onLeaveFeedbackPressed(BuildContext context) async {
    final provider = context.read<ChatProvider>();
    final userId = provider.currentUserId;
    if (userId == null) return;
    final submitted = await showFeedbackDialog(
      context,
      requestId: provider.request.id,
      postId: provider.request.postId,
      fromUserId: userId,
      toUserId: provider.request.ownerId,
    );
    if (submitted == true && context.mounted) {
      provider.markFeedbackGiven();
      AppSnackbar.show(context, 'Thanks for your feedback!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final currentUserId = provider.currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            provider.isLoadingProfile
                ? const AppShimmer(
                    width: 32,
                    height: 32,
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  )
                : AppAvatar(radius: 16, imageUrl: provider.otherProfile?.avatarUrl),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  provider.isLoadingProfile
                      ? const AppShimmer(
                          width: 100,
                          height: 12,
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                        )
                      : Text(
                          provider.otherProfile?.fullName ?? 'PAO User',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15),
                        ),
                  const SizedBox(height: 2),
                  Text(
                    widget.productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.normal,
                      color: context.appTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (provider.isOwner && provider.request.isPending)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: AppColors.primary.withValues(alpha: 0.08),
                child: PrimaryButton(
                  label: 'Accept & Give This Item',
                  isLoading: provider.isAccepting,
                  onPressed: () => _onAcceptPressed(context),
                ),
              ),
            if (provider.isRequester &&
                provider.request.isAccepted &&
                !provider.feedbackGiven)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.green.withValues(alpha: 0.08),
                child: PrimaryButton(
                  label: 'You received this — Leave Feedback',
                  onPressed: () => _onLeaveFeedbackPressed(context),
                ),
              ),
            Expanded(
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : provider.messages.isEmpty
                      ? Center(
                          child: Text(
                            'Say hello 👋',
                            style: TextStyle(color: context.appTextSecondary),
                          ),
                        )
                      : ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.all(16),
                          itemCount: provider.messages.length,
                          itemBuilder: (context, index) {
                            final message = provider
                                .messages[provider.messages.length - 1 - index];
                            final isMine = message.senderId == currentUserId;
                            return Align(
                              alignment: isMine
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.75,
                                ),
                                decoration: BoxDecoration(
                                  color: isMine
                                      ? AppColors.primary
                                      : context.appSurface,
                                  border: isMine
                                      ? null
                                      : Border.all(color: context.appBorder),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft:
                                        Radius.circular(isMine ? 16 : 4),
                                    bottomRight:
                                        Radius.circular(isMine ? 4 : 16),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      message.body,
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        height: 1.3,
                                        color: isMine
                                            ? Colors.white
                                            : context.appTextPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatTime(message.createdAt),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isMine
                                            ? Colors.white.withValues(alpha: 0.7)
                                            : context.appTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                        ),
                        onSubmitted: (value) {
                          context.read<ChatProvider>().sendMessage(value);
                          _messageController.clear();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send, color: AppColors.primary),
                      onPressed: () {
                        context.read<ChatProvider>().sendMessage(
                              _messageController.text,
                            );
                        _messageController.clear();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
