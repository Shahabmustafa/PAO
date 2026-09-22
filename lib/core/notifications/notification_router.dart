import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../l10n/l10n.dart';
import '../routes/app_navigator.dart';
import '../routes/app_routes.dart';
import '../../features/add_item/data/repository/post_repository.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/requests/data/repository/request_repository.dart';

/// Where a tapped push notification should take the user. [DashboardScreen]
/// listens to [requestedTab] and switches to it; this class only records the
/// intent, since a plain navigation stack push can't reach into a sibling
/// tab of an already-mounted [DashboardScreen].
class NotificationRouter {
  NotificationRouter._();

  /// The tab [DashboardScreen] should switch to, or `null` when nothing is
  /// pending. Matches the tab order in `DashboardScreen._screens`.
  static final ValueNotifier<int?> requestedTab = ValueNotifier<int?>(null);

  static const int requestsTabIndex = 3;

  /// Lands on the Requests tab, then opens the specific chat a message/
  /// request notification is about (fetching the request and its post,
  /// since a notification only carries the request id). Works whether the
  /// notification was tapped from the foreground, background, or a fully
  /// terminated app. If the fetch fails -- e.g. no network right after
  /// launch -- the user is still left on the Requests tab rather than
  /// stuck on nothing.
  static Future<void> openChat(String requestId) async {
    openRequestsTab();

    try {
      final request = await RequestRepository().fetchRequestById(requestId);
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (request == null || currentUserId == null) return;

      final otherUserId = request.requesterId == currentUserId
          ? request.ownerId
          : request.requesterId;
      final post = await PostRepository().fetchPostById(request.postId);

      final navigator = AppNavigator.navigatorKey.currentState;
      if (navigator == null) return;
      navigator.push(
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            request: request,
            otherUserId: otherUserId,
            productName: post?.title ?? navigator.context.l10n.paoItem,
          ),
        ),
      );
    } catch (_) {
      // The Requests tab opened above is a reasonable fallback.
    }
  }

  /// Opens the Requests tab alone, with no specific chat -- used as the
  /// landing step of [openChat] and for any notification that doesn't
  /// carry a request id.
  static void openRequestsTab() {
    requestedTab.value = requestsTabIndex;
    AppNavigator.navigatorKey.currentState?.pushNamedAndRemoveUntil(
      AppRoutes.dashboard,
      (route) => false,
    );
  }
}
