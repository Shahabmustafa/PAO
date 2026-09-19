import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pao/features/auth/presentation/screens/reset_password_screen.dart';

import '../helpers/test_app.dart';

void main() {
  setUpAll(initFakeSupabase);

  Future<void> pumpReset(WidgetTester tester, {Locale? locale}) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(
      testApp(const ResetPasswordScreen(), locale: locale ?? const Locale('en')),
    );
  }

  // The labels are separate Text widgets above the fields, so pick by order.
  Finder field(String label) => find
      .byType(TextFormField)
      .at(label == 'New Password' ? 0 : 1);

  testWidgets('shows the new-password form', (tester) async {
    await pumpReset(tester);

    expect(find.text('Reset Password'), findsOneWidget);
    expect(find.text('Choose a new password for your account.'), findsOneWidget);
    expect(find.text('New Password'), findsOneWidget);
    expect(find.text('Confirm Password'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Update Password'), findsOneWidget);
    expect(find.text('Back to Login'), findsOneWidget);
  });

  testWidgets('has no back arrow (the reset link is the only way in)', (
    tester,
  ) async {
    await pumpReset(tester);

    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('an empty form asks for a password', (tester) async {
    await pumpReset(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Update Password'));
    await tester.pump();

    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets('the password must be at least 6 characters', (tester) async {
    await pumpReset(tester);

    await tester.enterText(field('New Password'), '123');
    await tester.enterText(field('Confirm Password'), '123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Update Password'));
    await tester.pump();

    expect(find.text('Minimum 6 characters'), findsOneWidget);
  });

  testWidgets('the two passwords must match', (tester) async {
    await pumpReset(tester);

    await tester.enterText(field('New Password'), 'secret1');
    await tester.enterText(field('Confirm Password'), 'secret2');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Update Password'));
    await tester.pump();

    expect(find.text('Passwords do not match'), findsOneWidget);
  });

  testWidgets('is available in Urdu', (tester) async {
    await pumpReset(tester, locale: const Locale('ur'));

    expect(find.text('پاس ورڈ ری سیٹ کریں'), findsOneWidget);
    expect(find.text('نیا پاس ورڈ'), findsOneWidget);
    expect(find.text('پاس ورڈ اپ ڈیٹ کریں'), findsOneWidget);
    expect(find.text('Reset Password'), findsNothing);
  });
}
