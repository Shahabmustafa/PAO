import 'package:google_sign_in/google_sign_in.dart';
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

  static bool _googleInitialized = false;

  /// Native Google sign-in, exchanged for a Supabase session. Google
  /// accounts that don't exist yet are created on first use, so this one
  /// call serves both "sign in" and "sign up". Returns `null` if the user
  /// dismissed the account picker.
  Future<AuthResponse?> signInWithGoogle() async {
    final google = GoogleSignIn.instance;
    if (!_googleInitialized) {
      await google.initialize(
        clientId: SupabaseConfig.googleIosClientId,
        serverClientId: SupabaseConfig.googleWebClientId,
      );
      _googleInitialized = true;
    }

    final GoogleSignInAccount account;
    try {
      account = await google.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthException('No ID token from Google.');
    }
    final response = await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
    final user = response.user;
    if (user != null) await _syncProfileWithAuth(user);
    return response;
  }

  /// Supabase rewrites `avatar_url` / `full_name` in the auth metadata with
  /// Google's values on every Google sign-in, while the profile screen reads
  /// the `users` row, so the two are brought back in line here. Google's
  /// photo wins (it's copied into the row); for the name, whatever the user
  /// saved in the row wins and is put back into the metadata. Anything the
  /// row is missing is filled from Google.
  /// Best-effort: a failure here must not block signing in.
  Future<void> _syncProfileWithAuth(User user) async {
    try {
      final row = await _client
          .from('users')
          .select('full_name, avatar_url')
          .eq('id', user.id)
          .maybeSingle();
      if (row == null) return;

      final restoreMeta = <String, dynamic>{};
      final fillRow = <String, dynamic>{};
      for (final key in const ['full_name', 'avatar_url']) {
        final saved = row[key] as String?;
        final fromGoogle = user.userMetadata?[key] as String?;
        final hasSaved = saved != null && saved.isNotEmpty;
        final hasGoogle = fromGoogle != null && fromGoogle.isNotEmpty;
        if (saved == fromGoogle) continue;
        if (hasGoogle && (key == 'avatar_url' || !hasSaved)) {
          fillRow[key] = fromGoogle;
        } else if (hasSaved) {
          restoreMeta[key] = saved;
        }
      }

      if (restoreMeta.isNotEmpty) {
        await _client.auth.updateUser(UserAttributes(data: restoreMeta));
      }
      if (fillRow.isNotEmpty) {
        await _client.from('users').update(fillRow).eq('id', user.id);
      }
    } catch (_) {}
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }

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
    await signOut();
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
