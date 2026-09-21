// Hand-written fakes for the repository and data-source layers.
//
// The production classes are concrete (no interfaces), so each fake
// `implements` the real class: no constructor runs, which means no
// Supabase client is ever touched.
import 'dart:async';
import 'dart:typed_data';

import 'package:pao/core/realtime/realtime_event.dart';
import 'package:pao/features/add_item/data/datasource/post_remote_datasource.dart';
import 'package:pao/features/add_item/data/model/post_model.dart';
import 'package:pao/features/add_item/data/repository/post_repository.dart';
import 'package:pao/features/auth/data/datasource/auth_remote_datasource.dart';
import 'package:pao/features/auth/data/model/user_model.dart';
import 'package:pao/features/auth/data/repository/auth_repository.dart';
import 'package:pao/features/chat/data/datasource/chat_remote_datasource.dart';
import 'package:pao/features/chat/data/model/message_model.dart';
import 'package:pao/features/chat/data/repository/chat_repository.dart';
import 'package:pao/features/feedback/data/datasource/feedback_remote_datasource.dart';
import 'package:pao/features/feedback/data/model/feedback_model.dart';
import 'package:pao/features/feedback/data/repository/feedback_repository.dart';
import 'package:pao/features/requests/data/datasource/request_remote_datasource.dart';
import 'package:pao/features/requests/data/model/request_model.dart';
import 'package:pao/features/requests/data/repository/request_repository.dart';
import 'package:pao/features/settings/data/datasource/profile_remote_datasource.dart';
import 'package:pao/features/settings/data/model/profile_model.dart';
import 'package:pao/features/settings/data/repository/profile_repository.dart';
import 'package:pao/features/wishlist/data/datasource/wishlist_remote_datasource.dart';
import 'package:pao/features/wishlist/data/model/wishlist_item_model.dart';
import 'package:pao/features/wishlist/data/repository/wishlist_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Sample data
// ---------------------------------------------------------------------------

final DateTime kCreatedAt = DateTime.utc(2026, 9, 18, 12, 30);

Map<String, dynamic> postJson({
  String id = 'post-1',
  String userId = 'owner-1',
  String title = 'Wireless Headphones',
  String? description = 'Barely used',
  String? category = 'Electronics',
  String? condition = 'Old',
  String? address = 'House 5, Street 2',
  List<String>? imageUrls = const ['https://img/1.png', 'https://img/2.png'],
  bool? isGiven = false,
}) => {
  'id': id,
  'user_id': userId,
  'title': title,
  'description': description,
  'category': category,
  'condition': condition,
  'address': address,
  'image_urls': imageUrls,
  'is_given': isGiven,
  'created_at': kCreatedAt.toIso8601String(),
};

Map<String, dynamic> requestJson({
  String id = 'req-1',
  String postId = 'post-1',
  String requesterId = 'requester-1',
  String ownerId = 'owner-1',
  String status = 'pending',
}) => {
  'id': id,
  'post_id': postId,
  'requester_id': requesterId,
  'owner_id': ownerId,
  'status': status,
  'created_at': kCreatedAt.toIso8601String(),
};

RequestModel makeRequest({
  String id = 'req-1',
  String postId = 'post-1',
  String requesterId = 'requester-1',
  String ownerId = 'owner-1',
  String status = 'pending',
}) => RequestModel.fromJson(
  requestJson(
    id: id,
    postId: postId,
    requesterId: requesterId,
    ownerId: ownerId,
    status: status,
  ),
);

PostModel makePost({
  String id = 'post-1',
  String userId = 'owner-1',
  String title = 'Wireless Headphones',
  String? category = 'Electronics',
  String condition = 'Old',
  List<String> imageUrls = const ['https://img/1.png'],
  bool isGiven = false,
}) => PostModel(
  id: id,
  userId: userId,
  title: title,
  createdAt: kCreatedAt,
  category: category,
  condition: condition,
  imageUrls: imageUrls,
  isGiven: isGiven,
);

MessageModel makeMessage({
  String id = 'msg-1',
  String requestId = 'req-1',
  String senderId = 'owner-1',
  String body = 'Hello',
}) => MessageModel(
  id: id,
  requestId: requestId,
  senderId: senderId,
  body: body,
  createdAt: kCreatedAt,
);

