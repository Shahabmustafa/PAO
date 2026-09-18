import 'package:supabase_flutter/supabase_flutter.dart';

/// Talks directly to Supabase (the `feedback` table).
class FeedbackRemoteDataSource {
  FeedbackRemoteDataSource({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<Map<String, dynamic>?> fetchForRequest(String requestId) {
    return _client
        .from('feedback')
        .select()
        .eq('request_id', requestId)
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> fetchForUser(String userId) async {
    final rows = await _client
        .from('feedback')
        .select()
        .eq('to_user_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<void> submit({
    required String requestId,
    required String postId,
    required String fromUserId,
    required String toUserId,
    required int rating,
    String? comment,
  }) {
    return _client.from('feedback').insert({
      'request_id': requestId,
      'post_id': postId,
      'from_user_id': fromUserId,
      'to_user_id': toUserId,
      'rating': rating,
      'comment': comment,
    });
  }
}
