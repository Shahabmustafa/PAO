import 'package:supabase_flutter/supabase_flutter.dart';

class UserModel {
  const UserModel({
    required this.id,
    this.email,
    this.fullName,
    this.avatarUrl,
  });

  final String id;
  final String? email;
  final String? fullName;
  final String? avatarUrl;

  factory UserModel.fromSupabaseUser(User user) {
    return UserModel(
      id: user.id,
      email: user.email,
      fullName: user.userMetadata?['full_name'] as String?,
      avatarUrl: user.userMetadata?['avatar_url'] as String?,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String?,
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'avatar_url': avatarUrl,
    };
  }
}
