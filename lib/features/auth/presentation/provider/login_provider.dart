import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/auth_error_message.dart';
import '../../data/repository/auth_repository.dart';
import '../../../../core/l10n/l10n.dart';

class LoginProvider extends ChangeNotifier {
  LoginProvider({AuthRepository? repository})
    : _repository = repository ?? AuthRepository();

  final AuthRepository _repository;

  bool isLoading = false;

  /// Google sign-in in flight; shown on the Google button only.
  bool isGoogleLoading = false;
  String? errorMessage;

  Future<bool> login({required String email, required String password}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _repository.login(email: email, password: password);
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

  /// Returns true when signed in, false on failure or if the user cancelled
  /// (in which case [errorMessage] stays null).
  Future<bool> loginWithGoogle() async {
    isGoogleLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final user = await _repository.loginWithGoogle();
      return user != null;
    } on AuthException catch (e) {
      errorMessage = authErrorMessage(e);
      return false;
    } catch (_) {
      errorMessage = l10nNow.somethingWentWrong;
      return false;
    } finally {
      isGoogleLoading = false;
      notifyListeners();
    }
  }
}
