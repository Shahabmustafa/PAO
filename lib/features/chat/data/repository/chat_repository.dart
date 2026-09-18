import '../datasource/chat_remote_datasource.dart';
import '../model/message_model.dart';

/// Bridges the chat data source and the presentation layer.
class ChatRepository {
  ChatRepository({ChatRemoteDataSource? dataSource})
      : _dataSource = dataSource ?? ChatRemoteDataSource();

  final ChatRemoteDataSource _dataSource;

  Stream<List<MessageModel>> streamMessages(String requestId) {
    return _dataSource
        .streamMessages(requestId)
        .map((rows) => rows.map(MessageModel.fromJson).toList());
  }

  Future<void> sendMessage({
    required String requestId,
    required String senderId,
    required String body,
  }) {
    return _dataSource.sendMessage(
      requestId: requestId,
      senderId: senderId,
      body: body,
    );
  }
}
