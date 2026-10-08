import 'dart:async';
import 'package:app_links/app_links.dart' as app_links;
import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../notifications/notification_router.dart';
import '../routes/app_navigator.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/app_snackbar.dart';
import '../../features/add_item/data/model/post_model.dart';
import '../../features/add_item/data/repository/post_repository.dart';
import '../../features/home/data/product_store.dart';
import '../../features/home/domain/product.dart';
import '../../features/home/presentation/screens/product_detail_screen.dart';

/// Shareable links to a single post, and opening them inside the app.
///
/// A shared link is `https://shahabmustafa.github.io/PAO/post.html?id=<id>`.
/// WhatsApp etc. only make https links tappable; that page (docs/post.html)
/// hands the link over to the installed app as `com.pao.pao://post?id=<id>`,
/// or sends the visitor to the Play Store when the app isn't installed.
class PostLinks {
  PostLinks._();

  static const String webHost = 'shahabmustafa.github.io';
  static const String webPath = '/PAO/post.html';
  static const String appScheme = 'com.pao.pao';
  static const String appHost = 'post';

  /// The link put in the share text for [postId].
  static String urlFor(String postId) =>
      Uri.https(webHost, webPath, {'id': postId}).toString();

  /// The post id a link points at, or `null` when it isn't a post link
  /// (e.g. the password-reset callback, which Supabase handles itself).
  static String? postIdFrom(Uri uri) {
    final isWeb =
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host == webHost &&
        (uri.path == webPath || uri.path == '/PAO/post');
    final isApp = uri.scheme == appScheme && uri.host == appHost;
    if (!isWeb && !isApp) return null;
    final id = uri.queryParameters['id']?.trim();
    return id == null || id.isEmpty ? null : id;
  }

  static StreamSubscription<Uri>? _subscription;
  static Uri? _initialLink;
  static bool _initialSeenOnStream = false;
  static String? _pendingPostId;
  static int _dashboards = 0;

  /// Lets a test fetch posts from a fake; the app uses Supabase.
  @visibleForTesting
  static PostRepository Function() repository = PostRepository.new;

  /// Lets a test swap the detail screen for a stub.
  @visibleForTesting
  static Widget Function(Product product) detailScreen = _detailScreen;

  static Widget _detailScreen(Product product) =>
      ProductDetailScreen(product: product);

  /// Starts listening for post links. Call once at start-up. A link that
  /// cold-starts the app is kept until [DashboardScreen] is up, so a user
  /// who first has to log in still lands on the post afterwards.
  static void initialize() {
    if (_subscription != null) return;
    final links = app_links.AppLinks();
    _subscription = links.uriLinkStream.listen((uri) {
      // On Android the stream may repeat the launch link that
      // getInitialLink() below already handled.
      if (!_initialSeenOnStream && uri == _initialLink) {
        _initialSeenOnStream = true;
        return;
      }
      handle(uri);
    }, onError: (_) {});
    links
        .getInitialLink()
        .then((uri) {
          if (uri == null) return;
          _initialLink = uri;
          handle(uri);
        })
        .catchError((_) {});
  }

  /// Queues [uri] if it is a post link, and opens it right away when the
  /// dashboard is already showing.
  static void handle(Uri uri) {
    final postId = postIdFrom(uri);
    if (postId == null) return;
    _pendingPostId = postId;
    if (_dashboards > 0) openPending();
  }

  /// Called by [DashboardScreen] once it is on screen.
  static void dashboardShown() {
    _dashboards++;
    openPending();
  }

  /// Called by [DashboardScreen] when it is disposed.
  static void dashboardHidden() {
    if (_dashboards > 0) _dashboards--;
  }

  /// Opens the queued post, if any: its detail screen when it is still up
  /// for grabs, otherwise the Home tab with a note that it is gone.
  static Future<void> openPending() async {
    final postId = _pendingPostId;
    if (postId == null) return;
    _pendingPostId = null;

    // Start from Home, on top of the dashboard already on the stack.
    NotificationRouter.requestedTab.value = NotificationRouter.homeTabIndex;
    final navigator = AppNavigator.navigatorKey.currentState;
    navigator?.popUntil(
      (route) => route.settings.name == AppRoutes.dashboard || route.isFirst,
    );

    PostModel? post;
    var failed = false;
    try {
      post = await repository().fetchPostById(postId);
    } catch (_) {
      failed = true;
    }

    final current = AppNavigator.navigatorKey.currentState;
    if (current == null || !current.mounted) return;
    final context = current.context;

    if (post != null && !post.isGiven) {
      final product = ProductStore.productFromPost(post);
      current.push(MaterialPageRoute(builder: (_) => detailScreen(product)));
      return;
    }
    if (!context.mounted) return;
    final l10n = context.l10n;
    final message = failed
        ? l10n.postLinkFailed
        : post == null
        ? l10n.postLinkNotFound
        : l10n.postLinkGivenAway;
    AppSnackbar.show(
      context,
      message,
      icon: post?.isGiven == true
          ? Icons.volunteer_activism
          : Icons.info_outline,
      color: failed ? AppColors.error : AppColors.primary,
    );
  }

  @visibleForTesting
  static void resetForTest() {
    _pendingPostId = null;
    _dashboards = 0;
    repository = PostRepository.new;
    detailScreen = _detailScreen;
  }
}