// Realtime events, as a repository delivers them.
RealtimeEvent<T> insertEvent<T>(String id, T record, {String tag = ''}) =>
    RealtimeEvent(
      type: RealtimeEventType.insert,
      id: id,
      record: record,
      tag: tag,
    );

RealtimeEvent<T> updateEvent<T>(String id, T record, {String tag = ''}) =>
    RealtimeEvent(
      type: RealtimeEventType.update,
      id: id,
      record: record,
      tag: tag,
    );

RealtimeEvent<T> deleteEvent<T>(String id) =>
    RealtimeEvent(type: RealtimeEventType.delete, id: id);

RealtimeEvent<T> subscribedEvent<T>({bool isReconnect = false}) =>
    RealtimeEvent(type: RealtimeEventType.subscribed, isReconnect: isReconnect);

RealtimeEvent<T> errorEvent<T>() =>
    const RealtimeEvent(type: RealtimeEventType.error);

const ProfileModel kOtherProfile = ProfileModel(
  id: 'owner-1',
  fullName: 'Ayesha Khan',
  avatarUrl: 'https://img/avatar.png',
);

// ---------------------------------------------------------------------------
// Repository fakes (used by providers and stores)
// ---------------------------------------------------------------------------

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.user});

  UserModel? user;
  Object? loginError;
  Object? registerError;
  Object? resetError;
  Object? updatePasswordError;
  bool registerNeedsConfirmation = false;

  final loginCalls = <({String email, String password})>[];
  final registerCalls = <({String fullName, String email, String password})>[];
  final resetCalls = <String>[];
  final updatePasswordCalls = <String>[];

  @override
  UserModel? get currentUser => user;

  @override
  bool get isLoggedIn => user != null;

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  Future<UserModel?> login({
    required String email,
    required String password,
  }) async {
    loginCalls.add((email: email, password: password));
    if (loginError != null) throw loginError!;
    return user ?? UserModel(id: 'u-login', email: email);
  }

  @override
  Future<UserModel?> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    registerCalls.add((fullName: fullName, email: email, password: password));
    if (registerError != null) throw registerError!;
    if (registerNeedsConfirmation) return null;
    return UserModel(id: 'u-new', email: email, fullName: fullName);
  }

  @override
  Future<void> logout() async => user = null;

  @override
  Future<void> deleteAccount() async => user = null;

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    resetCalls.add(email);
    if (resetError != null) throw resetError!;
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    updatePasswordCalls.add(newPassword);
    if (updatePasswordError != null) throw updatePasswordError!;
  }
}

class FakePostRepository implements PostRepository {
  Object? createError;
  Object? markGivenError;
  Object? fetchError;
  List<PostModel> available = [];
  Map<String, PostModel> byId = {};
  Map<String, List<PostModel>> postsByUser = {};
  int donatedCount = 0;
  StreamController<RealtimeEvent<PostModel>>? postsController;

  final createCalls = <Map<String, Object?>>[];
  final markedGiven = <String>[];

  Object? updateError;
  Object? deleteError;
  final updateCalls = <Map<String, Object?>>[];
  final deleteCalls = <Map<String, Object?>>[];

  @override
  Future<PostModel> updatePost({
    required String postId,
    required String userId,
    required String title,
    required String description,
    required String category,
    required String condition,
    required String address,
    required List<String> keptImageUrls,
    required List<Uint8List> newImages,
    List<String> removedImageUrls = const [],
  }) async {
    updateCalls.add({
      'postId': postId,
      'userId': userId,
      'title': title,
      'description': description,
      'category': category,
      'condition': condition,
      'address': address,
      'kept': keptImageUrls,
      'new': newImages.length,
      'removed': removedImageUrls,
    });
    if (updateError != null) throw updateError!;
    return makePost(
      id: postId,
      userId: userId,
      title: title,
      category: category,
      condition: condition,
    );
  }

  @override
  Future<void> deletePost(
    String postId, {
    List<String> imageUrls = const [],
  }) async {
    deleteCalls.add({'postId': postId, 'imageUrls': imageUrls});
    if (deleteError != null) throw deleteError!;
  }

  @override
  Future<void> markAsGiven(String postId) async {
    if (markGivenError != null) throw markGivenError!;
    markedGiven.add(postId);
  }

