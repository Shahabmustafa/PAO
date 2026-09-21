import '../../../../core/realtime/realtime_event.dart';
import '../datasource/chat_remote_datasource.dart';
import '../model/message_model.dart';

/// Bridges the chat data source and the presentation layer.
class ChatRepository {
  ChatRepository({ChatRemoteDataSource? dataSource})
    : _dataSource = dataSource ?? ChatRemoteDataSource();

  final ChatRemoteDataSource _dataSource;

  /// Every message of the conversation, oldest first.
  Future<List<MessageModel>> fetchMessages(String requestId) async {
    final rows = await _dataSource.fetchMessages(requestId);
    return rows.map(MessageModel.fromJson).toList();
  }

  Stream<RealtimeEvent<MessageModel>> watchMessages(String requestId) {
    return _dataSource
        .watchMessages(requestId)
        .map((event) => event.mapRecord(MessageModel.fromJson));
  }

  Future<MessageModel> sendMessage({
    required String requestId,
    required String senderId,
    required String body,
  }) async {
    final row = await _dataSource.sendMessage(
      requestId: requestId,
      senderId: senderId,
      body: body,
    );
    return MessageModel.fromJson(row);
  }

  Future<void> deleteMessage(String messageId) =>
      _dataSource.deleteMessage(messageId);
}
