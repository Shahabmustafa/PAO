import 'package:supabase_flutter/supabase_flutter.dart';

/// Talks directly to Supabase (the `messages` table), including the
/// realtime stream that powers live chat.
class ChatRemoteDataSource {
  ChatRemoteDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Stream<List<Map<String, dynamic>>> streamMessages(String requestId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('request_id', requestId)
        .order('created_at');
  }

  Future<void> sendMessage({
    required String requestId,
    required String senderId,
    required String body,
  }) {
    return _client.from('messages').insert({
      'request_id': requestId,
      'sender_id': senderId,
      'body': body,
    });
  }
}
