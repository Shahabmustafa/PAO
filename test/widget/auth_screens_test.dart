import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pao/core/routes/app_router.dart';
import 'package:pao/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:pao/features/auth/presentation/screens/login_screen.dart';
import 'package:pao/features/auth/presentation/screens/signup_screen.dart';

import '../helpers/test_app.dart';

/// Screens here build their own providers against a signed-out Supabase
/// client (see [initFakeSupabase]); everything below stays on the device
/// because form validation and the terms check stop the submit first.
void main() {
  setUpAll(initFakeSupabase);

  /// Text fields keep their hint as `hintText`, so find them through it.
  Finder byHint(String hint) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == hint,
  );

  group('LoginScreen', () {
    Future<void> pumpLogin(WidgetTester tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        testApp(const LoginScreen(), onGenerateRoute: AppRouter.onGenerateRoute),
      );
    }

    testWidgets('shows the welcome text, fields and actions', (tester) async {
      await pumpLogin(tester);

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Login to continue'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
      expect(find.text("Don't have an account? "), findsOneWidget);
      expect(find.text('Sign Up'), findsOneWidget);
    });

    testWidgets('empty form shows both required errors', (tester) async {
      await pumpLogin(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pump();

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('rejects an email without @', (tester) async {
      await pumpLogin(tester);

      await tester.enterText(byHint('Enter your email'), 'not-an-email');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pump();

      expect(find.text('Enter a valid email'), findsOneWidget);
    });

    testWidgets('rejects a password shorter than 6 characters', (tester) async {
      await pumpLogin(tester);

      await tester.enterText(byHint('Enter your email'), 'a@b.com');
      await tester.enterText(byHint('Enter your password'), '12345');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pump();

      expect(find.text('Minimum 6 characters'), findsOneWidget);
    });

    testWidgets('a valid form still needs the terms accepted', (tester) async {
      await pumpLogin(tester);

      await tester.enterText(byHint('Enter your email'), 'a@b.com');
      await tester.enterText(byHint('Enter your password'), 'secret1');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await pumpUntilToastVisible(tester);

      expect(
        find.text(
          'Please accept the Terms & Conditions and Privacy Policy to continue.',
        ),
        findsOneWidget,
      );
      await settleToasts(tester);
    });

    testWidgets('the password can be revealed and hidden', (tester) async {
      await pumpLogin(tester);
      TextField password() => tester.widget<TextField>(byHint('Enter your password'));
      expect(password().obscureText, isTrue);

      await tester.tap(find.descendant(
        of: find.ancestor(
          of: byHint('Enter your password'),
          matching: find.byType(TextFormField),
        ),
        matching: find.byType(IconButton),
      ));
      await tester.pump();

      expect(password().obscureText, isFalse);
    });

    testWidgets('"Sign Up" opens the sign up screen', (tester) async {
      await pumpLogin(tester);

      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      expect(find.text('Create Account'), findsOneWidget);
    });

    testWidgets('"Forgot Password?" opens the reset screen', (tester) async {
      await pumpLogin(tester);

      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();

      expect(find.text('Send Reset Link'), findsOneWidget);
    });

    testWidgets('renders in dark mode without layout errors', (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        testApp(const LoginScreen(), themeMode: ThemeMode.dark),
      );

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('SignupScreen', () {
    Future<void> pumpSignup(WidgetTester tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(testApp(const SignupScreen()));
    }

    testWidgets('shows every field', (tester) async {
      await pumpSignup(tester);

      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Sign Up'), findsOneWidget);
    });

    testWidgets('empty form shows the required errors', (tester) async {
      await pumpSignup(tester);

      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Sign Up'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
      await tester.pump();

      expect(find.text('Name is required'), findsOneWidget);
      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('passwords must match', (tester) async {
      await pumpSignup(tester);

      await tester.enterText(byHint('Enter your full name'), 'Ali');
      await tester.enterText(byHint('Enter your email'), 'a@b.com');
      await tester.enterText(byHint('Create a password'), 'secret1');
      await tester.enterText(byHint('Re-enter your password'), 'different');
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Sign Up'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
      await tester.pump();

      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('enforces the minimum password length', (tester) async {
      await pumpSignup(tester);

      await tester.enterText(byHint('Create a password'), 'abc');
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Sign Up'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
      await tester.pump();

      expect(find.text('Minimum 6 characters'), findsOneWidget);
    });

    testWidgets('a valid form still needs the terms accepted', (tester) async {
      await pumpSignup(tester);

      await tester.enterText(byHint('Enter your full name'), 'Ali');
      await tester.enterText(byHint('Enter your email'), 'a@b.com');
      await tester.enterText(byHint('Create a password'), 'secret1');
      await tester.enterText(byHint('Re-enter your password'), 'secret1');
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Sign Up'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
      await pumpUntilToastVisible(tester);

      expect(
        find.text(
          'Please accept the Terms & Conditions and Privacy Policy to continue.',
        ),
        findsOneWidget,
      );
      await settleToasts(tester);
    });

    testWidgets('"Login" goes back to the previous screen', (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        testApp(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SignupScreen()),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Login'));
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      expect(find.text('Create Account'), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });
  });

  group('ForgotPasswordScreen', () {
    Future<void> pumpForgot(WidgetTester tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(testApp(const ForgotPasswordScreen()));
    }

    testWidgets('shows the explanation and the send button', (tester) async {
      await pumpForgot(tester);

      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(
        find.textContaining("Enter your email and we'll send you a link"),
        findsOneWidget,
      );
      expect(find.widgetWithText(ElevatedButton, 'Send Reset Link'), findsOneWidget);
      expect(find.text('Back to Login'), findsOneWidget);
    });

    testWidgets('requires an email', (tester) async {
      await pumpForgot(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Send Reset Link'));
      await tester.pump();

      expect(find.text('Email is required'), findsOneWidget);
    });

    testWidgets('requires a valid email', (tester) async {
      await pumpForgot(tester);

      await tester.enterText(byHint('Enter your email'), 'nope');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Send Reset Link'));
      await tester.pump();

      expect(find.text('Enter a valid email'), findsOneWidget);
    });

    testWidgets('"Back to Login" pops the screen', (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        testApp(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Back to Login'));
      await tester.pumpAndSettle();

      expect(find.text('Forgot Password?'), findsNothing);
    });
  });
}
