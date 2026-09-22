import '../../../../core/realtime/realtime_event.dart';
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

  Future<RequestModel?> fetchRequestById(String requestId) async {
    final row = await _dataSource.fetchRequestById(requestId);
    return row == null ? null : RequestModel.fromJson(row);
  }

  /// Live request changes for [userId]. Events are tagged
  /// [RequestRemoteDataSource.sentTag] / [RequestRemoteDataSource.receivedTag].
  Stream<RealtimeEvent<RequestModel>> watchRequests(String userId) {
    return _dataSource
        .watchRequests(userId)
        .map((event) => event.mapRecord(RequestModel.fromJson));
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
