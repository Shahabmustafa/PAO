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
}
