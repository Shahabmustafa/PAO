import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pao/core/theme/theme_controller.dart';
import 'package:pao/core/widgets/app_icon.dart';
import 'package:pao/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:pao/features/home/data/product_store.dart';
import 'package:pao/features/requests/data/request_store.dart';
import 'package:pao/features/requests/presentation/screens/requests_screen.dart';
import 'package:pao/features/splash/presentation/screens/splash_screen.dart';
import 'package:pao/main.dart';

import '../helpers/fakes.dart';
import '../helpers/test_app.dart';

void main() {
  setUpAll(() async {
    await initFakeSupabase();
    ProductStore.startRealtimeSync(repository: FakePostRepository());
  });

  setUp(() {
    ProductStore.items.value = [];
    ProductStore.isLoading.value = false;
    RequestStore.reset();
    ThemeController.themeMode.value = ThemeMode.light;
  });

  group('MyApp / SplashScreen', () {
    testWidgets('launches on the splash screen with the logo and a spinner', (
      tester,
    ) async {
      await tester.pumpWidget(const MyApp());

      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Run out the splash delay so no timer is left pending.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    });

    testWidgets('a signed-out user lands on the login screen after 2s', (
      tester,
    ) async {
      await tester.pumpWidget(const MyApp());

      await tester.pump(const Duration(seconds: 1));
      expect(
        find.byType(SplashScreen),
        findsOneWidget,
        reason: 'still splash at 1s',
      );

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.byType(SplashScreen), findsNothing);
      expect(find.text('Welcome Back'), findsOneWidget);
    });

    testWidgets('the app follows the saved theme mode', (tester) async {
      ThemeController.themeMode.value = ThemeMode.dark;
      await tester.pumpWidget(const MyApp());
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);
      expect(
        Theme.of(tester.element(find.text('Welcome Back'))).brightness,
        Brightness.dark,
      );
    });

    testWidgets('switching the theme at runtime re-themes the app', (
      tester,
    ) async {
      await tester.pumpWidget(const MyApp());
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.text('Welcome Back'))).brightness,
        Brightness.light,
      );

      ThemeController.themeMode.value = ThemeMode.dark;
      await tester.pumpAndSettle();

      expect(
        Theme.of(tester.element(find.text('Welcome Back'))).brightness,
        Brightness.dark,
      );
    });

    testWidgets('has the app title and hides the debug banner', (tester) async {
      await tester.pumpWidget(const MyApp());
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

      // The title is localised (`onGenerateTitle`), so read what was built.
      expect(tester.widget<Title>(find.byType(Title)).title, 'PAO');
      expect(app.debugShowCheckedModeBanner, isFalse);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    });
  });

  group('RequestsScreen', () {
    Future<void> pumpRequests(WidgetTester tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(testApp(const RequestsScreen()));
      await tester.pump();
    }

    testWidgets('has Sent and Received tabs, starting on Sent', (tester) async {
      await pumpRequests(tester);

      expect(find.text('Requests'), findsOneWidget);
      expect(find.text('Sent'), findsOneWidget);
      expect(find.text('Received'), findsOneWidget);
      expect(find.text('No requests yet'), findsOneWidget);
      expect(
        find.text('Tap "Give Me" on a product to request it'),
        findsOneWidget,
      );
    });

    testWidgets('the Received tab has its own empty message', (tester) async {
      await pumpRequests(tester);

      await tester.tap(find.text('Received'));
      await tester.pumpAndSettle();

      expect(find.text('No requests yet'), findsOneWidget);
      expect(
        find.text('Requests for the items you post will show up here'),
        findsOneWidget,
      );
    });

    // Regression: each tile's provider is created once with its request, so
    // after "Accept & Give" the tile kept showing the old status and button
    // until the screen was rebuilt from scratch.
    testWidgets('a received request stops offering Accept once accepted', (
      tester,
    ) async {
      ProductStore.items.value = [
        ProductStore.productFromPost(makePost(id: 'post-1')),
      ];
      await pumpRequests(tester);
      // Signed out, the screen clears the store on start, so fill it after.
      RequestStore.received.value = [makeRequest()];
      await tester.tap(find.text('Received'));
      await tester.pump(); // starts the tab animation
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Accept & Give'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);

      RequestStore.received.value = [makeRequest(status: 'accepted')];
      await tester.pump();

      expect(find.text('Accept & Give'), findsNothing);
      expect(find.text('Pending'), findsNothing);
      expect(find.text('Given to you'), findsOneWidget);
    });

    testWidgets('a sent request shows Leave Feedback once it is accepted', (
      tester,
    ) async {
      ProductStore.items.value = [
        ProductStore.productFromPost(makePost(id: 'post-1')),
      ];
      await pumpRequests(tester);
      RequestStore.sent.value = [makeRequest()];
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Leave Feedback'), findsNothing);

      RequestStore.sent.value = [makeRequest(status: 'accepted')];
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Pending'), findsNothing);
      expect(find.text('Given to you'), findsOneWidget);
      expect(find.text('Leave Feedback'), findsOneWidget);
    });
  });

  group('DashboardScreen', () {
    Future<void> pumpDashboard(WidgetTester tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(testApp(const DashboardScreen()));
      await tester.pump();
    }

    testWidgets('opens on Home with the four tabs and the add button', (
      tester,
    ) async {
      await pumpDashboard(tester);

      expect(find.text('Welcome back 👋'), findsOneWidget);
      for (final label in ['Home', 'Wishlist', 'Requests', 'Settings']) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      expect(
        find.text('Search'),
        findsNothing,
        reason: 'Search tab was replaced',
      );
      expect(find.text('Inbox'), findsNothing, reason: 'Inbox tab was renamed');
    });

    group('Requests badge', () {
      // The badge is the only "1"/"2"/… text the dashboard shows.
      Finder badge(String count) => find.text(count);

      testWidgets('is hidden when nothing is waiting for an answer', (
        tester,
      ) async {
        await pumpDashboard(tester);

        expect(badge('1'), findsNothing);
        expect(badge('0'), findsNothing);
      });

      testWidgets('counts received requests that are still pending', (
        tester,
      ) async {
        await pumpDashboard(tester);

        // Set after the first pump, as the realtime stream would: the
        // Requests screen clears the store while it starts up.
        RequestStore.received.value = [
          makeRequest(id: 'a'),
          makeRequest(id: 'b'),
          makeRequest(id: 'c', status: 'accepted'),
          makeRequest(id: 'd', status: 'closed'),
        ];
        await tester.pump();

        expect(badge('2'), findsOneWidget);
      });

      testWidgets('ignores requests the user sent', (tester) async {
        await pumpDashboard(tester);

        RequestStore.sent.value = [makeRequest()];
        await tester.pump();

        expect(badge('1'), findsNothing);
      });

      testWidgets('updates live when a request arrives or is answered', (
        tester,
      ) async {
        await pumpDashboard(tester);
        expect(badge('1'), findsNothing);

        RequestStore.received.value = [makeRequest(id: 'a')];
        await tester.pump();
        expect(badge('1'), findsOneWidget);

        RequestStore.received.value = [makeRequest(id: 'a', status: 'accepted')];
        await tester.pump();
        expect(badge('1'), findsNothing);
      });

      testWidgets('caps a large count at 99+', (tester) async {
        await pumpDashboard(tester);

        RequestStore.received.value = [
          for (var i = 0; i < 120; i++) makeRequest(id: 'r$i'),
        ];
        await tester.pump();

        expect(badge('99+'), findsOneWidget);
      });
    });

    testWidgets('each tab shows its screen', (tester) async {
      await pumpDashboard(tester);

      await tester.tap(find.text('Wishlist').last);
      await tester.pumpAndSettle();
      expect(find.text('Your wishlist is empty'), findsOneWidget);

      await tester.tap(find.text('Requests').last);
      await tester.pumpAndSettle();
      expect(find.text('Sent'), findsOneWidget);

      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      expect(find.text('Your Name'), findsOneWidget);

      await tester.tap(find.text('Home').last);
      await tester.pumpAndSettle();
      expect(find.text('Welcome back 👋'), findsOneWidget);
    });

    testWidgets('the centre button opens Add Product', (tester) async {
      await pumpDashboard(tester);

      // The create button is the only nav element that is not a labelled tab:
      // an AppIcon inside a circle, positioned above the bar.
      final createButton = find.byWidgetPredicate(
        (w) => w is InkWell && w.borderRadius == BorderRadius.circular(28),
      );
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      expect(find.text('Photos'), findsOneWidget);
      expect(find.byType(AppIcon), findsWidgets);
    });

    testWidgets('renders in dark mode without layout errors', (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        testApp(const DashboardScreen(), themeMode: ThemeMode.dark),
      );
      await tester.pump();

      expect(find.text('Welcome back 👋'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
