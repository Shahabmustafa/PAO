import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/utils/auth_error_message.dart';
import '../../data/repository/auth_repository.dart';

/// Backs the screen the user lands on after tapping the link in the
/// "reset your password" email.
class ResetPasswordProvider extends ChangeNotifier {
  ResetPasswordProvider({AuthRepository? repository})
    : _repository = repository ?? AuthRepository();

  final AuthRepository _repository;

  bool isLoading = false;
  String? errorMessage;

  Future<bool> updatePassword(String newPassword) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _repository.updatePassword(newPassword);
      return true;
    } on AuthException catch (e) {
      errorMessage = authErrorMessage(e);
      return false;
    } catch (_) {
      errorMessage = l10nNow.somethingWentWrong;
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Abandons the reset: the recovery link already signed the user in, so
  /// this signs them back out.
  Future<void> cancel() async {
    try {
      await _repository.logout();
    } catch (_) {
      // Nothing useful to do; the user is sent to the login screen anyway.
    }
  }
}
