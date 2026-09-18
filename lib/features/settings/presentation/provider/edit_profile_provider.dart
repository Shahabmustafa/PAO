import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/auth_error_message.dart';
import '../../../auth/data/repository/auth_repository.dart';
import '../../data/model/profile_model.dart';
import '../../data/repository/profile_repository.dart';

class EditProfileProvider extends ChangeNotifier {
  EditProfileProvider({
    ProfileRepository? repository,
    AuthRepository? authRepository,
  }) : _repository = repository ?? ProfileRepository(),
       _authRepository = authRepository ?? AuthRepository();

  final ProfileRepository _repository;
  final AuthRepository _authRepository;

  bool isLoading = false;
  bool isSaving = false;
  bool isUploadingAvatar = false;
  String? errorMessage;
  bool emailChangeNeedsConfirmation = false;
  String? avatarUrl;

  Future<ProfileModel?> loadProfile() async {
    avatarUrl = _authRepository.currentUser?.avatarUrl;
    final userId = _authRepository.currentUser?.id;
    if (userId == null) return null;

    isLoading = true;
    notifyListeners();
    try {
      final profile = await _repository.fetchProfile(userId);
      if (profile?.avatarUrl != null) avatarUrl = profile!.avatarUrl;
      return profile;
    } catch (_) {
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> uploadAvatar(Uint8List bytes) async {
    final userId = _authRepository.currentUser?.id;
    if (userId == null) {
      errorMessage = 'You must be logged in to update your photo.';
      notifyListeners();
      return;
    }

    isUploadingAvatar = true;
    errorMessage = null;
    notifyListeners();
    try {
      avatarUrl = await _repository.uploadAndSetAvatar(
        userId: userId,
        bytes: bytes,
      );
    } catch (_) {
      errorMessage = 'Failed to update photo. Please try again.';
    } finally {
      isUploadingAvatar = false;
      notifyListeners();
    }
  }

  Future<bool> save({
    required String fullName,
    required String email,
    String? phone,
    String? bio,
  }) async {
    final userId = _authRepository.currentUser?.id;
    if (userId == null) {
      errorMessage = 'You must be logged in to update your profile.';
      notifyListeners();
      return false;
    }

    final currentEmail = _authRepository.currentUser?.email ?? '';
    isSaving = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _repository.saveProfile(
        userId: userId,
        fullName: fullName,
        email: email,
        currentEmail: currentEmail,
        phone: phone,
        bio: bio,
      );
      emailChangeNeedsConfirmation = email != currentEmail;
      return true;
    } on AuthException catch (e) {
      errorMessage = authErrorMessage(e);
      return false;
    } catch (_) {
      errorMessage = 'Something went wrong. Please try again.';
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
