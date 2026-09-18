import '../datasource/feedback_remote_datasource.dart';
import '../model/feedback_model.dart';

/// Bridges the feedback data source and the presentation layer.
class FeedbackRepository {
  FeedbackRepository({FeedbackRemoteDataSource? dataSource})
    : _dataSource = dataSource ?? FeedbackRemoteDataSource();

  final FeedbackRemoteDataSource _dataSource;

  Future<FeedbackModel?> fetchForRequest(String requestId) async {
    final row = await _dataSource.fetchForRequest(requestId);
    return row == null ? null : FeedbackModel.fromJson(row);
  }

  Future<List<FeedbackModel>> fetchForUser(String userId) async {
    final rows = await _dataSource.fetchForUser(userId);
    return rows.map(FeedbackModel.fromJson).toList();
  }

  Future<void> submit({
    required String requestId,
    required String postId,
    required String fromUserId,
    required String toUserId,
    required int rating,
    String? comment,
  }) {
    return _dataSource.submit(
      requestId: requestId,
      postId: postId,
      fromUserId: fromUserId,
      toUserId: toUserId,
      rating: rating,
      comment: comment,
    );
  }
}
