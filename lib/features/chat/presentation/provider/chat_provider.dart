import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../auth/data/repository/auth_repository.dart';
import '../../../feedback/data/repository/feedback_repository.dart';
import '../../../requests/data/model/request_model.dart';
import '../../../requests/data/request_store.dart';
import '../../../settings/data/model/profile_model.dart';
import '../../../settings/data/repository/profile_repository.dart';
import '../../data/model/message_model.dart';
import '../../data/repository/chat_repository.dart';

class ChatProvider extends ChangeNotifier {
  ChatProvider({
    required this.request,
    required this.otherUserId,
    ChatRepository? repository,
    AuthRepository? authRepository,
    ProfileRepository? profileRepository,
    FeedbackRepository? feedbackRepository,
  })  : _repository = repository ?? ChatRepository(),
        _authRepository = authRepository ?? AuthRepository(),
        _profileRepository = profileRepository ?? ProfileRepository(),
        _feedbackRepository = feedbackRepository ?? FeedbackRepository() {
    _subscribe();
    _loadOtherProfile();
    if (isRequester && request.isAccepted) _checkFeedback();
  }

  RequestModel request;
  final String otherUserId;
  final ChatRepository _repository;
  final AuthRepository _authRepository;
  final ProfileRepository _profileRepository;
  final FeedbackRepository _feedbackRepository;

  List<MessageModel> messages = [];
  bool isLoading = true;
  bool isSending = false;
  String? errorMessage;
  StreamSubscription<List<MessageModel>>? _subscription;

  ProfileModel? otherProfile;
  bool isLoadingProfile = true;
  bool isAccepting = false;
  bool feedbackGiven = false;

  String? get currentUserId => _authRepository.currentUser?.id;
  bool get isOwner => request.ownerId == currentUserId;
  bool get isRequester => request.requesterId == currentUserId;

  void _subscribe() {
    _subscription = _repository.streamMessages(request.id).listen(
      (data) {
        messages = data;
        isLoading = false;
        notifyListeners();
      },
      onError: (_) {
        errorMessage = 'Failed to load messages.';
        isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> _loadOtherProfile() async {
    try {
      otherProfile = await _profileRepository.fetchPublicProfile(otherUserId);
    } catch (_) {
      // Keep the fallback name/avatar if the profile fails to load.
    } finally {
      isLoadingProfile = false;
      notifyListeners();
    }
  }

  Future<void> _checkFeedback() async {
    try {
      final feedback = await _feedbackRepository.fetchForRequest(request.id);
      feedbackGiven = feedback != null;
      notifyListeners();
    } catch (_) {
      // Leave the banner visible; worst case they're asked again.
    }
  }

  Future<bool> acceptRequest() async {
    isAccepting = true;
    errorMessage = null;
    notifyListeners();
    try {
      await RequestStore.accept(request);
      request = request.copyWith(status: 'accepted');
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

  Future<void> sendMessage(String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;
    final senderId = currentUserId;
    if (senderId == null) return;

    isSending = true;
    notifyListeners();
    try {
      await _repository.sendMessage(
        requestId: request.id,
        senderId: senderId,
        body: trimmed,
      );
    } catch (_) {
      errorMessage = 'Failed to send message.';
    } finally {
      isSending = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
