import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// Live Supabase Realtime stream of requests this user sent — emits again
  /// automatically whenever one of those requests changes (e.g. accepted).
  Stream<List<Map<String, dynamic>>> streamSentRequests(String requesterId) {
    return _client
        .from('requests')
        .stream(primaryKey: ['id'])
        .eq('requester_id', requesterId)
        .order('created_at', ascending: false);
  }

  /// Live Supabase Realtime stream of requests this user received — emits
  /// again automatically whenever a new request comes in or changes status.
  Stream<List<Map<String, dynamic>>> streamReceivedRequests(String ownerId) {
    return _client
        .from('requests')
        .stream(primaryKey: ['id'])
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false);
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
