import 'dart:typed_data';
import '../../../../core/cache/local_cache.dart';
import '../datasource/profile_remote_datasource.dart';
import '../model/profile_model.dart';

/// Bridges the profile data source and the presentation layer.
class ProfileRepository {
  ProfileRepository({ProfileRemoteDataSource? dataSource})
    : _dataSource = dataSource ?? ProfileRemoteDataSource();

  final ProfileRemoteDataSource _dataSource;

  Future<String> uploadAndSetAvatar({
    required String userId,
    required Uint8List bytes,
  }) async {
    final url = await _dataSource.uploadAvatar(userId: userId, bytes: bytes);
    await _dataSource.updateAvatarUrl(userId: userId, avatarUrl: url);
    return url;
  }

  Future<ProfileModel?> fetchProfile(String userId) async {
    final row = await _dataSource.fetchProfile(userId);
    return row == null ? null : ProfileModel.fromJson(row);
  }

  /// The last public profile fetched for [userId] (name, avatar, last
  /// seen, bio) straight from the local cache, or null.
  ProfileModel? cachedPublicProfile(String userId) {
    final json = LocalCache.readMap(LocalCache.profiles, userId);
    if (json == null) return null;
    try {
      return ProfileModel.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<ProfileModel?> fetchPublicProfile(String userId) async {
    final row = await _dataSource.fetchPublicProfile(userId);
    if (row == null) return null;
    final profile = ProfileModel.fromJson(row);
    LocalCache.write(LocalCache.profiles, userId, profile.toCacheJson());
    return profile;
  }

  /// Returns a map of user id -> profile for a batch of ids, so callers can
  /// look up each one without a per-row network call.
  Future<Map<String, ProfileModel>> fetchPublicProfiles(
    List<String> userIds,
  ) async {
    final rows = await _dataSource.fetchPublicProfiles(userIds);
    final profiles = rows.map(ProfileModel.fromJson).toList();
    for (final profile in profiles) {
      LocalCache.write(LocalCache.profiles, profile.id, profile.toCacheJson());
    }
    return {for (final profile in profiles) profile.id: profile};
  }

  /// Updates full_name (and email, if changed) on the auth account, then
  /// mirrors the editable fields onto the public profile row.
  Future<void> saveProfile({
    required String userId,
    required String fullName,
    required String email,
    required String currentEmail,
    String? phone,
    String? bio,
  }) async {
    final emailChanged = email != currentEmail;
    await _dataSource.updateAuthUser(
      fullName: fullName,
      newEmail: emailChanged ? email : null,
    );
    await _dataSource.updateProfileRow(
      userId: userId,
      fullName: fullName,
      email: email,
      phone: phone,
      bio: bio,
    );
  }
}
