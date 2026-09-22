import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/realtime/realtime_event.dart';
import '../../../../core/realtime/realtime_table_stream.dart';

/// Talks directly to Supabase (the `messages` table), including the
/// realtime channel that powers live chat.
class ChatRemoteDataSource {
  ChatRemoteDataSource({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> fetchMessages(String requestId) async {
    final rows = await _client
        .from('messages')
        .select()
        .eq('request_id', requestId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// Live INSERT / UPDATE / DELETE events for one conversation.
  ///
  /// INSERT and UPDATE are filtered to [requestId] on the server. DELETE
  /// can't be filtered (the deleted row only carries its id), so every
  /// delete is delivered and the listener drops the ones it doesn't have.
  Stream<RealtimeEvent<Map<String, dynamic>>> watchMessages(String requestId) {
    final inChat = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'request_id',
      value: requestId,
    );
    return watchTable(
      _client,
      channelName: 'messages:$requestId',
      table: 'messages',
      bindings: [
        RealtimeBinding(event: PostgresChangeEvent.insert, filter: inChat),
        RealtimeBinding(event: PostgresChangeEvent.update, filter: inChat),
        const RealtimeBinding(event: PostgresChangeEvent.delete),
      ],
    );
  }

  Future<Map<String, dynamic>> sendMessage({
    required String requestId,
    required String senderId,
    required String body,
  }) {
    return _client
        .from('messages')
        .insert({'request_id': requestId, 'sender_id': senderId, 'body': body})
        .select()
        .single();
  }

  Future<void> deleteMessage(String messageId) {
    return _client.from('messages').delete().eq('id', messageId);
  }

  /// Marks every unread message [readerId] received in [requestId] as seen.
  /// The sender's own realtime subscription picks up the resulting UPDATE,
  /// so their ticks flip to "read" live.
  Future<void> markMessagesRead({
    required String requestId,
    required String readerId,
  }) {
    return _client
        .from('messages')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('request_id', requestId)
        .neq('sender_id', readerId)
        .isFilter('read_at', null);
  }

  /// Edits one of the current user's own messages. `edited_at` is stamped
  /// server-side by `guard_message_update` (see
  /// supabase/messages_add_read_edited.sql), not sent from here.
  Future<Map<String, dynamic>> editMessage({
    required String messageId,
    required String body,
  }) {
    return _client
        .from('messages')
        .update({'body': body})
        .eq('id', messageId)
        .select()
        .single();
  }
}
