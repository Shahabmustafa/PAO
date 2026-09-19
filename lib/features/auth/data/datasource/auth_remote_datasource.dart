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

  /// Permanently deletes the signed-in user's account via the
  /// `delete_user` RPC (see supabase/delete_account_function.sql), which
  /// cascades to remove all of their data, then clears the local session.
  Future<void> deleteAccount() async {
    await _client.rpc('delete_user');
    await _client.auth.signOut();
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