  @override
  Future<int> fetchDonatedCount(String userId) async => donatedCount;

  @override
  Future<List<PostModel>> fetchPostsByUser(String userId) async {
    if (fetchError != null) throw fetchError!;
    return postsByUser[userId] ?? const [];
  }

  @override
  Future<PostModel?> fetchPostById(String postId) async {
    if (fetchError != null) throw fetchError!;
    return byId[postId];
  }

  @override
  Future<List<PostModel>> fetchAvailablePosts() async {
    if (fetchError != null) throw fetchError!;
    return available;
  }

  /// Every call to [fetchAvailablePostsPage], for asserting on the query.
  final pageCalls =
      <
        ({
          int offset,
          int limit,
          String? excludeUserId,
          String? category,
          String? condition,
          String? search,
        })
      >[];

  /// Set to hold every page response until it completes.
  Completer<void>? pageGate;

  /// Thrown by [fetchAvailablePostsPage] while set.
  Object? pageError;

  /// Mimics the server: filters [available] with the same rules as the real
  /// query, then returns the requested slice.
  @override
  Future<List<PostModel>> fetchAvailablePostsPage({
    required int offset,
    required int limit,
    String? excludeUserId,
    String? category,
    String? condition,
    String? search,
  }) async {
    pageCalls.add((
      offset: offset,
      limit: limit,
      excludeUserId: excludeUserId,
      category: category,
      condition: condition,
      search: search,
    ));
    if (pageGate != null) await pageGate!.future;
    if (pageError != null) throw pageError!;
    return available
        .where((post) {
          if (post.isGiven) return false;
          if (excludeUserId != null && post.userId == excludeUserId) {
            return false;
          }
          if (category != null && (post.category ?? 'Other') != category) {
            return false;
          }
          if (condition != null && post.condition != condition) return false;
          if (search != null &&
              !post.title.toLowerCase().contains(search.toLowerCase())) {
            return false;
          }
          return true;
        })
        .skip(offset)
        .take(limit)
        .toList();
  }

  @override
  Stream<RealtimeEvent<PostModel>> watchPosts() =>
      (postsController ??=
              StreamController<RealtimeEvent<PostModel>>.broadcast())
          .stream;

  @override
  Future<PostModel> createPost({
    required String userId,
    required String title,
    required String description,
    required String category,
    required String condition,
    required String address,
    required List<Uint8List> images,
  }) async {
    createCalls.add({
      'userId': userId,
      'title': title,
      'description': description,
      'category': category,
      'condition': condition,
      'address': address,
      'images': images.length,
    });
    if (createError != null) throw createError!;
    return makePost(
      id: 'created-1',
      userId: userId,
      title: title,
      category: category,
      condition: condition,
    );
  }
}

class FakeRequestRepository implements RequestRepository {
  Object? createError;
  Object? acceptError;
  List<RequestModel> sent = [];
  List<RequestModel> received = [];
  StreamController<RealtimeEvent<RequestModel>>? eventsController;

  final createCalls = <({String postId, String requesterId, String ownerId})>[];
  final acceptCalls = <({String requestId, String postId})>[];
  final cancelCalls = <String>[];

  @override
  Future<RequestModel> createRequest({
    required String postId,
    required String requesterId,
    required String ownerId,
  }) async {
    createCalls.add((
      postId: postId,
      requesterId: requesterId,
      ownerId: ownerId,
    ));
    if (createError != null) throw createError!;
    return makeRequest(
      id: 'new-req',
      postId: postId,
      requesterId: requesterId,
      ownerId: ownerId,
    );
  }

  @override
  Future<List<RequestModel>> fetchSentRequests(String requesterId) async =>
      sent;

  @override
  Future<List<RequestModel>> fetchReceivedRequests(String ownerId) async =>
      received;

  @override
  Stream<RealtimeEvent<RequestModel>> watchRequests(String userId) =>
      (eventsController ??=
              StreamController<RealtimeEvent<RequestModel>>.broadcast())
          .stream;

  @override
  Future<void> cancelRequest(String requestId) async =>
      cancelCalls.add(requestId);

  @override
  Future<void> acceptRequest({
    required String requestId,
    required String postId,
  }) async {
    acceptCalls.add((requestId: requestId, postId: postId));
    if (acceptError != null) throw acceptError!;
  }
}

