import 'package:flutter/foundation.dart';
import '../../../auth/data/repository/auth_repository.dart';
import '../../data/model/post_model.dart';
import '../../data/repository/post_repository.dart';
import '../../../../core/l10n/l10n.dart';

class AddItemProvider extends ChangeNotifier {
  AddItemProvider({PostRepository? repository, AuthRepository? authRepository})
    : _repository = repository ?? PostRepository(),
      _authRepository = authRepository ?? AuthRepository();

  final PostRepository _repository;
  final AuthRepository _authRepository;

  bool isLoading = false;
  String? errorMessage;

  Future<PostModel?> submit({
    required String title,
    required String description,
    required String category,
    required String condition,
    required String address,
    required List<Uint8List> images,
  }) async {
    final userId = _authRepository.currentUser?.id;
    if (userId == null) {
      errorMessage = l10nNow.mustBeLoggedInToPost;
      notifyListeners();
      return null;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      return await _repository.createPost(
        userId: userId,
        title: title,
        description: description,
        category: category,
        condition: condition,
        address: address,
        images: images,
      );
    } catch (_) {
      errorMessage = l10nNow.somethingWentWrong;
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<PostModel?> update({
    required String postId,
    required String title,
    required String description,
    required String category,
    required String condition,
    required String address,
    required List<String> keptImageUrls,
    required List<Uint8List> newImages,
    List<String> removedImageUrls = const [],
  }) async {
    final userId = _authRepository.currentUser?.id;
    if (userId == null) {
      errorMessage = l10nNow.mustBeLoggedInToPost;
      notifyListeners();
      return null;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      return await _repository.updatePost(
        postId: postId,
        userId: userId,
        title: title,
        description: description,
        category: category,
        condition: condition,
        address: address,
        keptImageUrls: keptImageUrls,
        newImages: newImages,
        removedImageUrls: removedImageUrls,
      );
    } catch (_) {
      errorMessage = l10nNow.failedToUpdate;
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
