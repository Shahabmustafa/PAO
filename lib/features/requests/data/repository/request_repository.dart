import '../datasource/request_remote_datasource.dart';
import '../model/request_model.dart';

/// Bridges the request data source and the presentation layer.
class RequestRepository {
  RequestRepository({RequestRemoteDataSource? dataSource})
    : _dataSource = dataSource ?? RequestRemoteDataSource();

  final RequestRemoteDataSource _dataSource;

  Future<RequestModel> createRequest({
    required String postId,
    required String requesterId,
    required String ownerId,
  }) async {
    final row = await _dataSource.createRequest(
      postId: postId,
      requesterId: requesterId,
      ownerId: ownerId,
    );
    return RequestModel.fromJson(row);
  }

  Future<List<RequestModel>> fetchSentRequests(String requesterId) async {
    final rows = await _dataSource.fetchSentRequests(requesterId);
    return rows.map(RequestModel.fromJson).toList();
  }

  Future<List<RequestModel>> fetchReceivedRequests(String ownerId) async {
    final rows = await _dataSource.fetchReceivedRequests(ownerId);
    return rows.map(RequestModel.fromJson).toList();
  }

  Stream<List<RequestModel>> streamSentRequests(String requesterId) {
    return _dataSource
        .streamSentRequests(requesterId)
        .map((rows) => rows.map(RequestModel.fromJson).toList());
  }

  Stream<List<RequestModel>> streamReceivedRequests(String ownerId) {
    return _dataSource
        .streamReceivedRequests(ownerId)
        .map((rows) => rows.map(RequestModel.fromJson).toList());
  }

  Future<void> cancelRequest(String requestId) {
    return _dataSource.cancelRequest(requestId);
  }

  /// Accepts one request and closes every other pending request on the
  /// same post — the item can only go to one person.
  Future<void> acceptRequest({
    required String requestId,
    required String postId,
  }) async {
    await _dataSource.acceptRequest(requestId);
    await _dataSource.closeOtherPendingRequests(
      postId: postId,
      acceptedRequestId: requestId,
    );
  }
}