class FakeWishlistRepository implements WishlistRepository {
  Object? addError;
  Object? removeError;
  List<WishlistItemModel> remote = [];

  final added =
      <({String userId, String postId, String title, String? note})>[];
  final removed = <({String userId, String postId})>[];

  @override
  Future<List<WishlistItemModel>> fetchWishlist(String userId) async => remote;

  @override
  Future<void> addToWishlist({
    required String userId,
    required String postId,
    required String title,
    String? note,
  }) async {
    if (addError != null) throw addError!;
    added.add((userId: userId, postId: postId, title: title, note: note));
  }

  @override
  Future<void> removeFromWishlist({
    required String userId,
    required String postId,
  }) async {
    if (removeError != null) throw removeError!;
    removed.add((userId: userId, postId: postId));
  }
}

class FakeProfileRepository implements ProfileRepository {
  Object? fetchError;
  Object? saveError;
  Object? uploadError;
  ProfileModel? profile;
  ProfileModel? publicProfile;

  final saveCalls = <Map<String, Object?>>[];

  @override
  Future<String> uploadAndSetAvatar({
    required String userId,
    required Uint8List bytes,
  }) async {
    if (uploadError != null) throw uploadError!;
    return 'https://img/new-avatar.png';
  }

  @override
  Future<ProfileModel?> fetchProfile(String userId) async {
    if (fetchError != null) throw fetchError!;
    return profile;
  }

  @override
  Future<ProfileModel?> fetchPublicProfile(String userId) async {
    if (fetchError != null) throw fetchError!;
    return publicProfile;
  }

  @override
  Future<Map<String, ProfileModel>> fetchPublicProfiles(
    List<String> userIds,
  ) async => {};

  @override
  Future<void> saveProfile({
    required String userId,
    required String fullName,
    required String email,
    required String currentEmail,
    String? phone,
    String? bio,
  }) async {
    saveCalls.add({
      'userId': userId,
      'fullName': fullName,
      'email': email,
      'currentEmail': currentEmail,
      'phone': phone,
      'bio': bio,
    });
    if (saveError != null) throw saveError!;
  }
}

class FakeFeedbackRepository implements FeedbackRepository {
  FeedbackModel? existing;
  Object? fetchError;

  @override
  Future<FeedbackModel?> fetchForRequest(String requestId) async {
    if (fetchError != null) throw fetchError!;
    return existing;
  }

  @override
  Future<List<FeedbackModel>> fetchForUser(String userId) async => [];

  @override
  Future<void> submit({
    required String requestId,
    required String postId,
    required String fromUserId,
    required String toUserId,
    required int rating,
    String? comment,
  }) async {}
}

class FakeChatRepository implements ChatRepository {
  Object? sendError;
  Object? deleteError;
  Object? fetchError;
  List<MessageModel> history = [];
  int fetchCalls = 0;
  final deleted = <String>[];
  final controller = StreamController<RealtimeEvent<MessageModel>>.broadcast();
  final sent = <({String requestId, String senderId, String body})>[];

  @override
  Future<List<MessageModel>> fetchMessages(String requestId) async {
    fetchCalls++;
    if (fetchError != null) throw fetchError!;
    return history;
  }

  @override
  Stream<RealtimeEvent<MessageModel>> watchMessages(String requestId) =>
      controller.stream;

  @override
  Future<MessageModel> sendMessage({
    required String requestId,
    required String senderId,
    required String body,
  }) async {
    if (sendError != null) throw sendError!;
    sent.add((requestId: requestId, senderId: senderId, body: body));
    return makeMessage(
      id: 'sent-${sent.length}',
      requestId: requestId,
      senderId: senderId,
      body: body,
    );
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    if (deleteError != null) throw deleteError!;
    deleted.add(messageId);
  }
}

// ---------------------------------------------------------------------------
// Data-source fakes (used to test the repositories' mapping logic)
// ---------------------------------------------------------------------------

class FakeAuthDataSource implements AuthRemoteDataSource {
  User? user;
  AuthResponse? signInResponse;
  AuthResponse? signUpResponse;
  final calls = <String>[];

