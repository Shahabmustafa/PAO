import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/auth_error_message.dart';
import '../../data/repository/auth_repository.dart';

class ForgotPasswordProvider extends ChangeNotifier {
  ForgotPasswordProvider({AuthRepository? repository})
    : _repository = repository ?? AuthRepository();

  final AuthRepository _repository;

  bool isLoading = false;
  String? errorMessage;
  bool emailSent = false;

  Future<void> sendResetEmail(String email) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _repository.sendPasswordResetEmail(email);
      emailSent = true;
    } on AuthException catch (e) {
      errorMessage = authErrorMessage(e);
    } catch (_) {
      errorMessage = 'Something went wrong. Please try again.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
