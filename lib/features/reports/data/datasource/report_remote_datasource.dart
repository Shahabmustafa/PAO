import 'package:supabase_flutter/supabase_flutter.dart';

/// Talks directly to Supabase (the `app_reports` table).
class ReportRemoteDataSource {
  ReportRemoteDataSource({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> fetchForUser(String userId) async {
    final rows = await _client
        .from('app_reports')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<Map<String, dynamic>> submit({
    required String userId,
    required String type,
    required String title,
    required String description,
    String? platform,
  }) {
    return _client
        .from('app_reports')
        .insert({
          'user_id': userId,
          'type': type,
          'title': title,
          'description': description,
          'platform': platform,
        })
        .select()
        .single();
  }
}