  @override
  User? get currentUser => user;

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    calls.add('signIn:$email');
    return signInResponse ?? AuthResponse();
  }

  @override
  Future<AuthResponse> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    calls.add('signUp:$fullName:$email');
    return signUpResponse ?? AuthResponse();
  }

  @override
  Future<void> signOut() async => calls.add('signOut');

  @override
  Future<void> deleteAccount() async => calls.add('deleteAccount');

  @override
  Future<void> resetPassword(String email) async =>
      calls.add('resetPassword:$email');

  @override
  Future<void> updatePassword(String newPassword) async =>
      calls.add('updatePassword:$newPassword');
}

User makeSupabaseUser({
  String id = 'user-1',
  String? email = 'a@b.com',
  Map<String, dynamic>? metadata,
}) => User(
  id: id,
  appMetadata: const {},
  userMetadata: metadata,
  aud: 'authenticated',
  createdAt: kCreatedAt.toIso8601String(),
  email: email,
);

class FakePostDataSource implements PostRemoteDataSource {
  final uploaded = <Uint8List>[];
  final createdWith = <Map<String, Object?>>[];
  final calls = <String>[];
  List<Map<String, dynamic>> rows = [];
  Map<String, dynamic>? row;
  int donated = 0;

  Object? deleteImagesError;
  final postEvents = StreamController<RealtimeEvent<Map<String, dynamic>>>();

  @override
  Stream<RealtimeEvent<Map<String, dynamic>>> watchPosts() => postEvents.stream;
  final updatedWith = <Map<String, Object?>>[];
  final deletedPosts = <String>[];
  final removedImages = <List<String>>[];

  @override
  Future<Map<String, dynamic>> updatePost({
    required String postId,
    required String title,
    required String description,
    required String category,
    required String condition,
    required String address,
    required List<String> imageUrls,
  }) async {
    updatedWith.add({
      'postId': postId,
      'title': title,
      'address': address,
      'imageUrls': imageUrls,
    });
    return postJson(
      id: postId,
      title: title,
      category: category,
      condition: condition,
      address: address,
      imageUrls: imageUrls,
    );
  }

  @override
  Future<void> deletePost(String postId) async {
    calls.add('deletePost:$postId');
    deletedPosts.add(postId);
  }

  @override
  Future<void> deleteImages(List<String> urls) async {
    calls.add('deleteImages');
    if (deleteImagesError != null) throw deleteImagesError!;
    removedImages.add(urls);
  }

  @override
  Future<String> uploadImage({
    required String userId,
    required Uint8List bytes,
  }) async {
    uploaded.add(bytes);
    return 'https://cdn/$userId/${uploaded.length}.png';
  }

  @override
  Future<void> markAsGiven(String postId) async =>
      calls.add('markAsGiven:$postId');

  @override
  Future<List<Map<String, dynamic>>> fetchAvailablePosts() async => rows;

  @override
  Future<List<Map<String, dynamic>>> fetchAvailablePostsPage({
    required int offset,
    required int limit,
    String? excludeUserId,
    String? category,
    String? condition,
    String? search,
  }) async {
    calls.add(
      'page:$offset:$limit:$excludeUserId:$category:$condition:$search',
    );
    return rows;
  }

  @override
  Future<Map<String, dynamic>?> fetchPostById(String postId) async => row;

  @override
  Future<int> fetchDonatedCount(String userId) async => donated;

  @override
  Future<List<Map<String, dynamic>>> fetchPostsByUser(String userId) async {
    calls.add('fetchPostsByUser:$userId');
    return rows;
  }

  @override
  Future<Map<String, dynamic>> createPost({
    required String userId,
    required String title,
    required String description,
    required String category,
    required String condition,
    required String address,
    required List<String> imageUrls,
  }) async {
    createdWith.add({
      'userId': userId,
      'title': title,
      'category': category,
      'address': address,
      'imageUrls': imageUrls,
    });
    return postJson(
      userId: userId,
      title: title,
      category: category,
      condition: condition,
      address: address,
      imageUrls: imageUrls,
    );
  }
}

class FakeRequestDataSource implements RequestRemoteDataSource {
  List<Map<String, dynamic>> rows = [];
  final calls = <String>[];

  @override
  Future<Map<String, dynamic>> createRequest({
    required String postId,
    required String requesterId,
    required String ownerId,
  }) async =>
      requestJson(postId: postId, requesterId: requesterId, ownerId: ownerId);

