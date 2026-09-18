import 'package:supabase_flutter/supabase_flutter.dart';

/// Talks directly to Supabase (the `wishlist` table). No app logic here —
/// the repository interprets the results.
class WishlistRemoteDataSource {
  WishlistRemoteDataSource({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> fetchWishlist(String userId) async {
    final rows = await _client
        .from('wishlist')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<void> addToWishlist({
    required String userId,
    required String postId,
    required String title,
    String? note,
  }) {
    return _client.from('wishlist').insert({
      'user_id': userId,
      'post_id': postId,
      'title': title,
      'note': note,
    });
  }

  Future<void> removeFromWishlist({
    required String userId,
    required String postId,
  }) {
    return _client
        .from('wishlist')
        .delete()
        .eq('user_id', userId)
        .eq('post_id', postId);
  }
}
