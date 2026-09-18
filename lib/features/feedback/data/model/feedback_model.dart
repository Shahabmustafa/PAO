class FeedbackModel {
  const FeedbackModel({
    required this.id,
    required this.requestId,
    required this.postId,
    required this.fromUserId,
    required this.toUserId,
    required this.rating,
    required this.createdAt,
    this.comment,
  });

  final String id;
  final String requestId;
  final String postId;
  final String fromUserId;
  final String toUserId;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  factory FeedbackModel.fromJson(Map<String, dynamic> json) {
    return FeedbackModel(
      id: json['id'] as String,
      requestId: json['request_id'] as String,
      postId: json['post_id'] as String,
      fromUserId: json['from_user_id'] as String,
      toUserId: json['to_user_id'] as String,
      rating: json['rating'] as int,
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
