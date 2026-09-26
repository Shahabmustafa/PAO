import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:image_picker/image_picker.dart';
import '../../../../core/media/media_compressor.dart';
import 'package:video_player/video_player.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../feedback/presentation/widgets/feedback_dialog.dart';
import '../../../auth/data/repository/auth_repository.dart';
import '../../../add_item/data/repository/post_repository.dart';
import '../../../home/data/product_store.dart';
import '../../../home/domain/product.dart';
import '../../../home/presentation/screens/product_detail_screen.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../requests/data/model/request_model.dart';
import '../../../requests/data/request_store.dart';
import '../../data/model/message_model.dart';
import '../provider/chat_provider.dart';
import '../widgets/chat_composer_widgets.dart';
import '../widgets/chat_media_widgets.dart';
import '../widgets/report_user_sheet.dart';
import '../widgets/voice_recorder.dart';
import '../../../../core/l10n/l10n.dart';

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

/// Whole calendar days between [date] and today (0 = today, 1 = yesterday).
int _daysAgo(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  return today.difference(day).inDays;
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// WhatsApp-style chat palette, separate from the app's brand colours so
/// bubbles stay readable against the tinted chat background.
class _ChatColors {
  const _ChatColors._(this.isDark);

  factory _ChatColors.of(BuildContext context) =>
      _ChatColors._(context.isDarkMode);

  final bool isDark;

  Color get background =>
      isDark ? const Color(0xFF0B141A) : const Color(0xFFEFEAE2);
  // My own bubbles use the brand lime in both themes, with black text.
  Color get outgoing => AppColors.primary;
  Color get outgoingText => AppColors.onPrimary;
  Color get incoming => isDark ? const Color(0xFF202C33) : Colors.white;
  Color get text => isDark ? const Color(0xFFE9EDEF) : const Color(0xFF111B21);
  Color get meta => isDark ? const Color(0xFF8696A0) : const Color(0xFF667781);
  Color get outgoingMeta => AppColors.onPrimary.withValues(alpha: 0.55);
  Color get chip => isDark ? const Color(0xFF182229) : Colors.white;
  Color get chipText =>
      isDark ? const Color(0xFF8696A0) : const Color(0xFF54656F);
  Color get composer => isDark ? const Color(0xFF202C33) : Colors.white;
  // Blue read ticks, dark enough to show up on the lime bubble.
  static const readTick = AppColors.primaryDark;
}

class _ChatView extends StatefulWidget {
  final String productName;

  const _ChatView({required this.productName});

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final _messageController = TextEditingController();
  final _inputFocus = FocusNode();
  MessageModel? _editingMessage;
  MessageModel? _replyingTo;

  static const _reactionEmojis = ['👍', '👎', '❤️', '😂', '😮', '😢'];

  final _voice = VoiceRecorderController();
  final _picker = ImagePicker();
  final _scroll = ScrollController();
  static const _maxMediaBytes = 50 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadOlder);
  }

  // The list is reversed, so its "end" is the oldest loaded message.
  void _maybeLoadOlder() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      context.read<ChatProvider>().loadOlder();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _messageController.dispose();
    _inputFocus.dispose();
    _voice.dispose();
    super.dispose();
  }

  Future<void> _attach(BuildContext context) async {
    final choice = await showAttachmentSheet(context);
    if (choice == null || !context.mounted) return;
    final provider = context.read<ChatProvider>();
    try {
      final files = <XFile>[];
      var type = MessageMediaType.image;
      switch (choice) {
        case AttachmentChoice.photoCamera:
          final file = await _picker.pickImage(
            source: ImageSource.camera,
            imageQuality: 80,
            maxWidth: 1920,
          );
          if (file != null) files.add(file);
        case AttachmentChoice.photoGallery:
          files.addAll(
            await _picker.pickMultiImage(
              imageQuality: 80,
              maxWidth: 1920,
              limit: 10,
            ),
          );
        case AttachmentChoice.videoCamera:
          type = MessageMediaType.video;
          final file = await _picker.pickVideo(
            source: ImageSource.camera,
            maxDuration: const Duration(minutes: 3),
          );
          if (file != null) files.add(file);
        case AttachmentChoice.videoGallery:
          type = MessageMediaType.video;
          final file = await _picker.pickVideo(source: ImageSource.gallery);
          if (file != null) files.add(file);
      }
      for (final xfile in files) {
        if (!context.mounted) return;
        var file = File(xfile.path);
        file = type == MessageMediaType.video
            ? await MediaCompressor.compressVideoFile(file)
            : await MediaCompressor.compressImageFile(file);
        if (!context.mounted) return;
        final durationMs = type == MessageMediaType.video
            ? await _videoDurationMs(file)
            : null;
        if (!context.mounted) return;
        await _sendMedia(context, provider, file, type, durationMs: durationMs);
      }
    } catch (_) {
      // Camera / gallery permission denied or the picker failed.
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        context.l10n.failedToSendMessage,
        icon: Icons.error_outline,
        color: AppColors.error,
      );
    }
  }

  Future<int?> _videoDurationMs(File file) async {
    final controller = VideoPlayerController.file(file);
    try {
      await controller.initialize();
      return controller.value.duration.inMilliseconds;
    } catch (_) {
      return null;
    } finally {
      await controller.dispose();
    }
  }

  Future<void> _sendMedia(
    BuildContext context,
    ChatProvider provider,
    File file,
    MessageMediaType type, {
    int? durationMs,
  }) async {
    if (await file.length() > _maxMediaBytes) {
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        context.l10n.mediaTooLarge,
        icon: Icons.error_outline,
        color: AppColors.error,
      );
      return;
    }
    final sent = await provider.sendMedia(file, type, durationMs: durationMs);
    if (type == MessageMediaType.audio) {
      // Voice notes are temp files -- nothing else needs them once sent.
      try {
        await file.delete();
      } catch (_) {}
    }
    if (!sent && context.mounted) {
      AppSnackbar.show(
        context,
        provider.errorMessage ?? context.l10n.failedToSendMessage,
        icon: Icons.error_outline,
        color: AppColors.error,
      );
    }
  }

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// "Online" when the other participant's last heartbeat (see
  /// PresenceHeartbeat) is recent, otherwise "last seen today / yesterday /
  /// a date at HH:mm". Null when that account has never sent a heartbeat.
  String? _statusLabel(BuildContext context, DateTime? lastSeenAt) {
    if (lastSeenAt == null) return null;
    final local = lastSeenAt.toLocal();
    if (DateTime.now().difference(local) < const Duration(seconds: 90)) {
      return context.l10n.online;
    }
    final time = _formatTime(local);
    return switch (_daysAgo(local)) {
      0 => context.l10n.lastSeenToday(time),
      1 => context.l10n.lastSeenYesterday(time),
      _ => context.l10n.lastSeenOn(
        DateFormat.MMMd(
          Localizations.localeOf(context).toString(),
        ).format(local),
        time,
      ),
    };
  }

  void _startEditing(MessageModel message) {
    setState(() {
      _replyingTo = null;
      _editingMessage = message;
      _messageController.text = message.body;
      _messageController.selection = TextSelection.collapsed(
        offset: _messageController.text.length,
      );
    });
  }

  void _startReplying(MessageModel message) {
    setState(() {
      _editingMessage = null;
      _replyingTo = message;
    });
    // Like WhatsApp: the keyboard opens ready to type the reply.
    _inputFocus.requestFocus();
  }

  Future<void> _react(
    BuildContext context,
    MessageModel message,
    String emoji,
  ) async {
    final ok = await context.read<ChatProvider>().react(message, emoji);
    if (ok || !context.mounted) return;
    AppSnackbar.show(
      context,
      context.l10n.failedToUpdate,
      icon: Icons.error_outline,
      color: AppColors.error,
    );
  }

  String _senderLabel(BuildContext context, MessageModel message) {
    final provider = context.read<ChatProvider>();
    return message.senderId == provider.currentUserId
        ? context.l10n.you
        : (provider.otherProfile?.fullName ?? '');
  }

  void _cancelEditing() {
    setState(() {
      _editingMessage = null;
      _messageController.clear();
    });
  }

  Future<void> _submit(BuildContext context) async {
    final text = _messageController.text;
    if (text.trim().isEmpty) return;
    final provider = context.read<ChatProvider>();
    final editing = _editingMessage;
    if (editing != null) {
      setState(() => _editingMessage = null);
      _messageController.clear();
      final success = await provider.editMessage(editing, text);
      if (!success && context.mounted) {
        AppSnackbar.show(
          context,
          provider.errorMessage ?? context.l10n.failedToEditMessage,
          icon: Icons.error_outline,
          color: AppColors.error,
        );
      }
    } else {
      _messageController.clear();
      final replyTo = _replyingTo;
      setState(() => _replyingTo = null);
      await provider.sendMessage(text, replyToId: replyTo?.id);
    }
  }

  Future<void> _showMessageActions(
    BuildContext context,
    MessageModel message, {
    required bool isMine,
  }) async {
    final action = await showModalBottomSheet<VoidCallback>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final emoji in _reactionEmojis)
                    InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.pop(
                        sheetContext,
                        () => _react(context, message, emoji),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.reply, color: AppColors.primary),
              title: Text(sheetContext.l10n.reply),
              onTap: () =>
                  Navigator.pop(sheetContext, () => _startReplying(message)),
            ),
            if (isMine && !message.hasMedia)
              ListTile(
                leading: AppIcon(AppIcons.edit, color: AppColors.primary),
                title: Text(sheetContext.l10n.edit),
                onTap: () =>
                    Navigator.pop(sheetContext, () => _startEditing(message)),
              ),
            ListTile(
              leading: const AppIcon(AppIcons.delete, color: AppColors.error),
              title: Text(
                sheetContext.l10n.deleteForMe,
                style: const TextStyle(color: AppColors.error),
              ),
              onTap: () => Navigator.pop(
                sheetContext,
                () => _onDeleteForMePressed(context, message),
              ),
            ),
            if (isMine)
              ListTile(
                leading: const AppIcon(AppIcons.delete, color: AppColors.error),
                title: Text(
                  sheetContext.l10n.deleteForEveryone,
                  style: const TextStyle(color: AppColors.error),
                ),
                onTap: () => Navigator.pop(
                  sheetContext,
                  () => _onDeleteMessagePressed(context, message),
                ),
              ),
          ],
        ),
      ),
    );
    action?.call();
  }

  // Request ids whose accept is in flight (other than the chat's own one,
  // which the provider tracks), and product names resolved for older
  // requests in this conversation.
  final Set<String> _accepting = {};
  final Map<String, Product> _products = {};
  final Set<String> _lookingUp = {};

  /// The listing a request is about: from the feed store, or fetched once.
  Product? _productFor(RequestModel request) {
    for (final p in ProductStore.items.value) {
      if (p.id == request.postId) return p;
    }
    final known = _products[request.postId];
    if (known != null) return known;
    if (_lookingUp.add(request.postId)) {
      PostRepository()
          .fetchPostById(request.postId)
          .then((post) {
            if (!mounted || post == null) return;
            setState(
              () => _products[request.postId] = ProductStore.productFromPost(
                post,
              ),
            );
          })
          .catchError((_) {});
    }
    return null;
  }

  String _productNameFor(RequestModel request) {
    if (request.postId == context.read<ChatProvider>().request.postId) {
      return widget.productName;
    }
    return _productFor(request)?.name ?? context.l10n.paoItem;
  }

  Future<void> _onRejectPressed(
    BuildContext context,
    RequestModel request,
  ) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: context.l10n.rejectRequestTitle,
      message: context.l10n.rejectRequestConfirm(_productNameFor(request)),
      confirmText: context.l10n.rejectRequest,
      cancelText: context.l10n.cancel,
      isDestructive: true,
      icon: AppIcons.close,
    );
    if (!confirmed || !context.mounted) return;

    setState(() => _accepting.add(request.id));
    var success = true;
    try {
      // The chat's provider follows the store, so the card updates itself.
      await RequestStore.decline(request);
    } catch (_) {
      success = false;
    } finally {
      if (mounted) setState(() => _accepting.remove(request.id));
    }
    if (!context.mounted) return;
    if (success) {
      AppSnackbar.show(context, context.l10n.requestRejected);
    } else {
      AppSnackbar.show(
        context,
        context.l10n.failedToUpdate,
        icon: Icons.error_outline,
        color: AppColors.error,
      );
    }
  }

  /// Every request between the two participants (this chat's own one
  /// always included), oldest first, with live statuses from the stores.
  List<RequestModel> _pairRequests(ChatProvider provider) {
    final me = provider.currentUserId;
    final other = provider.otherUserId;
    final byId = <String, RequestModel>{};
    for (final r in [
      ...RequestStore.sent.value,
      ...RequestStore.received.value,
    ]) {
      final between =
          (r.ownerId == other && r.requesterId == me) ||
          (r.requesterId == other && r.ownerId == me);
      if (between) byId[r.id] = r;
    }
    byId[provider.request.id] = provider.request;
    return byId.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<void> _onAcceptPressed(
    BuildContext context,
    RequestModel request,
  ) async {
    final name = _productNameFor(request);
    final confirmed = await AppDialog.confirm(
      context,
      title: context.l10n.giveThisItem,
      message: context.l10n.giveThisItemConfirm(name),
      confirmText: context.l10n.yesGive,
      cancelText: context.l10n.cancel,
      icon: AppIcons.checkCircle,
    );
    if (!confirmed) return;
    if (!context.mounted) return;

    final provider = context.read<ChatProvider>();
    var success = false;
    String? error;
    if (request.id == provider.request.id) {
      success = await provider.acceptRequest();
      error = provider.errorMessage;
    } else {
      setState(() => _accepting.add(request.id));
      try {
        await RequestStore.accept(request);
        success = true;
      } catch (_) {
        success = false;
      } finally {
        if (mounted) setState(() => _accepting.remove(request.id));
      }
    }
    if (!context.mounted) return;

    if (success) {
      AppSnackbar.show(context, context.l10n.itemMarkedAsGiven);
    } else {
      AppSnackbar.show(
        context,
        error ?? context.l10n.failedToUpdate,
        icon: Icons.error_outline,
        color: AppColors.error,
      );
    }
  }

  String _otherName(ChatProvider provider) =>
      provider.otherProfile?.fullName ?? context.l10n.paoUser;

  void _onMenuSelected(BuildContext context, _ChatMenu choice) {
    final provider = context.read<ChatProvider>();
    switch (choice) {
      case _ChatMenu.clear:
        _onClearChatPressed(context, provider);
      case _ChatMenu.report:
        _onReportPressed(context, provider);
      case _ChatMenu.block:
        _toggleBlock(context, provider);
    }
  }

  Future<void> _onClearChatPressed(
    BuildContext context,
    ChatProvider provider,
  ) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: context.l10n.clearChat,
      message: context.l10n.clearChatConfirm,
      confirmText: context.l10n.clearChatAction,
      cancelText: context.l10n.cancel,
      isDestructive: true,
      icon: AppIcons.delete,
    );
    if (!confirmed || !context.mounted) return;
    final ok = await provider.clearChat();
    if (!context.mounted) return;
    ok
        ? AppSnackbar.show(context, context.l10n.chatCleared)
        : AppSnackbar.show(
            context,
            context.l10n.failedToUpdate,
            icon: Icons.error_outline,
            color: AppColors.error,
          );
  }

  Future<void> _toggleBlock(BuildContext context, ChatProvider provider) async {
    final blocking = !provider.isBlockedByMe;
    if (blocking) {
      final confirmed = await AppDialog.confirm(
        context,
        title: context.l10n.blockUserTitle(_otherName(provider)),
        message: context.l10n.blockUserConfirm,
        confirmText: context.l10n.blockUser,
        cancelText: context.l10n.cancel,
        isDestructive: true,
        icon: AppIcons.close,
      );
      if (!confirmed || !context.mounted) return;
    }
    final ok = await provider.setBlocked(blocking);
    if (!context.mounted) return;
    ok
        ? AppSnackbar.show(
            context,
            blocking ? context.l10n.userBlocked : context.l10n.userUnblocked,
          )
        : AppSnackbar.show(
            context,
            context.l10n.failedToUpdate,
            icon: Icons.error_outline,
            color: AppColors.error,
          );
  }

  Future<void> _onReportPressed(
    BuildContext context,
    ChatProvider provider,
  ) async {
    final sent = await showReportUserSheet(
      context,
      userName: _otherName(provider),
      onSubmit: provider.reportUser,
    );
    if (sent == true && context.mounted) {
      AppSnackbar.show(context, context.l10n.reportSent);
    }
  }

  Future<void> _onDeleteForMePressed(
    BuildContext context,
    MessageModel message,
  ) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: context.l10n.deleteForMe,
      message: context.l10n.deleteForMeConfirm,
      confirmText: context.l10n.delete,
      cancelText: context.l10n.cancel,
      isDestructive: true,
      icon: AppIcons.delete,
    );
    if (!confirmed || !context.mounted) return;

    final deleted = await context.read<ChatProvider>().deleteMessageForMe(
      message,
    );
    if (deleted || !context.mounted) return;
    AppSnackbar.show(
      context,
      context.l10n.failedToDeleteMessage,
      icon: Icons.error_outline,
      color: AppColors.error,
    );
  }

  Future<void> _onDeleteMessagePressed(
    BuildContext context,
    MessageModel message,
  ) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: context.l10n.deleteMessage,
      message: context.l10n.deleteMessageConfirm,
      confirmText: context.l10n.delete,
      cancelText: context.l10n.cancel,
      isDestructive: true,
      icon: AppIcons.delete,
    );
    if (!confirmed || !context.mounted) return;

    final deleted = await context.read<ChatProvider>().deleteMessage(message);
    if (deleted || !context.mounted) return;
    AppSnackbar.show(
      context,
      context.l10n.failedToDeleteMessage,
      icon: Icons.error_outline,
      color: AppColors.error,
    );
  }

  // Requests whose feedback dialog was already shown during this run.
  static final Set<String> _feedbackPrompted = {};

  /// Once the owner has accepted, the requester gets the feedback dialog
  /// right inside the chat -- on opening it, or live while it is open.
  void _maybePromptFeedback(ChatProvider provider) {
    if (!provider.isRequester ||
        !provider.request.isAccepted ||
        !provider.feedbackChecked ||
        provider.feedbackGiven ||
        !_feedbackPrompted.add(provider.request.id)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onLeaveFeedbackPressed(context);
    });
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
      AppSnackbar.show(context, context.l10n.thanksForFeedback);
    }
  }

  Widget _requestCard(
    BuildContext context,
    ChatProvider provider,
    RequestModel request,
  ) {
    final product = _productFor(request);
    return _RequestCard(
      request: request,
      productName: _productNameFor(request),
      imageUrl: product?.imageUrl,
      onOpenProduct: product == null
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailScreen(product: product),
              ),
            ),
      time: _formatTime(request.createdAt),
      isAccepting: request.id == provider.request.id
          ? provider.isAccepting
          : _accepting.contains(request.id),
      onAccept: () => _onAcceptPressed(context, request),
      onReject: () => _onRejectPressed(context, request),
    );
  }

  Widget _dayChip(BuildContext context, DateTime at) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: _InfoChip(text: _dayLabel(context, at)),
  );

  /// Messages and the request cards between the two people, in time order:
  /// a request is part of the conversation, at the moment it was made.
  Widget _buildTimeline(
    BuildContext context,
    ChatProvider provider,
    _ChatColors colors,
  ) {
    final currentUserId = provider.currentUserId;
    final messages = provider.messages;
    final requests = _pairRequests(provider);

    if (messages.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final r in requests) ...[
            _dayChip(context, r.createdAt),
            _requestCard(context, provider, r),
          ],
          const SizedBox(height: 12),
          _InfoChip(text: context.l10n.sayHello),
        ],
      );
    }

    // Oldest first; a request goes before a message sent at the same time.
    final entries =
        <({DateTime at, MessageModel? message, RequestModel? request})>[
          for (final m in messages)
            (at: m.createdAt, message: m, request: null),
          for (final r in requests)
            (at: r.createdAt, message: null, request: r),
        ]..sort((a, b) {
          final c = a.at.compareTo(b.at);
          if (c != 0) return c;
          return (a.request != null ? 0 : 1) - (b.request != null ? 0 : 1);
        });

    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final i = entries.length - 1 - index;
        final entry = entries[i];
        final previous = i > 0 ? entries[i - 1] : null;
        final startsNewDay =
            previous == null ||
            !_isSameDay(previous.at.toLocal(), entry.at.toLocal());

        final request = entry.request;
        if (request != null) {
          return Column(
            children: [
              if (startsNewDay) _dayChip(context, request.createdAt),
              _requestCard(context, provider, request),
            ],
          );
        }

        final message = entry.message!;
        final isMine = message.senderId == currentUserId;
        // Like WhatsApp: only the first bubble of a run from the same
        // sender gets a tail and extra spacing.
        final startsGroup =
            startsNewDay ||
            previous.request != null ||
            previous.message!.senderId != message.senderId;
        return Column(
          children: [
            if (startsNewDay) _dayChip(context, message.createdAt),
            _SwipeToReply(
              enabled:
                  message.status == MessageStatus.sent &&
                  !provider.isBlockedByMe,
              onReply: () => _startReplying(message),
              child: _MessageBubble(
                message: message,
                isMine: isMine,
                showTail: startsGroup,
                topSpacing: startsGroup && !startsNewDay ? 8 : 2,
                time: _formatTime(message.createdAt),
                currentUserId: currentUserId,
                replyTo: message.replyToId == null
                    ? null
                    : (provider.messageById(message.replyToId)),
                replySenderName: message.replyToId == null
                    ? null
                    : (provider.messageById(message.replyToId) == null
                          ? null
                          : _senderLabel(
                              context,
                              provider.messageById(message.replyToId)!,
                            )),
                onLongPress: () =>
                    _showMessageActions(context, message, isMine: isMine),
                onRetry: () => provider.retry(message),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    _maybePromptFeedback(provider);
    final status = _statusLabel(context, provider.otherProfile?.lastSeenAt);
    final isOnline = status == context.l10n.online;
    final colors = _ChatColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            provider.isLoadingProfile
                ? const AppShimmer(
                    width: 38,
                    height: 38,
                    borderRadius: BorderRadius.all(Radius.circular(19)),
                  )
                : Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AppAvatar(
                        radius: 19,
                        imageUrl: provider.otherProfile?.avatarUrl,
                      ),
                      if (isOnline)
                        PositionedDirectional(
                          end: 0,
                          bottom: 0,
                          child: Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: context.appBackground,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
            const SizedBox(width: 10),
            Expanded(
              child: provider.isLoadingProfile
                  ? const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppShimmer(
                          width: 110,
                          height: 13,
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                        ),
                        SizedBox(height: 6),
                        AppShimmer(
                          width: 150,
                          height: 10,
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          provider.otherProfile?.fullName ??
                              context.l10n.paoUser,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          status ?? widget.productName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: isOnline
                                ? Colors.green
                                : context.appTextSecondary,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<_ChatMenu>(
            onSelected: (choice) => _onMenuSelected(context, choice),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _ChatMenu.clear,
                child: Text(context.l10n.clearChat),
              ),
              PopupMenuItem(
                value: _ChatMenu.report,
                child: Text(context.l10n.reportUser),
              ),
              PopupMenuItem(
                value: _ChatMenu.block,
                child: Text(
                  provider.isBlockedByMe
                      ? context.l10n.unblockUser
                      : context.l10n.blockUser,
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (provider.isRequester &&
                provider.request.isAccepted &&
                !provider.feedbackGiven)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: context.appBackground,
                child: PrimaryButton(
                  label: context.l10n.receivedLeaveFeedback,
                  onPressed: () => _onLeaveFeedbackPressed(context),
                ),
              ),
            Expanded(
              child: provider.isLoading
                  ? const _ChatShimmer()
                  : ListenableBuilder(
                      // Request statuses live in the stores.
                      listenable: Listenable.merge([
                        RequestStore.sent,
                        RequestStore.received,
                      ]),
                      builder: (context, _) =>
                          _buildTimeline(context, provider, colors),
                    ),
            ),
            if (provider.isBlockedByMe)
              _BlockedBar(
                colors: colors,
                onUnblock: () => _toggleBlock(context, provider),
              )
            else ...[
              if (_replyingTo != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colors.composer,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    border: BorderDirectional(
                      start: BorderSide(color: AppColors.primary, width: 4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.reply, size: 18, color: colors.meta),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _senderLabel(context, _replyingTo!),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colors.text,
                              ),
                            ),
                            Text(
                              messagePreview(context, _replyingTo!),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.meta,
                              ),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => setState(() => _replyingTo = null),
                        child: AppIcon(
                          AppIcons.close,
                          size: 18,
                          color: colors.meta,
                        ),
                      ),
                    ],
                  ),
                ),
              if (_editingMessage != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colors.composer,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    border: BorderDirectional(
                      start: BorderSide(color: AppColors.primary, width: 4),
                    ),
                  ),
                  child: Row(
                    children: [
                      AppIcon(AppIcons.edit, size: 16, color: colors.meta),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              context.l10n.editMessage,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colors.text,
                              ),
                            ),
                            Text(
                              _editingMessage!.body,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.meta,
                              ),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: _cancelEditing,
                        child: AppIcon(
                          AppIcons.close,
                          size: 18,
                          color: colors.meta,
                        ),
                      ),
                    ],
                  ),
                ),
              if (provider.isUploadingMedia)
                const LinearProgressIndicator(minHeight: 2),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: ListenableBuilder(
                        listenable: _voice,
                        builder: (context, _) => _voice.isRecording
                            ? RecordingBar(
                                controller: _voice,
                                background: colors.composer,
                                textColor: colors.text,
                                hintColor: colors.meta,
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  color: colors.composer,
                                  borderRadius:
                                      (_editingMessage != null ||
                                          _replyingTo != null)
                                      ? const BorderRadius.vertical(
                                          bottom: Radius.circular(24),
                                        )
                                      : BorderRadius.circular(24),
                                ),
                                child: TextField(
                                  controller: _messageController,
                                  focusNode: _inputFocus,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  minLines: 1,
                                  maxLines: 5,
                                  // Enter adds a new line (like WhatsApp); the send
                                  // button submits.
                                  keyboardType: TextInputType.multiline,
                                  textInputAction: TextInputAction.newline,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: colors.text,
                                  ),
                                  decoration: InputDecoration(
                                    suffixIcon: _editingMessage == null
                                        ? IconButton(
                                            tooltip: context.l10n.attach,
                                            icon: Icon(
                                              Icons.attach_file,
                                              color: colors.meta,
                                            ),
                                            onPressed: () => _attach(context),
                                          )
                                        : null,
                                    hintText: context.l10n.typeMessageHint,
                                    hintStyle: TextStyle(color: colors.meta),
                                    filled: false,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _messageController,
                      builder: (context, value, _) {
                        if (value.text.trim().isEmpty &&
                            _editingMessage == null) {
                          return VoiceMicButton(
                            controller: _voice,
                            onRecorded: (recording) => _sendMedia(
                              context,
                              context.read<ChatProvider>(),
                              recording.file,
                              MessageMediaType.audio,
                              durationMs: recording.duration.inMilliseconds,
                            ),
                            onPermissionDenied: () => AppSnackbar.show(
                              context,
                              context.l10n.microphonePermissionDenied,
                              icon: Icons.mic_off,
                              color: AppColors.error,
                            ),
                            onTooShort: () => AppSnackbar.show(
                              context,
                              context.l10n.holdToRecordVoice,
                              icon: Icons.mic,
                            ),
                          );
                        }
                        return Material(
                          color: AppColors.primary,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => _submit(context),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: Center(
                                child: AppIcon(
                                  _editingMessage != null
                                      ? AppIcons.check
                                      : AppIcons.send,
                                  size: 22,
                                  mirrorInRtl: _editingMessage == null,
                                  color: AppColors.onPrimary,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// "Today", "Yesterday", the weekday within the last week, else the date.
  String _dayLabel(BuildContext context, DateTime dateTime) {
    final local = dateTime.toLocal();
    final locale = Localizations.localeOf(context).toString();
    final days = _daysAgo(local);
    if (days == 0) return context.l10n.today;
    if (days == 1) return context.l10n.yesterday;
    if (days < 7) return DateFormat.EEEE(locale).format(local);
    return DateFormat.yMMMd(locale).format(local);
  }
}

/// A small centred pill on the chat background -- used for the day
/// separators, the listing this chat is about and the empty-chat hint.
class _InfoChip extends StatelessWidget {
  final String text;

  const _InfoChip({required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = _ChatColors.of(context);
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colors.chip,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colors.chipText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMine;
  final bool showTail;
  final double topSpacing;
  final String time;
  final VoidCallback? onLongPress;

  /// Tapping a failed message re-sends it.
  final VoidCallback? onRetry;
  final String? currentUserId;
  final MessageModel? replyTo;
  final String? replySenderName;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.showTail,
    required this.topSpacing,
    required this.time,
    this.onLongPress,
    this.onRetry,
    this.currentUserId,
    this.replyTo,
    this.replySenderName,
  });

  static const _tailWidth = 8.0;
  static const _radius = Radius.circular(8);

  @override
  Widget build(BuildContext context) {
    final colors = _ChatColors.of(context);
    final bubbleColor = isMine ? colors.outgoing : colors.incoming;
    final metaColor = isMine ? colors.outgoingMeta : colors.meta;
    final isRead = message.readAt != null;

    // Clock while sending, red "!" when it failed, ticks once the server
    // has it.
    Widget statusIcon(Color base, Color readColor) => switch (message.status) {
      MessageStatus.sending => Icon(Icons.schedule, size: 14, color: base),
      MessageStatus.failed => const Icon(
        Icons.error_outline,
        size: 15,
        color: AppColors.error,
      ),
      MessageStatus.sent => AppIcon(
        isRead ? AppIcons.checkAll : AppIcons.check,
        size: 15,
        color: isRead ? readColor : base,
      ),
    };
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final tailOnRight = isMine != isRtl;
    final metaStyle = TextStyle(fontSize: 11, color: metaColor);
    final editedText = message.editedAt != null
        ? '${context.l10n.editedLabel} '
        : '';

    // The time (and ticks) sit in the bubble's bottom corner, WhatsApp
    // style: an invisible copy of them is appended to the text so the last
    // line leaves room, or wraps when there isn't any.
    final meta = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$editedText$time', style: metaStyle),
        if (isMine) ...[
          const SizedBox(width: 3),
          statusIcon(metaColor, _ChatColors.readTick),
        ],
      ],
    );

    // Photos and videos fill the bubble edge to edge, with the time and
    // ticks laid over the picture (WhatsApp style).
    final isVisualMedia =
        message.hasMedia && message.mediaType != MessageMediaType.audio;
    final overlayMeta = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$editedText$time',
          style: const TextStyle(fontSize: 11, color: Colors.white),
        ),
        if (isMine) ...[
          const SizedBox(width: 3),
          statusIcon(Colors.white, const Color(0xFF53BDEB)),
        ],
      ],
    );

    return Padding(
      padding: EdgeInsetsDirectional.only(
        top: topSpacing,
        start: isMine ? 48 : 0,
        end: isMine ? 0 : 48,
      ),
      child: Align(
        alignment: isMine
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: GestureDetector(
          onLongPress: onLongPress,
          onTap: message.status == MessageStatus.failed ? onRetry : null,
          child: Padding(
            // Keep bubbles lined up whether or not they carry a tail.
            padding: EdgeInsetsDirectional.only(
              start: isMine ? 0 : _tailWidth,
              end: isMine ? _tailWidth : 0,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: isVisualMedia
                      ? const EdgeInsets.all(3)
                      : const EdgeInsets.fromLTRB(9, 6, 9, 6),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadiusDirectional.only(
                      topStart: showTail && !isMine ? Radius.zero : _radius,
                      topEnd: showTail && isMine ? Radius.zero : _radius,
                      bottomStart: _radius,
                      bottomEnd: _radius,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 1,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.replyToId != null)
                        _ReplyQuote(
                          senderName: replySenderName,
                          body: replyTo == null
                              ? null
                              : messagePreview(context, replyTo!),
                          isMine: isMine,
                        ),
                      if (message.hasMedia)
                        ChatMediaContent(
                          message: message,
                          foreground: isMine
                              ? colors.outgoingText
                              : colors.text,
                          accent: isMine
                              ? colors.outgoingText
                              : AppColors.primary,
                          meta: meta,
                          overlayMeta: overlayMeta,
                        )
                      else
                        Stack(
                          children: [
                            Text.rich(
                              TextSpan(
                                text: message.body,
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.3,
                                  color: isMine
                                      ? colors.outgoingText
                                      : colors.text,
                                ),
                                children: [
                                  TextSpan(
                                    text: '   $editedText$time',
                                    style: metaStyle.copyWith(
                                      color: Colors.transparent,
                                    ),
                                  ),
                                  if (isMine)
                                    const WidgetSpan(
                                      child: SizedBox(width: 18),
                                    ),
                                ],
                              ),
                            ),
                            PositionedDirectional(
                              end: 0,
                              bottom: 0,
                              child: meta,
                            ),
                          ],
                        ),
                      if (message.reactions.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(
                            top: 4,
                            left: isVisualMedia ? 6 : 0,
                            right: isVisualMedia ? 6 : 0,
                            bottom: isVisualMedia ? 3 : 0,
                          ),
                          child: _ReactionChips(
                            reactions: message.reactions,
                            currentUserId: currentUserId,
                          ),
                        ),
                    ],
                  ),
                ),
                if (showTail)
                  Positioned(
                    top: 0,
                    left: tailOnRight ? null : -_tailWidth,
                    right: tailOnRight ? -_tailWidth : null,
                    child: CustomPaint(
                      size: const Size(_tailWidth, 12),
                      painter: _BubbleTailPainter(
                        color: bubbleColor,
                        pointsRight: tailOnRight,
                      ),
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

/// The quoted message shown at the top of a reply bubble.
class _ReplyQuote extends StatelessWidget {
  final String? senderName;
  final String? body;
  final bool isMine;

  const _ReplyQuote({
    required this.senderName,
    required this.body,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _ChatColors.of(context);
    final textColor = isMine ? colors.outgoingText : colors.text;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 8, 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(6),
        border: BorderDirectional(
          start: BorderSide(
            color: isMine ? AppColors.primaryDark : AppColors.primary,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (senderName != null)
            Text(
              senderName!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          Text(
            body ?? context.l10n.originalMessageUnavailable,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontStyle: body == null ? FontStyle.italic : FontStyle.normal,
              color: textColor.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

/// Emoji reactions under a bubble, grouped with a count when more than one
/// participant used the same emoji.
class _ReactionChips extends StatelessWidget {
  final Map<String, String> reactions;
  final String? currentUserId;

  const _ReactionChips({required this.reactions, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final colors = _ChatColors.of(context);
    final counts = <String, int>{};
    for (final emoji in reactions.values) {
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }
    return Wrap(
      spacing: 4,
      children: [
        for (final e in counts.entries)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: colors.chip,
              borderRadius: BorderRadius.circular(12),
              border: reactions[currentUserId] == e.key
                  ? Border.all(color: AppColors.primary, width: 1.5)
                  : null,
            ),
            child: Text(
              e.value > 1 ? '${e.key} ${e.value}' : e.key,
              style: TextStyle(fontSize: 13, color: colors.text),
            ),
          ),
      ],
    );
  }
}

/// The little triangle on the top corner of the first bubble in a group.
class _BubbleTailPainter extends CustomPainter {
  final Color color;
  final bool pointsRight;

  const _BubbleTailPainter({required this.color, required this.pointsRight});

  @override
  void paint(Canvas canvas, Size size) {
    final path = pointsRight
        ? (Path()
            ..moveTo(0, 0)
            ..lineTo(size.width - 1, 0)
            ..quadraticBezierTo(size.width, 0, size.width - 1.5, 1.5)
            ..lineTo(0, size.height)
            ..close())
        : (Path()
            ..moveTo(size.width, 0)
            ..lineTo(1, 0)
            ..quadraticBezierTo(0, 0, 1.5, 1.5)
            ..lineTo(size.width, size.height)
            ..close());
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BubbleTailPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.pointsRight != pointsRight;
}

/// Skeleton bubbles shown while the conversation history loads.
class _ChatShimmer extends StatelessWidget {
  const _ChatShimmer();

  // (isMine, width fraction, height) for each placeholder bubble.
  static const _bubbles = [
    (false, 0.55, 38.0),
    (false, 0.35, 38.0),
    (true, 0.6, 56.0),
    (false, 0.45, 38.0),
    (true, 0.3, 38.0),
    (true, 0.5, 38.0),
    (false, 0.65, 56.0),
    (true, 0.4, 38.0),
    (false, 0.3, 38.0),
    (true, 0.55, 38.0),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => ListView.builder(
        reverse: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        itemCount: _bubbles.length,
        itemBuilder: (context, index) {
          final (isMine, widthFactor, height) = _bubbles[index];
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Align(
              alignment: isMine
                  ? AlignmentDirectional.centerEnd
                  : AlignmentDirectional.centerStart,
              child: AppShimmer(
                width: constraints.maxWidth * widthFactor,
                height: height,
                borderRadius: const BorderRadius.all(Radius.circular(8)),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The "Give me" request, shown at the top of the conversation like an
/// order in a freelance chat: who asked, for what, its status, and (for
/// the owner) the button to accept and donate the item.
class _RequestCard extends StatelessWidget {
  final RequestModel request;
  final String productName;
  final String? imageUrl;
  final VoidCallback? onOpenProduct;
  final String time;
  final bool isAccepting;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _RequestCard({
    required this.request,
    required this.productName,
    required this.imageUrl,
    required this.onOpenProduct,
    required this.time,
    required this.isAccepting,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final l10n = context.l10n;
    final colors = _ChatColors.of(context);

    final me = AuthRepository().currentUser;
    final isOwner = request.ownerId == me?.id;
    final requester = isOwner ? provider.otherProfile : null;
    final name = isOwner ? requester?.fullName : me?.fullName;
    final avatarUrl = isOwner ? requester?.avatarUrl : me?.avatarUrl;
    final title = isOwner
        ? l10n.requestWantsItem(name ?? l10n.paoUser)
        : l10n.requestYouAsked;

    final (statusText, statusColor) = switch (request.status) {
      'accepted' => (
        isOwner ? l10n.itemMarkedAsGiven : l10n.statusGivenToYou,
        Colors.green,
      ),
      'closed' => (l10n.statusNotSelected, colors.meta),
      'declined' => (l10n.statusDeclined, colors.meta),
      _ => (l10n.statusPending, AppColors.primary),
    };

    // Like a chat bubble: what the other person asks for sits on the left,
    // what I asked for on the right.
    final isMine = request.requesterId == me?.id;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.82;
    return Align(
      alignment: isMine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colors.chip,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.25),
            ),
          ),
          child: InkWell(
            // Opens the item's detail screen.
            onTap: onOpenProduct,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (imageUrl != null)
                  AspectRatio(
                    aspectRatio: 16 / 10,
                    child: AppNetworkImage(
                      imageUrl: imageUrl!,
                      memCacheWidth: 700,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AppAvatar(radius: 22, imageUrl: avatarUrl),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const AppIcon(
                                      AppIcons.chat,
                                      size: 15,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: colors.text,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  productName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colors.meta,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ),
                          Text(
                            time,
                            style: TextStyle(fontSize: 11, color: colors.meta),
                          ),
                        ],
                      ),
                      if (isOwner && request.isPending) ...[
                        const SizedBox(height: 10),
                        PrimaryButton(
                          label: l10n.acceptAndGiveThisItem,
                          isLoading: isAccepting,
                          onPressed: onAccept,
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: isAccepting ? null : onReject,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                              minimumSize: const Size.fromHeight(48),
                            ),
                            child: Text(l10n.rejectRequest),
                          ),
                        ),
                      ],
                    ],
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

enum _ChatMenu { clear, report, block }

/// Replaces the composer while the other person is blocked.
class _BlockedBar extends StatelessWidget {
  const _BlockedBar({required this.colors, required this.onUnblock});

  final _ChatColors colors;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: colors.composer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.block, size: 20, color: colors.meta),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.l10n.youBlockedThisUser,
              style: TextStyle(fontSize: 14, color: colors.text),
            ),
          ),
          TextButton(
            onPressed: onUnblock,
            child: Text(context.l10n.unblockUser),
          ),
        ],
      ),
    );
  }
}

/// WhatsApp-style swipe: drag a message sideways (towards the end of the
/// line) and let go to reply to it. A reply icon shows while dragging and
/// the message springs back.
class _SwipeToReply extends StatefulWidget {
  const _SwipeToReply({
    required this.child,
    required this.onReply,
    required this.enabled,
  });

  final Widget child;
  final VoidCallback onReply;
  final bool enabled;

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply>
    with SingleTickerProviderStateMixin {
  static const _trigger = 56.0;
  static const _max = 76.0;

  late final AnimationController _back = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  double _drag = 0;
  bool _armed = false;

  @override
  void dispose() {
    _back.dispose();
    super.dispose();
  }

  void _update(DragUpdateDetails details, double sign) {
    final next = (_drag + details.delta.dx * sign).clamp(0.0, _max);
    if (next >= _trigger && !_armed) {
      _armed = true;
      HapticFeedback.selectionClick();
    } else if (next < _trigger) {
      _armed = false;
    }
    setState(() => _drag = next);
  }

  void _end() {
    if (_armed) widget.onReply();
    _armed = false;
    final from = _drag;
    _back
      ..removeListener(_springListener)
      ..reset();
    _from = from;
    _back
      ..addListener(_springListener)
      ..forward();
  }

  double _from = 0;

  void _springListener() {
    setState(() => _drag = _from * (1 - Curves.easeOut.transform(_back.value)));
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final sign = rtl ? -1.0 : 1.0;
    final progress = (_drag / _trigger).clamp(0.0, 1.0);
    final colors = _ChatColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) => _back.stop(),
      onHorizontalDragUpdate: (d) => _update(d, sign),
      onHorizontalDragEnd: (_) => _end(),
      onHorizontalDragCancel: _end,
      child: Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [
          if (_drag > 0)
            PositionedDirectional(
              start: 8,
              child: Opacity(
                opacity: progress,
                child: Transform.scale(
                  scale: 0.6 + 0.4 * progress,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: colors.chip,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.reply, size: 18, color: colors.chipText),
                  ),
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(_drag * sign, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