  @override
  Future<List<Map<String, dynamic>>> fetchSentRequests(
    String requesterId,
  ) async => rows;

  @override
  Future<List<Map<String, dynamic>>> fetchReceivedRequests(
    String ownerId,
  ) async => rows;

  final events = StreamController<RealtimeEvent<Map<String, dynamic>>>();

  @override
  Stream<RealtimeEvent<Map<String, dynamic>>> watchRequests(String userId) =>
      events.stream;

  @override
  Future<void> cancelRequest(String requestId) async =>
      calls.add('cancel:$requestId');

  @override
  Future<void> acceptRequest(String requestId) async =>
      calls.add('accept:$requestId');

  @override
  Future<void> closeOtherPendingRequests({
    required String postId,
    required String acceptedRequestId,
  }) async => calls.add('closeOthers:$postId:$acceptedRequestId');
}

class FakeWishlistDataSource implements WishlistRemoteDataSource {
  List<Map<String, dynamic>> rows = [];
  final calls = <String>[];

  @override
  Future<List<Map<String, dynamic>>> fetchWishlist(String userId) async => rows;

  @override
  Future<void> addToWishlist({
    required String userId,
    required String postId,
    required String title,
    String? note,
  }) async => calls.add('add:$userId:$postId:$title:$note');

  @override
  Future<void> removeFromWishlist({
    required String userId,
    required String postId,
  }) async => calls.add('remove:$userId:$postId');
}

class FakeFeedbackDataSource implements FeedbackRemoteDataSource {
  Map<String, dynamic>? row;
  List<Map<String, dynamic>> rows = [];
  final calls = <String>[];

  @override
  Future<Map<String, dynamic>?> fetchForRequest(String requestId) async => row;

  @override
  Future<List<Map<String, dynamic>>> fetchForUser(String userId) async => rows;

  @override
  Future<void> submit({
    required String requestId,
    required String postId,
    required String fromUserId,
    required String toUserId,
    required int rating,
    String? comment,
  }) async => calls.add('submit:$requestId:$rating:$comment');
}

class FakeChatDataSource implements ChatRemoteDataSource {
  List<Map<String, dynamic>> rows = [];
  final calls = <String>[];

  final events = StreamController<RealtimeEvent<Map<String, dynamic>>>();

  @override
  Future<List<Map<String, dynamic>>> fetchMessages(String requestId) async =>
      rows;

  @override
  Stream<RealtimeEvent<Map<String, dynamic>>> watchMessages(String requestId) =>
      events.stream;

  @override
  Future<Map<String, dynamic>> sendMessage({
    required String requestId,
    required String senderId,
    required String body,
  }) async {
    calls.add('send:$requestId:$senderId:$body');
    return {
      'id': 'sent-1',
      'request_id': requestId,
      'sender_id': senderId,
      'body': body,
      'created_at': kCreatedAt.toIso8601String(),
    };
  }

  @override
  Future<void> deleteMessage(String messageId) async =>
      calls.add('delete:$messageId');
}

class FakeProfileDataSource implements ProfileRemoteDataSource {
  Map<String, dynamic>? row;
  List<Map<String, dynamic>> rows = [];
  final calls = <String>[];

  @override
  Future<Map<String, dynamic>?> fetchProfile(String userId) async => row;

  @override
  Future<Map<String, dynamic>?> fetchPublicProfile(String userId) async => row;

  @override
  Future<List<Map<String, dynamic>>> fetchPublicProfiles(
    List<String> userIds,
  ) async => rows;

  @override
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
  }) async {
    calls.add('upload:$userId');
    return 'https://cdn/avatar.png';
  }

  @override
  Future<void> updateAvatarUrl({
    required String userId,
    required String avatarUrl,
  }) async => calls.add('updateAvatar:$userId:$avatarUrl');

  @override
  Future<void> updateProfileRow({
    required String userId,
    required String fullName,
    required String email,
    String? phone,
    String? bio,
  }) async => calls.add('row:$userId:$fullName:$email:$phone:$bio');

  @override
  Future<void> updateAuthUser({
    required String fullName,
    String? newEmail,
  }) async => calls.add('auth:$fullName:$newEmail');
}
