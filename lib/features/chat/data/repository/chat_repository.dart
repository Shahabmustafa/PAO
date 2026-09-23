import 'dart:io';
import '../../../../core/realtime/realtime_event.dart';
import '../datasource/chat_remote_datasource.dart';
import '../model/message_model.dart';

/// Bridges the chat data source and the presentation layer.
class ChatRepository {
  ChatRepository({ChatRemoteDataSource? dataSource})
    : _dataSource = dataSource ?? ChatRemoteDataSource();

  final ChatRemoteDataSource _dataSource;

  /// Every message the two users have exchanged, oldest first.
  Future<List<MessageModel>> fetchMessages({
    required String currentUserId,
    required String otherUserId,
  }) async {
    final rows = await _dataSource.fetchMessages(
      currentUserId: currentUserId,
      otherUserId: otherUserId,
    );
    return rows.map(MessageModel.fromJson).toList();
  }

  Stream<RealtimeEvent<MessageModel>> watchMessages(String currentUserId) {
    return _dataSource
        .watchMessages(currentUserId)
        .map((event) => event.mapRecord(MessageModel.fromJson));
  }

  Future<MessageModel> sendMessage({
    String? requestId,
    required String senderId,
    required String recipientId,
    required String body,
    String? replyToId,
    MessageMediaType? mediaType,
    String? mediaPath,
    int? mediaDurationMs,
  }) async {
    final row = await _dataSource.sendMessage(
      replyToId: replyToId,
      requestId: requestId,
      senderId: senderId,
      recipientId: recipientId,
      body: body,
      mediaType: mediaType?.name,
      mediaPath: mediaPath,
      mediaDurationMs: mediaDurationMs,
    );
    return MessageModel.fromJson(row);
  }

  Future<String> uploadMedia({
    required String userId,
    required File file,
    required String extension,
    required String contentType,
  }) => _dataSource.uploadMedia(
    userId: userId,
    file: file,
    extension: extension,
    contentType: contentType,
  );

  Future<String> mediaUrl(String path) => _dataSource.mediaUrl(path);

  Future<void> removeMedia(String path) => _dataSource.removeMedia(path);

  Future<void> deleteMessage(String messageId) =>
      _dataSource.deleteMessage(messageId);

  Future<void> reactToMessage(String messageId, String? emoji) =>
      _dataSource.reactToMessage(messageId, emoji);

  Future<void> deleteMessageForMe(String messageId) =>
      _dataSource.deleteMessageForMe(messageId);

  Future<void> markMessagesRead({
    required String readerId,
    required String otherUserId,
  }) => _dataSource.markMessagesRead(
    readerId: readerId,
    otherUserId: otherUserId,
  );

  Future<MessageModel> editMessage({
    required String messageId,
    required String body,
  }) async {
    final row = await _dataSource.editMessage(messageId: messageId, body: body);
    return MessageModel.fromJson(row);
  }

  Future<List<MessageModel>> fetchUnread(String userId) async {
    final rows = await _dataSource.fetchUnread(userId);
    return rows.map(MessageModel.fromJson).toList();
  }

  Stream<RealtimeEvent<MessageModel>> watchUnread(String userId) {
    return _dataSource
        .watchUnread(userId)
        .map((event) => event.mapRecord(MessageModel.fromJson));
  }
}
