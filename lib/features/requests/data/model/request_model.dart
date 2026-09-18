class RequestModel {
  const RequestModel({
    required this.id,
    required this.postId,
    required this.requesterId,
    required this.ownerId,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String postId;
  final String requesterId;
  final String ownerId;
  final String status;
  final DateTime createdAt;

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';

  RequestModel copyWith({String? status}) {
    return RequestModel(
      id: id,
      postId: postId,
      requesterId: requesterId,
      ownerId: ownerId,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }

  factory RequestModel.fromJson(Map<String, dynamic> json) {
    return RequestModel(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      requesterId: json['requester_id'] as String,
      ownerId: json['owner_id'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
