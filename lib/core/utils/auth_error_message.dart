import 'package:supabase_flutter/supabase_flutter.dart';
import '../l10n/l10n.dart';

/// Maps a Supabase [AuthException] to a message safe to show the user, in
/// the currently selected app language.
///
/// [AuthRetryableFetchException] is thrown when the request never reached
/// the server (e.g. no internet) — its `message` is the raw underlying
/// exception's `toString()` (like "ClientException with SocketException:
/// Failed host lookup..."), so it needs a friendly replacement instead of
/// being shown as-is. Well-known server error codes are translated too;
/// anything else falls back to the server's own (English) message.
String authErrorMessage(AuthException error) {
  final l10n = l10nNow;
  if (error is AuthRetryableFetchException) return l10n.noInternet;
  switch (error.code) {
    case 'invalid_credentials':
      return l10n.errorInvalidCredentials;
    case 'user_already_exists':
    case 'email_exists':
      return l10n.errorUserAlreadyExists;
    case 'email_not_confirmed':
      return l10n.errorEmailNotConfirmed;
    case 'weak_password':
      return l10n.errorWeakPassword;
    case 'same_password':
      return l10n.errorSamePassword;
    case 'over_request_rate_limit':
    case 'over_email_send_rate_limit':
      return l10n.errorRateLimited;
  }
  return error.message;
}
