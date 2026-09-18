import 'package:flutter/foundation.dart';
import '../../../add_item/data/repository/post_repository.dart';
import '../../../auth/data/repository/auth_repository.dart';
import '../../../requests/data/request_store.dart';
import '../../../settings/data/model/profile_model.dart';
import '../../../settings/data/repository/profile_repository.dart';
import '../../data/product_store.dart';
import '../../domain/product.dart';

class ProductDetailProvider extends ChangeNotifier {
  ProductDetailProvider({
    required this.product,
    AuthRepository? authRepository,
    PostRepository? postRepository,
    ProfileRepository? profileRepository,
  })  : _authRepository = authRepository ?? AuthRepository(),
        _postRepository = postRepository ?? PostRepository(),
        _profileRepository = profileRepository ?? ProfileRepository() {
    _loadPosterProfile();
  }

  final Product product;
  final AuthRepository _authRepository;
  final PostRepository _postRepository;
  final ProfileRepository _profileRepository;

  bool isLoadingPoster = true;
  bool isMarkingGiven = false;
  bool isRequesting = false;
  ProfileModel? posterProfile;
  String? errorMessage;

  bool get isOwner =>
      product.userId != null &&
      product.userId == _authRepository.currentUser?.id;

  Future<void> _loadPosterProfile() async {
    final userId = product.userId;
    if (userId == null) {
      isLoadingPoster = false;
      notifyListeners();
      return;
    }
    try {
      posterProfile = await _profileRepository.fetchPublicProfile(userId);
    } catch (_) {
      // Keep the fallback name/avatar if the profile fails to load.
    } finally {
      isLoadingPoster = false;
      notifyListeners();
    }
  }

  Future<bool> sendRequest() async {
    final ownerId = product.userId;
    if (ownerId == null) return false;

    if (isOwner) {
      errorMessage = "You can't request your own item.";
      notifyListeners();
      return false;
    }

    isRequesting = true;
    errorMessage = null;
    notifyListeners();
    try {
      final request = await RequestStore.send(
        postId: product.id,
        ownerId: ownerId,
      );
      if (request == null) {
        errorMessage = 'Failed to send request. Please try again.';
        return false;
      }
      return true;
    } catch (_) {
      errorMessage = 'Failed to send request. Please try again.';
      return false;
    } finally {
      isRequesting = false;
      notifyListeners();
    }
  }

  Future<bool> markAsGiven() async {
    isMarkingGiven = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _postRepository.markAsGiven(product.id);
      ProductStore.markAsGiven(product.id);
      return true;
    } catch (_) {
      errorMessage = 'Failed to update. Please try again.';
      return false;
    } finally {
      isMarkingGiven = false;
      notifyListeners();
    }
  }
}
