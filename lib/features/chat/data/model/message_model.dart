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

  MessageModel copyWith({Map<String, String>? reactions}) => MessageModel(
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
  );

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
    );
  }
}
