/// What a message carries besides (or instead of) text.
enum MessageMediaType {
  image,
  video,
  audio;

  static MessageMediaType? parse(String? value) {
    for (final type in values) {
      if (type.name == value) return type;
    }
    return null;
  }
}

/// Delivery state of a message on this device. Only ever `sending` or
/// `failed` for a message the current user wrote that the server hasn't
/// confirmed yet; everything that came from Supabase is `sent`.
enum MessageStatus {
  sending,
  sent,
  failed;

  static MessageStatus parse(String? value) {
    for (final status in values) {
      if (status.name == value) return status;
    }
    return sent;
  }
}

class MessageModel {
  const MessageModel({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.body,
    required this.createdAt,
    this.requestId,
    this.readAt,
    this.editedAt,
    this.mediaType,
    this.mediaPath,
    this.mediaDurationMs,
    this.deletedFor = const [],
    this.replyToId,
    this.reactions = const {},
    this.status = MessageStatus.sent,
  });

  final String id;
  final String senderId;
  final String recipientId;

  /// Which listing this message was originally sent about -- kept for
  /// reference (and the push-notification deep link) only; it no longer
  /// determines which conversation a message belongs to.
  final String? requestId;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;
  final DateTime? editedAt;

  /// Set for photo / video / voice messages; [mediaPath] is the file's path
  /// in the private `chat_media` bucket and [body] is empty.
  final MessageMediaType? mediaType;
  final String? mediaPath;
  final int? mediaDurationMs;

  bool get hasMedia => mediaType != null && mediaPath != null;

  /// Users who hid this message from their own view ("delete for me").
  final List<String> deletedFor;

  /// The message this one replies to, if any.
  final String? replyToId;

  /// userId -> emoji; each participant has at most one reaction.
  final Map<String, String> reactions;

  /// Local delivery state; see [MessageStatus].
  final MessageStatus status;

  bool get isPending => status != MessageStatus.sent;

  MessageModel copyWith({
    Map<String, String>? reactions,
    MessageStatus? status,
  }) => MessageModel(
    id: id,
    senderId: senderId,
    recipientId: recipientId,
    body: body,
    createdAt: createdAt,
    requestId: requestId,
    readAt: readAt,
    editedAt: editedAt,
    mediaType: mediaType,
    mediaPath: mediaPath,
    mediaDurationMs: mediaDurationMs,
    deletedFor: deletedFor,
    replyToId: replyToId,
    reactions: reactions ?? this.reactions,
    status: status ?? this.status,
  );

  /// Same shape as the `messages` row (plus the local `_status`), so the
  /// cache is read back with [MessageModel.fromJson].
  Map<String, dynamic> toJson() => {
    'id': id,
    'sender_id': senderId,
    'recipient_id': recipientId,
    'request_id': requestId,
    'body': body,
    'created_at': createdAt.toUtc().toIso8601String(),
    'read_at': readAt?.toUtc().toIso8601String(),
    'edited_at': editedAt?.toUtc().toIso8601String(),
    'reply_to_id': replyToId,
    'reactions': reactions,
    'media_type': mediaType?.name,
    'media_path': mediaPath,
    'media_duration_ms': mediaDurationMs,
    'deleted_for': deletedFor,
    '_status': status.name,
  };

  bool isDeletedFor(String userId) => deletedFor.contains(userId);

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      recipientId: json['recipient_id'] as String,
      requestId: json['request_id'] as String?,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      editedAt: json['edited_at'] != null
          ? DateTime.parse(json['edited_at'] as String)
          : null,
      replyToId: json['reply_to_id'] as String?,
      reactions: {
        for (final e in ((json['reactions'] as Map?) ?? const {}).entries)
          e.key as String: e.value as String,
      },
      mediaType: MessageMediaType.parse(json['media_type'] as String?),
      mediaPath: json['media_path'] as String?,
      mediaDurationMs: json['media_duration_ms'] as int?,
      deletedFor: [
        for (final id in (json['deleted_for'] as List?) ?? const [])
          id as String,
      ],
      status: MessageStatus.parse(json['_status'] as String?),
    );
  }
}
