import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/supabase_config.dart';

/// Talks directly to Supabase auth. No app logic here — the repository
/// is the layer that interprets responses.
class AuthRemoteDataSource {
  AuthRemoteDataSource({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUp({
    required String fullName,
    required String email,
    required String password,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  /// Whether an admin has flagged this account banned (see
  /// `supabase/users_add_role.sql`). RLS only lets an account read its own
  /// `is_banned`, so this is only meaningful for the signed-in user.
  Future<bool> isBanned(String userId) async {
    final row = await _client
        .from('users')
        .select('is_banned')
        .eq('id', userId)
        .maybeSingle();
    return row?['is_banned'] == true;
  }

  /// Permanently deletes the signed-in user's account via the
  /// `delete_user` RPC (see supabase/delete_account_function.sql), which
  /// cascades to remove all of their data, then clears the local session.
  Future<void> deleteAccount() async {
    await _removeChatMedia();
    await _client.rpc('delete_user');
    await _client.auth.signOut();
  }

  /// Deletes the photos / videos / voice notes this user sent. The cascade
  /// in `delete_user` removes their message rows but not storage files.
  /// Best-effort: a failure here must not block deleting the account.
  Future<void> _removeChatMedia() async {
    final userId = currentUser?.id;
    if (userId == null) return;
    try {
      final bucket = _client.storage.from('chat_media');
      final files = await bucket.list(
        path: userId,
        searchOptions: const SearchOptions(limit: 1000),
      );
      if (files.isEmpty) return;
      await bucket.remove([for (final f in files) '$userId/${f.name}']);
    } catch (_) {}
  }

  Future<void> resetPassword(String email) {
    return _client.auth.resetPasswordForEmail(
      email,
      redirectTo: SupabaseConfig.passwordResetRedirectUrl,
    );
  }

  /// Sets a new password for the signed-in user (which, after following a
  /// reset-password email link, is the temporary recovery session).
  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }
}
