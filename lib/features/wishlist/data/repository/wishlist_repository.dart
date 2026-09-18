import '../datasource/wishlist_remote_datasource.dart';
import '../model/wishlist_item_model.dart';

/// Bridges the wishlist data source and the presentation layer.
class WishlistRepository {
  WishlistRepository({WishlistRemoteDataSource? dataSource})
    : _dataSource = dataSource ?? WishlistRemoteDataSource();

  final WishlistRemoteDataSource _dataSource;

  Future<List<WishlistItemModel>> fetchWishlist(String userId) async {
    final rows = await _dataSource.fetchWishlist(userId);
    return rows.map(WishlistItemModel.fromJson).toList();
  }

  Future<void> addToWishlist({
    required String userId,
    required String postId,
    required String title,
    String? note,
  }) {
    return _dataSource.addToWishlist(
      userId: userId,
      postId: postId,
      title: title,
      note: note,
    );
  }

  Future<void> removeFromWishlist({
    required String userId,
    required String postId,
  }) {
    return _dataSource.removeFromWishlist(userId: userId, postId: postId);
  }
}
