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
    );
  }
}
