import 'dart:typed_data';
import '../../../../core/realtime/realtime_event.dart';
import '../../../../core/realtime/realtime_log.dart';
import '../datasource/post_remote_datasource.dart';
import '../model/post_model.dart';

/// Bridges the post data source and the presentation layer: uploads photos
/// first, then creates the post row with the resulting image URLs.
class PostRepository {
  PostRepository({PostRemoteDataSource? dataSource})
    : _dataSource = dataSource ?? PostRemoteDataSource();

  final PostRemoteDataSource _dataSource;

  Future<void> markAsGiven(String postId) => _dataSource.markAsGiven(postId);

  /// Donation count per user id, over all given-away posts.
  Future<Map<String, int>> fetchDonorCounts() async {
    final counts = <String, int>{};
    for (final id in await _dataSource.fetchGivenPostOwners()) {
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }

  Future<int> fetchDonatedCount(String userId) =>
      _dataSource.fetchDonatedCount(userId);

  /// Looks up a single post regardless of its `is_given` status — used to
  /// display a given-away item's name/image where the paged feed
  /// (which excludes given posts) wouldn't have it.
  Future<PostModel?> fetchPostById(String postId) async {
    final row = await _dataSource.fetchPostById(postId);
    return row == null ? null : PostModel.fromJson(row);
  }

  Future<List<PostModel>> fetchPostsByUser(String userId) async {
    final rows = await _dataSource.fetchPostsByUser(userId);
    return rows.map(PostModel.fromJson).toList();
  }

  Future<List<PostModel>> fetchPostsByIds(List<String> ids) async {
    final rows = await _dataSource.fetchPostsByIds(ids);
    return rows.map(PostModel.fromJson).toList();
  }

  Future<List<PostModel>> fetchAvailablePostsPage({
    DateTime? afterCreatedAt,
    String? afterId,
    required int limit,
    String? excludeUserId,
    String? category,
    String? condition,
    String? search,
  }) async {
    final rows = await _dataSource.fetchAvailablePostsPage(
      afterCreatedAt: afterCreatedAt,
      afterId: afterId,
      limit: limit,
      excludeUserId: excludeUserId,
      category: category,
      condition: condition,
      search: search,
    );
    return rows.map(PostModel.fromJson).toList();
  }

  /// Live post changes. An UPDATE that arrives without every column (Realtime
  /// leaves out unchanged large values such as a long description) is
  /// completed by fetching that one row.
  Stream<RealtimeEvent<PostModel>> watchPosts() {
    return _dataSource
        .watchPosts()
        .asyncMap(_toPostEvent)
        .where((event) => event != null)
        .cast<RealtimeEvent<PostModel>>();
  }

  Future<RealtimeEvent<PostModel>?> _toPostEvent(
    RealtimeEvent<Map<String, dynamic>> event,
  ) async {
    try {
      return event.mapRecord(PostModel.fromJson);
    } catch (_) {
      realtimeLog('post ${event.id} arrived incomplete, fetching that row');
    }
    try {
      final row = await _dataSource.fetchPostById(event.id);
      if (row == null) return null;
      return RealtimeEvent(
        type: event.type,
        id: event.id,
        record: PostModel.fromJson(row),
      );
    } catch (_) {
      return null;
    }
  }

  Future<PostModel> createPost({
    required String userId,
    required String title,
    required String description,
    required String category,
    required String condition,
    required String address,
    required List<Uint8List> images,
  }) async {
    final imageUrls = <String>[];
    for (final bytes in images) {
      final url = await _dataSource.uploadImage(userId: userId, bytes: bytes);
      imageUrls.add(url);
    }

    final row = await _dataSource.createPost(
      userId: userId,
      title: title,
      description: description,
      category: category,
      condition: condition,
      address: address,
      imageUrls: imageUrls,
    );
    return PostModel.fromJson(row);
  }

  /// Saves edits to a post. [keptImageUrls] are photos already uploaded that
  /// stay, [newImages] are uploaded now, and [removedImageUrls] are deleted
  /// from storage once the post row has been updated.
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
    final imageUrls = [...keptImageUrls];
    for (final bytes in newImages) {
      imageUrls.add(
        await _dataSource.uploadImage(userId: userId, bytes: bytes),
      );
    }

    final row = await _dataSource.updatePost(
      postId: postId,
      title: title,
      description: description,
      category: category,
      condition: condition,
      address: address,
      imageUrls: imageUrls,
    );
    await _deleteImagesQuietly(removedImageUrls);
    return PostModel.fromJson(row);
  }

  /// Deletes a post and, afterwards, its photos.
  Future<void> deletePost(
    String postId, {
    List<String> imageUrls = const [],
  }) async {
    await _dataSource.deletePost(postId);
    await _deleteImagesQuietly(imageUrls);
  }

  // A leftover photo is harmless next to a failed edit/delete, so storage
  // errors here are swallowed.
  Future<void> _deleteImagesQuietly(List<String> urls) async {
    if (urls.isEmpty) return;
    try {
      await _dataSource.deleteImages(urls);
    } catch (_) {}
  }
}
