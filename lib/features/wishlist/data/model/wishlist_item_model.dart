class WishlistItemModel {
  const WishlistItemModel({
    required this.id,
    required this.userId,
    required this.postId,
    required this.title,
    this.note,
  });

  final String id;
  final String userId;
  final String postId;
  final String title;
  final String? note;

  factory WishlistItemModel.fromJson(Map<String, dynamic> json) {
    return WishlistItemModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      postId: json['post_id'] as String,
      title: json['title'] as String,
      note: json['note'] as String?,
    );
  }
}
