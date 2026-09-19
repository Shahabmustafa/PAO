import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Talks directly to Supabase (the `posts` table and `post-images` storage
/// bucket). No app logic here — the repository interprets the results.
class PostRemoteDataSource {
  PostRemoteDataSource({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _bucket = 'post-images';

  Future<String> uploadImage({
    required String userId,
    required Uint8List bytes,
  }) async {
    final path = '$userId/${DateTime.now().microsecondsSinceEpoch}.jpg';
    await _client.storage
        .from(_bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    return _client.storage.from(_bucket).getPublicUrl(path);
  }

  Future<void> markAsGiven(String postId) {
    return _client.from('posts').update({'is_given': true}).eq('id', postId);
  }

  Future<List<Map<String, dynamic>>> fetchAvailablePosts() async {
    final rows = await _client
        .from('posts')
        .select()
        .eq('is_given', false)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// Every post created by [userId], available or given away, newest first.
  Future<List<Map<String, dynamic>>> fetchPostsByUser(String userId) async {
    final rows = await _client
        .from('posts')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// Live Supabase Realtime stream of every available post — emits again
  /// automatically whenever a post is created, edited, or marked as given.
  Stream<List<Map<String, dynamic>>> streamAvailablePosts() {
    return _client
        .from('posts')
        .stream(primaryKey: ['id'])
        .eq('is_given', false)
        .order('created_at', ascending: false);
  }

  Future<Map<String, dynamic>?> fetchPostById(String postId) {
    return _client.from('posts').select().eq('id', postId).maybeSingle();
  }

  Future<int> fetchDonatedCount(String userId) async {
    final rows = await _client
        .from('posts')
        .select('id')
        .eq('user_id', userId)
        .eq('is_given', true);
    return (rows as List).length;
  }

  Future<Map<String, dynamic>> createPost({
    required String userId,
    required String title,
    required String description,
    required String category,
    required String condition,
    required List<String> imageUrls,
  }) {
    return _client
        .from('posts')
        .insert({
          'user_id': userId,
          'title': title,
          'description': description,
          'category': category,
          'condition': condition,
          'image_urls': imageUrls,
        })
        .select()
        .single();
  }
}
