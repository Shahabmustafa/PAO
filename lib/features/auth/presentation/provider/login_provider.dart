import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/auth_error_message.dart';
import '../../data/repository/auth_repository.dart';

class LoginProvider extends ChangeNotifier {
  LoginProvider({AuthRepository? repository})
    : _repository = repository ?? AuthRepository();

  final AuthRepository _repository;

  bool isLoading = false;
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
      errorMessage = 'Something went wrong. Please try again.';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
