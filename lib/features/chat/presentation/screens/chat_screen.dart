import 'package:flutter/material.dart';
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
import '../../../requests/data/model/request_model.dart';
import '../../data/model/message_model.dart';
import '../provider/chat_provider.dart';
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
  MessageModel? _editingMessage;

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
      _editingMessage = message;
      _messageController.text = message.body;
      _messageController.selection = TextSelection.collapsed(
        offset: _messageController.text.length,
      );
    });
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
      await provider.sendMessage(text);
    }
  }

  Future<void> _showMessageActions(
    BuildContext context,
    MessageModel message,
  ) async {
    final action = await showModalBottomSheet<VoidCallback>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: AppIcon(AppIcons.edit, color: AppColors.primary),
              title: Text(sheetContext.l10n.edit),
              onTap: () =>
                  Navigator.pop(sheetContext, () => _startEditing(message)),
            ),
            ListTile(
              leading: const AppIcon(AppIcons.delete, color: AppColors.error),
              title: Text(
                sheetContext.l10n.delete,
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

  Future<void> _onAcceptPressed(BuildContext context) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: context.l10n.giveThisItem,
      message: context.l10n.giveThisItemConfirm(widget.productName),
      confirmText: context.l10n.yesGive,
      cancelText: context.l10n.cancel,
      icon: AppIcons.checkCircle,
    );
    if (!confirmed) return;
    if (!context.mounted) return;

    final provider = context.read<ChatProvider>();
    final success = await provider.acceptRequest();
    if (!context.mounted) return;

    if (success) {
      AppSnackbar.show(context, context.l10n.itemMarkedAsGiven);
    } else {
      AppSnackbar.show(
        context,
        provider.errorMessage ?? context.l10n.failedToUpdate,
        icon: Icons.error_outline,
        color: AppColors.error,
      );
    }
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final currentUserId = provider.currentUserId;
    final status = _statusLabel(context, provider.otherProfile?.lastSeenAt);
    final isOnline = status == context.l10n.online;
    final colors = _ChatColors.of(context);
    final messages = provider.messages;

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
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (provider.isOwner && provider.request.isPending)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: context.appBackground,
                child: PrimaryButton(
                  label: context.l10n.acceptAndGiveThisItem,
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
                color: context.appBackground,
                child: PrimaryButton(
                  label: context.l10n.receivedLeaveFeedback,
                  onPressed: () => _onLeaveFeedbackPressed(context),
                ),
              ),
            Expanded(
              child: provider.isLoading
                  ? const _ChatShimmer()
                  : messages.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _InfoChip(
                          icon: AppIcons.description,
                          text: widget.productName,
                        ),
                        const SizedBox(height: 12),
                        _InfoChip(text: context.l10n.sayHello),
                      ],
                    )
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      // One extra item at the top of the history: which
                      // listing this conversation is about.
                      itemCount: messages.length + 1,
                      itemBuilder: (context, index) {
                        if (index == messages.length) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _InfoChip(
                              icon: AppIcons.description,
                              text: widget.productName,
                            ),
                          );
                        }
                        final i = messages.length - 1 - index;
                        final message = messages[i];
                        final previous = i > 0 ? messages[i - 1] : null;
                        final isMine = message.senderId == currentUserId;
                        final startsNewDay =
                            previous == null ||
                            !_isSameDay(
                              previous.createdAt.toLocal(),
                              message.createdAt.toLocal(),
                            );
                        // Like WhatsApp: only the first bubble of a run from
                        // the same sender gets a tail and extra spacing.
                        final startsGroup =
                            startsNewDay ||
                            previous.senderId != message.senderId;
                        return Column(
                          children: [
                            if (startsNewDay)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: _InfoChip(
                                  text: _dayLabel(context, message.createdAt),
                                ),
                              ),
                            _MessageBubble(
                              message: message,
                              isMine: isMine,
                              showTail: startsGroup,
                              topSpacing: startsGroup && !startsNewDay ? 8 : 2,
                              time: _formatTime(message.createdAt),
                              onLongPress: isMine
                                  ? () => _showMessageActions(context, message)
                                  : null,
                            ),
                          ],
                        );
                      },
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
                            style: TextStyle(fontSize: 12, color: colors.meta),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: colors.composer,
                        borderRadius: _editingMessage != null
                            ? const BorderRadius.vertical(
                                bottom: Radius.circular(24),
                              )
                            : BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        textCapitalization: TextCapitalization.sentences,
                        minLines: 1,
                        maxLines: 5,
                        textInputAction: TextInputAction.send,
                        style: TextStyle(fontSize: 15, color: colors.text),
                        decoration: InputDecoration(
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
                        onSubmitted: (_) => _submit(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Material(
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
                  ),
                ],
              ),
            ),
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
  final String? icon;

  const _InfoChip({required this.text, this.icon});

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
            if (icon != null) ...[
              AppIcon(icon!, size: 14, color: colors.chipText),
              const SizedBox(width: 6),
            ],
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

  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.showTail,
    required this.topSpacing,
    required this.time,
    this.onLongPress,
  });

  static const _tailWidth = 8.0;
  static const _radius = Radius.circular(8);

  @override
  Widget build(BuildContext context) {
    final colors = _ChatColors.of(context);
    final bubbleColor = isMine ? colors.outgoing : colors.incoming;
    final metaColor = isMine ? colors.outgoingMeta : colors.meta;
    final isRead = message.readAt != null;
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
          AppIcon(
            isRead ? AppIcons.checkAll : AppIcons.check,
            size: 15,
            color: isRead ? _ChatColors.readTick : metaColor,
          ),
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
                  padding: const EdgeInsets.fromLTRB(9, 6, 9, 6),
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
                  child: Stack(
                    children: [
                      Text.rich(
                        TextSpan(
                          text: message.body,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.3,
                            color: isMine ? colors.outgoingText : colors.text,
                          ),
                          children: [
                            TextSpan(
                              text: '   $editedText$time',
                              style: metaStyle.copyWith(
                                color: Colors.transparent,
                              ),
                            ),
                            if (isMine)
                              const WidgetSpan(child: SizedBox(width: 18)),
                          ],
                        ),
                      ),
                      PositionedDirectional(end: 0, bottom: 0, child: meta),
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
