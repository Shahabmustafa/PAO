import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Supabase project credentials, loaded from the untracked `.env` file at
/// the project root (see `.env.example`). Call `dotenv.load()` in `main()`
/// before reading these.
class SupabaseConfig {
  SupabaseConfig._();

  static String get url => dotenv.env['SUPABASE_URL'] ?? '';

  static String get anonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  /// OAuth client IDs for Google sign-in (Google Cloud Console). The web
  /// client ID is required on Android and is also the one enabled in
  /// Supabase > Authentication > Providers > Google; the iOS one is only
  /// needed on iOS.
  static String get googleWebClientId =>
      dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '';

  static String? get googleIosClientId {
    final id = dotenv.env['GOOGLE_IOS_CLIENT_ID'];
    return id == null || id.isEmpty ? null : id;
  }

  /// Where the "reset your password" email link sends the user: a deep link
  /// back into this app (scheme = the app id). It must also be listed under
  /// Authentication > URL Configuration > Redirect URLs in the Supabase
  /// dashboard, or Supabase falls back to its Site URL.
  static const String passwordResetRedirectUrl =
      'com.pao.pao://reset-callback/';
}
