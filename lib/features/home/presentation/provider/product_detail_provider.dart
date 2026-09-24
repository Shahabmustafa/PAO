import 'package:flutter/foundation.dart';
import '../../../add_item/data/repository/post_repository.dart';
import '../../../auth/data/repository/auth_repository.dart';
import '../../../requests/data/request_store.dart';
import '../../../settings/data/model/profile_model.dart';
import '../../../settings/data/repository/profile_repository.dart';
import '../../data/product_store.dart';
import '../../domain/product.dart';
import '../../../../core/l10n/l10n.dart';

class ProductDetailProvider extends ChangeNotifier {
  ProductDetailProvider({
    required this.product,
    AuthRepository? authRepository,
    PostRepository? postRepository,
    ProfileRepository? profileRepository,
  }) : _authRepository = authRepository ?? AuthRepository(),
       _postRepository = postRepository ?? PostRepository(),
       _profileRepository = profileRepository ?? ProfileRepository() {
    // The cached product is already on screen; refresh it (and the
    // poster) in the background. A changed post reaches the screen through
    // ProductStore.
    _loadPosterProfile();
    ProductStore.refreshOne(product.id, repository: postRepository);
  }

  final Product product;
  final AuthRepository _authRepository;
  final PostRepository _postRepository;
  final ProfileRepository _profileRepository;

  bool isLoadingPoster = true;
  bool isMarkingGiven = false;
  bool isRequesting = false;
  bool isDeleting = false;
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
    final cached = _profileRepository.cachedPublicProfile(userId);
    if (cached != null) {
      posterProfile = cached;
      isLoadingPoster = false;
      notifyListeners();
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
      errorMessage = l10nNow.cantRequestOwnItem;
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
        errorMessage = l10nNow.failedToSendRequest;
        return false;
      }
      return true;
    } catch (_) {
      errorMessage = l10nNow.failedToSendRequest;
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
      errorMessage = l10nNow.failedToUpdate;
      return false;
    } finally {
      isMarkingGiven = false;
      notifyListeners();
    }
  }

  /// Deletes this post for good (owner only) and forgets it locally.
  Future<bool> deleteProduct() async {
    if (!isOwner) return false;
    isDeleting = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _postRepository.deletePost(
        product.id,
        imageUrls: product.imageUrls,
      );
      ProductStore.remove(product.id);
      RequestStore.removeForPost(product.id);
      return true;
    } catch (_) {
      errorMessage = l10nNow.failedToDeleteProduct;
      return false;
    } finally {
      isDeleting = false;
      notifyListeners();
    }
  }
}
