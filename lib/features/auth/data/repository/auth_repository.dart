import 'package:supabase_flutter/supabase_flutter.dart';
import '../datasource/auth_remote_datasource.dart';
import '../model/user_model.dart';

/// Bridges the auth data source and the presentation layer: turns raw
/// Supabase responses into [UserModel]s the rest of the app understands.
class AuthRepository {
  AuthRepository({AuthRemoteDataSource? dataSource})
    : _dataSource = dataSource ?? AuthRemoteDataSource();

  final AuthRemoteDataSource _dataSource;

  UserModel? get currentUser {
    final user = _dataSource.currentUser;
    return user == null ? null : UserModel.fromSupabaseUser(user);
  }

  bool get isLoggedIn => _dataSource.currentUser != null;

  Stream<AuthState> get authStateChanges => _dataSource.authStateChanges;

  Future<UserModel?> login({
    required String email,
    required String password,
  }) async {
    final response = await _dataSource.signIn(email: email, password: password);
    final user = response.user;
    if (user == null) return null;
    if (await _dataSource.isBanned(user.id)) {
      await _dataSource.signOut();
      throw AuthException(
        'Your account has been suspended.',
        code: 'account_banned',
      );
    }
    return UserModel.fromSupabaseUser(user);
  }

  /// Returns the created [UserModel], or `null` when email confirmation is
  /// required before a session is issued.
  Future<UserModel?> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final response = await _dataSource.signUp(
      fullName: fullName,
      email: email,
      password: password,
    );
    if (response.session == null) return null;
    final user = response.user;
    return user == null ? null : UserModel.fromSupabaseUser(user);
  }

  Future<void> logout() => _dataSource.signOut();

  Future<void> deleteAccount() => _dataSource.deleteAccount();

  Future<void> sendPasswordResetEmail(String email) {
    return _dataSource.resetPassword(email);
  }

  Future<void> updatePassword(String newPassword) {
    return _dataSource.updatePassword(newPassword);
  }
}
