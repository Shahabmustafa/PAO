// End-to-end tests: they launch the real app (real `main()`, real Supabase
// project from `.env`) on a device or desktop and drive it like a user.
//
// Run the always-safe flows on any device:
//
//   flutter test integration_test -d <device-id>
//
// To also run the signed-in journey, pass a dedicated test account (never a
// personal one). It must already exist and be email-confirmed:
//
//   flutter test integration_test -d <device-id> \
//     --dart-define=PAO_TEST_EMAIL=you@example.com \
//     --dart-define=PAO_TEST_PASSWORD=secret
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pao/main.dart' as app;

const _testEmail = String.fromEnvironment('PAO_TEST_EMAIL');
const _testPassword = String.fromEnvironment('PAO_TEST_PASSWORD');
const _hasAccount = _testEmail != '' && _testPassword != '';

/// Pumps frames until [finder] matches, or fails after [timeout]. Needed
/// because the splash screen's spinner never lets `pumpAndSettle` finish and
/// network calls complete in real time.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out after $timeout waiting for: $finder');
}

Finder byHint(String hint) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.hintText == hint,
);

Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> launch(WidgetTester tester) async {
    app.main();
    await tester.pump();
  }

  group('signed-out journey', () {
    testWidgets('splash leads to the login screen', (tester) async {
      await launch(tester);

      await pumpUntilFound(tester, find.text('Welcome Back'));

      expect(find.text('Login to continue'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
    });

    testWidgets('login validates input before contacting the server', (
      tester,
    ) async {
      await launch(tester);
      await pumpUntilFound(tester, find.text('Welcome Back'));

      // Empty form.
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();
      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);

      // Bad email, then short password.
      await tester.enterText(byHint('Enter your email'), 'not-an-email');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email'), findsOneWidget);

      await tester.enterText(byHint('Enter your email'), 'a@b.com');
      await tester.enterText(byHint('Enter your password'), '123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();
      expect(find.text('Minimum 6 characters'), findsOneWidget);
    });

    testWidgets('a valid form still requires accepting the terms', (
      tester,
    ) async {
      await launch(tester);
      await pumpUntilFound(tester, find.text('Welcome Back'));

      await tester.enterText(byHint('Enter your email'), 'a@b.com');
      await tester.enterText(byHint('Enter your password'), 'secret1');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));

      await pumpUntilFound(
        tester,
        find.text(
          'Please accept the Terms & Conditions and Privacy Policy to continue.',
        ),
      );
      // Still on the login screen.
      expect(find.text('Welcome Back'), findsOneWidget);
    });

    testWidgets('sign up form: navigate in, validate, and come back', (
      tester,
    ) async {
      await launch(tester);
      await pumpUntilFound(tester, find.text('Welcome Back'));

      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();
      expect(find.text('Create Account'), findsOneWidget);

      await scrollTo(tester, find.widgetWithText(ElevatedButton, 'Sign Up'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
      await tester.pumpAndSettle();
      expect(find.text('Name is required'), findsOneWidget);

      await tester.enterText(byHint('Create a password'), 'secret1');
      await tester.enterText(byHint('Re-enter your password'), 'different');
      await scrollTo(tester, find.widgetWithText(ElevatedButton, 'Sign Up'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
      await tester.pumpAndSettle();
      expect(find.text('Passwords do not match'), findsOneWidget);

      await scrollTo(tester, find.text('Login'));
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome Back'), findsOneWidget);
    });

    testWidgets('forgot password: open, validate, and go back', (tester) async {
      await launch(tester);
      await pumpUntilFound(tester, find.text('Welcome Back'));

      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();
      expect(find.text('Send Reset Link'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Send Reset Link'));
      await tester.pumpAndSettle();
      expect(find.text('Email is required'), findsOneWidget);

      await tester.tap(find.text('Back to Login'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome Back'), findsOneWidget);
    });
  });

  group('signed-in journey', () {
    testWidgets(
      'login, browse, switch theme, and log out',
      (tester) async {
        await launch(tester);
        await pumpUntilFound(tester, find.text('Welcome Back'));

        // --- Log in (accepting the terms first). -------------------------
        await tester.enterText(byHint('Enter your email'), _testEmail);
        await tester.enterText(byHint('Enter your password'), _testPassword);
        await tester.tap(find.byType(Checkbox));
        await tester.pump();
        await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
        await pumpUntilFound(tester, find.text('Welcome back 👋'));

        // --- The four tabs. ---------------------------------------------
        await tester.tap(find.text('Wishlist').last);
        await pumpUntilFound(tester, find.text('Wishlist').first);
        await tester.tap(find.text('Requests').last);
        await pumpUntilFound(tester, find.text('Sent'));
        expect(find.text('Received'), findsOneWidget);

        // --- Settings: identity is shown, theme can be changed. ---------
        await tester.tap(find.text('Settings').last);
        await pumpUntilFound(tester, find.text(_testEmail));

        await tester.tap(find.text('Theme'));
        await pumpUntilFound(tester, find.text('Choose how PAO looks'));
        await tester.tap(find.text('Dark'));
        await tester.pumpAndSettle();
        expect(
          Theme.of(tester.element(find.text('Choose how PAO looks'))).brightness,
          Brightness.dark,
        );
        // Put the theme back so later runs start from the default.
        await tester.tap(find.text('Light'));
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();

        // --- Log out. ---------------------------------------------------
        await scrollTo(tester, find.text('Logout'));
        await tester.tap(find.text('Logout'));
        await pumpUntilFound(tester, find.text('Welcome Back'));
      },
      skip: !_hasAccount,
    );
  });
}
