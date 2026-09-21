import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/realtime/realtime_event.dart';
import '../../../../core/realtime/realtime_table_stream.dart';

/// Talks directly to Supabase (the `requests` table). No app logic here —
/// the repository interprets the results.
class RequestRemoteDataSource {
  RequestRemoteDataSource({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<Map<String, dynamic>> createRequest({
    required String postId,
    required String requesterId,
    required String ownerId,
  }) {
    return _client
        .from('requests')
        .insert({
          'post_id': postId,
          'requester_id': requesterId,
          'owner_id': ownerId,
        })
        .select()
        .single();
  }

  Future<List<Map<String, dynamic>>> fetchSentRequests(
    String requesterId,
  ) async {
    final rows = await _client
        .from('requests')
        .select()
        .eq('requester_id', requesterId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<List<Map<String, dynamic>>> fetchReceivedRequests(
    String ownerId,
  ) async {
    final rows = await _client
        .from('requests')
        .select()
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// Tag on events for requests this user sent.
  static const sentTag = 'sent';

  /// Tag on events for requests this user received.
  static const receivedTag = 'received';

  /// Live INSERT / UPDATE / DELETE events for every request [userId] is part
  /// of, tagged [sentTag] (they are the requester) or [receivedTag] (they
  /// own the post). Row Level Security already limits requests to the two
  /// participants; the filters just pick the right list. DELETE can't be
  /// filtered, so every delete is delivered and matched to local state by id.
  Stream<RealtimeEvent<Map<String, dynamic>>> watchRequests(String userId) {
    PostgresChangeFilter column(String name) => PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: name,
      value: userId,
    );
    return watchTable(
      _client,
      channelName: 'requests:$userId',
      table: 'requests',
      bindings: [
        for (final event in [
          PostgresChangeEvent.insert,
          PostgresChangeEvent.update,
        ]) ...[
          RealtimeBinding(
            event: event,
            filter: column('requester_id'),
            tag: sentTag,
          ),
          RealtimeBinding(
            event: event,
            filter: column('owner_id'),
            tag: receivedTag,
          ),
        ],
        const RealtimeBinding(event: PostgresChangeEvent.delete),
      ],
    );
  }

  Future<void> cancelRequest(String requestId) {
    return _client.from('requests').delete().eq('id', requestId);
  }

  Future<void> acceptRequest(String requestId) {
    return _client
        .from('requests')
        .update({'status': 'accepted'})
        .eq('id', requestId);
  }

  Future<void> closeOtherPendingRequests({
    required String postId,
    required String acceptedRequestId,
  }) {
    return _client
        .from('requests')
        .update({'status': 'closed'})
        .eq('post_id', postId)
        .eq('status', 'pending')
        .neq('id', acceptedRequestId);
  }
}
