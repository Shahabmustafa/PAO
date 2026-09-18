import 'package:flutter/foundation.dart';
import '../../../auth/data/repository/auth_repository.dart';
import '../../data/model/post_model.dart';
import '../../data/repository/post_repository.dart';

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
    required List<Uint8List> images,
  }) async {
    final userId = _authRepository.currentUser?.id;
    if (userId == null) {
      errorMessage = 'You must be logged in to post an item.';
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
        images: images,
      );
    } catch (_) {
      errorMessage = 'Something went wrong. Please try again.';
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
