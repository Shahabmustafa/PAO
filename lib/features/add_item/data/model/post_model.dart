class PostModel {
  const PostModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.createdAt,
    this.description,
    this.category,
    this.address,
    this.condition = 'New',
    this.imageUrls = const [],
    this.isGiven = false,
  });

  final String id;
  final String userId;
  final String title;
  final String? description;
  final String? category;
  final String? address;
  final String condition;
  final List<String> imageUrls;
  final bool isGiven;
  final DateTime createdAt;

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      category: json['category'] as String?,
      address: json['address'] as String?,
      condition: json['condition'] as String? ?? 'New',
      imageUrls: (json['image_urls'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
      isGiven: json['is_given'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
