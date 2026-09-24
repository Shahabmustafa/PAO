class ProfileModel {
  const ProfileModel({
    required this.id,
    this.fullName,
    this.email,
    this.phone,
    this.bio,
    this.avatarUrl,
    this.lastSeenAt,
  });

  final String id;
  final String? fullName;
  final String? email;
  final String? phone;
  final String? bio;
  final String? avatarUrl;
  final DateTime? lastSeenAt;

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.parse(json['last_seen_at'] as String)
          : null,
    );
  }

  /// Only what is safe and useful to keep on the device for fast rendering
  /// -- deliberately without e-mail or phone.
  Map<String, dynamic> toCacheJson() => {
    'id': id,
    'full_name': fullName,
    'bio': bio,
    'avatar_url': avatarUrl,
    'last_seen_at': lastSeenAt?.toUtc().toIso8601String(),
  };
}
