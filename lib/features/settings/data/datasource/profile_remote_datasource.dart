import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Talks directly to Supabase: the `users` profile table for display fields,
/// the `avatars` storage bucket for photos, and Supabase Auth for the
/// account's own full_name/avatar metadata and email.
class ProfileRemoteDataSource {
  ProfileRemoteDataSource({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _avatarBucket = 'avatars';

  Future<Map<String, dynamic>?> fetchProfile(String userId) {
    return _client.from('users').select().eq('id', userId).maybeSingle();
  }

  /// Name + avatar only, readable for any user (see public_profiles_view.sql)
  /// — used to show who posted an item on the post detail screen.
  Future<Map<String, dynamic>?> fetchPublicProfile(String userId) {
    return _client
        .from('public_profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
  }

  /// Batched version of [fetchPublicProfile] — used to resolve names/avatars
  /// for a list of feedback authors in one round trip.
  Future<List<Map<String, dynamic>>> fetchPublicProfiles(
    List<String> userIds,
  ) async {
    if (userIds.isEmpty) return [];
    final rows = await _client
        .from('public_profiles')
        .select()
        .inFilter('id', userIds);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// Uploads to a fixed per-user path (overwriting any previous photo) and
  /// returns a cache-busted public URL.
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
  }) async {
    final path = '$userId/avatar.jpg';
    await _client.storage
        .from(_avatarBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
    final url = _client.storage.from(_avatarBucket).getPublicUrl(path);
    return '$url?t=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> updateAvatarUrl({
    required String userId,
    required String avatarUrl,
  }) async {
    await _client.auth.updateUser(
      UserAttributes(data: {'avatar_url': avatarUrl}),
    );
    await _client
        .from('users')
        .update({'avatar_url': avatarUrl})
        .eq('id', userId);
  }

  Future<void> updateProfileRow({
    required String userId,
    required String fullName,
    required String email,
    String? phone,
    String? bio,
  }) {
    return _client
        .from('users')
        .update({
          'full_name': fullName,
          'email': email,
          'phone': phone,
          'bio': bio,
        })
        .eq('id', userId);
  }

  /// Updates the auth account itself: full_name metadata always, and email
  /// only when it changed (Supabase then emails a confirmation link before
  /// the login email actually switches over).
  Future<void> updateAuthUser({required String fullName, String? newEmail}) {
    return _client.auth.updateUser(
      UserAttributes(email: newEmail, data: {'full_name': fullName}),
    );
  }
}
