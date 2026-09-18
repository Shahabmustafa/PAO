import 'package:flutter/foundation.dart';
import '../../../add_item/data/repository/post_repository.dart';
import '../../../auth/data/repository/auth_repository.dart';
import '../../../feedback/data/repository/feedback_repository.dart';
import '../../../settings/data/model/profile_model.dart';
import '../../../settings/data/repository/profile_repository.dart';
import '../../data/model/request_model.dart';
import '../../data/request_store.dart';

class RequestTileProvider extends ChangeNotifier {
  RequestTileProvider({
    required this.request,
    required this.otherUserId,
    required this.isSentTab,
    this.productName,
    this.productImageUrl,
    ProfileRepository? profileRepository,
    FeedbackRepository? feedbackRepository,
    PostRepository? postRepository,
    AuthRepository? authRepository,
  })  : _profileRepository = profileRepository ?? ProfileRepository(),
        _feedbackRepository = feedbackRepository ?? FeedbackRepository(),
        _postRepository = postRepository ?? PostRepository(),
        _authRepository = authRepository ?? AuthRepository() {
    _loadProfile();
    if (productName == null) _loadProduct();
    if (isSentTab && request.isAccepted) _checkFeedback();
  }

  final RequestModel request;
  final String otherUserId;
  final bool isSentTab;

  final ProfileRepository _profileRepository;
  final FeedbackRepository _feedbackRepository;
  final PostRepository _postRepository;
  final AuthRepository _authRepository;

  ProfileModel? profile;
  bool isLoadingProfile = true;

  String? productName;
  String? productImageUrl;
  bool isLoadingProduct = false;

  bool feedbackGiven = false;
  bool isAccepting = false;
  String? errorMessage;

  String? get currentUserId => _authRepository.currentUser?.id;

  Future<void> _loadProfile() async {
    try {
      profile = await _profileRepository.fetchPublicProfile(otherUserId);
    } catch (_) {
      // Keep the fallback name.
    } finally {
      isLoadingProfile = false;
      notifyListeners();
    }
  }

  Future<void> _loadProduct() async {
    isLoadingProduct = true;
    notifyListeners();
    try {
      final post = await _postRepository.fetchPostById(request.postId);
      productName = post?.title ?? 'PAO item';
      productImageUrl =
          post != null && post.imageUrls.isNotEmpty ? post.imageUrls.first : null;
    } catch (_) {
      productName = 'PAO item';
    } finally {
      isLoadingProduct = false;
      notifyListeners();
    }
  }

  Future<void> _checkFeedback() async {
    try {
      final feedback = await _feedbackRepository.fetchForRequest(request.id);
      feedbackGiven = feedback != null;
      notifyListeners();
    } catch (_) {
      // Leave the button visible; worst case they're asked again.
    }
  }

  Future<bool> accept() async {
    isAccepting = true;
    errorMessage = null;
    notifyListeners();
    try {
      await RequestStore.accept(request);
      return true;
    } catch (_) {
      errorMessage = 'Failed to update. Please try again.';
      return false;
    } finally {
      isAccepting = false;
      notifyListeners();
    }
  }

  void markFeedbackGiven() {
    feedbackGiven = true;
    notifyListeners();
  }
}
