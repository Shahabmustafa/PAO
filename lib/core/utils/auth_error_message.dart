import 'package:supabase_flutter/supabase_flutter.dart';

/// Maps a Supabase [AuthException] to a message safe to show the user.
///
/// [AuthRetryableFetchException] is thrown when the request never reached
/// the server (e.g. no internet) — its `message` is the raw underlying
/// exception's `toString()` (like "ClientException with SocketException:
/// Failed host lookup..."), so it needs a friendly replacement instead of
/// being shown as-is.
String authErrorMessage(AuthException error) {
  if (error is AuthRetryableFetchException) {
    return 'No internet connection. Please check your network and try again.';
  }
  return error.message;
}
