import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pao/core/deep_links/post_links.dart';
import 'package:pao/core/notifications/notification_router.dart';
import 'package:pao/core/routes/app_navigator.dart';
import 'package:pao/features/add_item/data/model/post_model.dart';

import '../helpers/fakes.dart';
import '../helpers/test_app.dart';

PostModel _post({bool isGiven = false}) => PostModel(
  id: 'p1',
  userId: 'owner',
  title: 'Old sofa',
  createdAt: DateTime(2026, 10, 1),
  isGiven: isGiven,
);

void main() {
  group('PostLinks URLs', () {
    test('share link round-trips to the post id', () {
      final url = PostLinks.urlFor('abc-123');
      expect(url, 'https://shahabmustafa.github.io/PAO/post.html?id=abc-123');
      expect(PostLinks.postIdFrom(Uri.parse(url)), 'abc-123');
    });

    test('accepts the app scheme the web page forwards to', () {
      expect(
        PostLinks.postIdFrom(Uri.parse('com.pao.pao://post?id=abc')),
        'abc',
      );
    });

    test('ignores other links', () {
      for (final link in [
        'com.pao.pao://reset-callback/?code=x',
        'com.pao.pao://post',
        'https://shahabmustafa.github.io/PAO/privacy_policy.html?id=abc',
        'https://example.com/PAO/post.html?id=abc',
      ]) {
        expect(PostLinks.postIdFrom(Uri.parse(link)), isNull, reason: link);
      }
    });
  });

  group('PostLinks opening', () {
    late FakePostRepository posts;

    setUpAll(initFakeSupabase);

    setUp(() {
      PostLinks.resetForTest();
      NotificationRouter.requestedTab.value = null;
      posts = FakePostRepository();
      PostLinks.repository = () => posts;
      PostLinks.detailScreen = (product) =>
          Scaffold(body: Text('detail:${product.name}'));
    });

    tearDown(PostLinks.resetForTest);

    Future<void> pumpDashboard(WidgetTester tester) => tester.pumpWidget(
      testApp(
        const Scaffold(body: Text('dashboard')),
        navigatorKey: AppNavigator.navigatorKey,
      ),
    );

    testWidgets('an available post opens its detail screen', (tester) async {
      posts.byId['p1'] = _post();
      await pumpDashboard(tester);

      PostLinks.handle(Uri.parse(PostLinks.urlFor('p1')));
      PostLinks.dashboardShown();
      await tester.pumpAndSettle();

      expect(find.text('detail:Old sofa'), findsOneWidget);
      expect(
        NotificationRouter.requestedTab.value,
        NotificationRouter.homeTabIndex,
      );
    });

    testWidgets('waits for the dashboard before opening', (tester) async {
      posts.byId['p1'] = _post();
      await pumpDashboard(tester);

      PostLinks.handle(Uri.parse(PostLinks.urlFor('p1')));
      await tester.pumpAndSettle();
      expect(find.text('detail:Old sofa'), findsNothing);

      PostLinks.dashboardShown();
      await tester.pumpAndSettle();
      expect(find.text('detail:Old sofa'), findsOneWidget);
    });

    testWidgets('a given-away post stays on Home with a note', (tester) async {
      posts.byId['p1'] = _post(isGiven: true);
      await pumpDashboard(tester);
      PostLinks.dashboardShown();

      PostLinks.handle(Uri.parse(PostLinks.urlFor('p1')));
      await pumpUntilToastVisible(tester);

      expect(find.textContaining('already been given away'), findsOneWidget);
      expect(find.textContaining('detail:'), findsNothing);
      await settleToasts(tester);
    });

    testWidgets('a deleted post shows that it is unavailable', (tester) async {
      await pumpDashboard(tester);
      PostLinks.dashboardShown();

      PostLinks.handle(Uri.parse(PostLinks.urlFor('missing')));
      await pumpUntilToastVisible(tester);

      expect(find.text('This post is no longer available.'), findsOneWidget);
      await settleToasts(tester);
    });
  });
}
