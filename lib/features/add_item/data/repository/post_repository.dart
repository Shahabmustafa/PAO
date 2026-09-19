import 'dart:typed_data';
import '../datasource/post_remote_datasource.dart';
import '../model/post_model.dart';

/// Bridges the post data source and the presentation layer: uploads photos
/// first, then creates the post row with the resulting image URLs.
class PostRepository {
  PostRepository({PostRemoteDataSource? dataSource})
    : _dataSource = dataSource ?? PostRemoteDataSource();

  final PostRemoteDataSource _dataSource;

  Future<void> markAsGiven(String postId) => _dataSource.markAsGiven(postId);

  Future<int> fetchDonatedCount(String userId) =>
      _dataSource.fetchDonatedCount(userId);

  /// Looks up a single post regardless of its `is_given` status — used to
  /// display a given-away item's name/image where [fetchAvailablePosts]
  /// (which excludes given posts) wouldn't have it.
  Future<PostModel?> fetchPostById(String postId) async {
    final row = await _dataSource.fetchPostById(postId);
    return row == null ? null : PostModel.fromJson(row);
  }

  Future<List<PostModel>> fetchPostsByUser(String userId) async {
    final rows = await _dataSource.fetchPostsByUser(userId);
    return rows.map(PostModel.fromJson).toList();
  }

  Future<List<PostModel>> fetchAvailablePosts() async {
    final rows = await _dataSource.fetchAvailablePosts();
    return rows.map(PostModel.fromJson).toList();
  }

  Stream<List<PostModel>> streamAvailablePosts() {
    return _dataSource.streamAvailablePosts().map(
      (rows) => rows.map(PostModel.fromJson).toList(),
    );
  }

  Future<PostModel> createPost({
    required String userId,
    required String title,
    required String description,
    required String category,
    required String condition,
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
      imageUrls: imageUrls,
    );
    return PostModel.fromJson(row);
  }
}
