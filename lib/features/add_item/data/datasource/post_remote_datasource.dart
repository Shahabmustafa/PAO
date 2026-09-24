import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/realtime/realtime_event.dart';
import '../../../../core/realtime/realtime_table_stream.dart';

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

  /// Removes uploaded photos from the bucket. The paths are read back out of
  /// the public URLs that were stored on the post.
  Future<void> deleteImages(List<String> urls) async {
    final paths = [
      for (final url in urls)
        if (url.contains('/$_bucket/')) url.split('/$_bucket/').last,
    ];
    if (paths.isEmpty) return;
    await _client.storage.from(_bucket).remove(paths);
  }

  /// The columns [PostModel] reads -- listed so a query never pulls
  /// anything the app doesn't use.
  static const postColumns =
      'id, user_id, title, description, category, address, condition, '
      'image_urls, is_given, created_at';

  Future<void> markAsGiven(String postId) {
    return _client.from('posts').update({'is_given': true}).eq('id', postId);
  }

  /// One page of available posts, newest first, filtered on the server so a
  /// page always holds up to [limit] matching rows.
  ///
  /// Keyset pagination: pass the last row of the previous page as
  /// [afterCreatedAt] / [afterId] to get the rows that follow it in
  /// `created_at desc, id desc` order. Unlike OFFSET this stays fast on deep
  /// pages, and new posts arriving meanwhile can't shift or repeat rows.
  Future<List<Map<String, dynamic>>> fetchAvailablePostsPage({
    DateTime? afterCreatedAt,
    String? afterId,
    required int limit,
    String? excludeUserId,
    String? category,
    String? condition,
    String? search,
  }) async {
    var query = _client.from('posts').select(postColumns).eq('is_given', false);
    if (afterCreatedAt != null && afterId != null) {
      final at = afterCreatedAt.toUtc().toIso8601String();
      query = query.or(
        'created_at.lt.$at,and(created_at.eq.$at,id.lt.$afterId)',
      );
    }
    if (excludeUserId != null) query = query.neq('user_id', excludeUserId);
    if (category == 'Other') {
      // The app shows a post without a category as "Other".
      query = query.or('category.eq.Other,category.is.null');
    } else if (category != null) {
      query = query.eq('category', category);
    }
    if (condition != null) query = query.eq('condition', condition);
    if (search != null && search.isNotEmpty) {
      query = query.ilike('title', '%${_escapeLike(search)}%');
    }
    final rows = await query
        .order('created_at', ascending: false)
        // Tie-breaker so rows created at the same instant keep a stable order
        // between pages.
        .order('id', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// Escapes the `LIKE` wildcards so a search for "50%" matches the literal
  /// text instead of everything.
  static String _escapeLike(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');

  /// Every post created by [userId], available or given away, newest first.
  Future<List<Map<String, dynamic>>> fetchPostsByUser(String userId) async {
    final rows = await _client
        .from('posts')
        .select(postColumns)
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// Live INSERT / UPDATE / DELETE events for every post.
  ///
  /// Deliberately not filtered on `is_given`: a post that is given away
  /// stops matching such a filter, so its UPDATE would never arrive and the
  /// feed would keep showing it. Listeners decide what to keep.
  Stream<RealtimeEvent<Map<String, dynamic>>> watchPosts() {
    return watchTable(
      _client,
      channelName: 'posts',
      table: 'posts',
      bindings: const [
        RealtimeBinding(event: PostgresChangeEvent.insert),
        RealtimeBinding(event: PostgresChangeEvent.update),
        RealtimeBinding(event: PostgresChangeEvent.delete),
      ],
    );
  }

  Future<Map<String, dynamic>?> fetchPostById(String postId) {
    return _client
        .from('posts')
        .select(postColumns)
        .eq('id', postId)
        .maybeSingle();
  }

  /// Several posts by id in one round trip (wishlist / request lookups).
  Future<List<Map<String, dynamic>>> fetchPostsByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await _client
        .from('posts')
        .select(postColumns)
        .inFilter('id', ids);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// `user_id` of every given-away post (one entry per donation), used to
  /// rank donors.
  Future<List<String>> fetchGivenPostOwners() async {
    final rows = await _client
        .from('posts')
        .select('user_id')
        .eq('is_given', true);
    return [
      for (final r in rows as List)
        if (r['user_id'] != null) r['user_id'] as String,
    ];
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
    required String address,
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
          'address': address,
          'image_urls': imageUrls,
        })
        .select(postColumns)
        .single();
  }

  Future<Map<String, dynamic>> updatePost({
    required String postId,
    required String title,
    required String description,
    required String category,
    required String condition,
    required String address,
    required List<String> imageUrls,
  }) {
    // Row Level Security only lets the owner update, so for anyone else this
    // matches no row and `single()` throws.
    return _client
        .from('posts')
        .update({
          'title': title,
          'description': description,
          'category': category,
          'condition': condition,
          'address': address,
          'image_urls': imageUrls,
        })
        .eq('id', postId)
        .select(postColumns)
        .single();
  }

  /// Deletes the post; its requests, chats, wishlist entries and feedback go
  /// with it (`on delete cascade`). Throws if no row was deleted (not the
  /// owner, or already gone).
  Future<void> deletePost(String postId) async {
    final rows = await _client
        .from('posts')
        .delete()
        .eq('id', postId)
        .select('id');
    if ((rows as List).isEmpty) {
      throw StateError('Post $postId was not deleted');
    }
  }
}
