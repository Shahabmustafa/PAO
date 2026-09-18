import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/auth_error_message.dart';
import '../../data/repository/auth_repository.dart';

enum SignupResult { success, needsEmailConfirmation, failure }

class SignupProvider extends ChangeNotifier {
  SignupProvider({AuthRepository? repository})
    : _repository = repository ?? AuthRepository();

  final AuthRepository _repository;

  bool isLoading = false;
  String? errorMessage;

  Future<SignupResult> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final user = await _repository.register(
        fullName: fullName,
        email: email,
        password: password,
      );
      return user != null
          ? SignupResult.success
          : SignupResult.needsEmailConfirmation;
    } on AuthException catch (e) {
      errorMessage = authErrorMessage(e);
      return SignupResult.failure;
    } catch (_) {
      errorMessage = 'Something went wrong. Please try again.';
      return SignupResult.failure;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
