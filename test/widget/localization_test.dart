import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pao/features/add_item/presentation/screens/add_item_screen.dart';
import 'package:pao/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:pao/features/auth/presentation/screens/login_screen.dart';
import 'package:pao/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:pao/features/auth/presentation/screens/signup_screen.dart';
import 'package:pao/features/location/presentation/screens/province_screen.dart';
import 'package:pao/features/settings/presentation/screens/edit_profile_screen.dart';
import 'package:pao/features/settings/presentation/screens/help_center_screen.dart';
import 'package:pao/features/settings/presentation/screens/language_screen.dart';
import 'package:pao/features/settings/presentation/screens/privacy_policy_screen.dart';
import 'package:pao/features/settings/presentation/screens/terms_conditions_screen.dart';
import 'package:pao/features/settings/presentation/screens/theme_screen.dart';

import '../helpers/test_app.dart';

const _urdu = Locale('ur');

void main() {
  setUpAll(initFakeSupabase);

  group('Urdu', () {
    testWidgets('lays the login screen out right-to-left in Urdu', (
      tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(testApp(const LoginScreen(), locale: _urdu));

      final direction = Directionality.of(
        tester.element(find.byType(Scaffold).first),
      );
      expect(direction, TextDirection.rtl);
    });

    testWidgets('the login screen is fully translated', (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(testApp(const LoginScreen(), locale: _urdu));

      expect(find.text('خوش آمدید'), findsOneWidget);
      expect(find.text('جاری رکھنے کے لیے لاگ اِن کریں'), findsOneWidget);
      expect(find.text('ای میل'), findsOneWidget);
      expect(find.text('پاس ورڈ بھول گئے؟'), findsOneWidget);
      // No English left behind.
      expect(find.text('Welcome Back'), findsNothing);
      expect(find.text('Forgot Password?'), findsNothing);
    });

    testWidgets('validation errors are shown in Urdu', (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(testApp(const LoginScreen(), locale: _urdu));

      await tester.tap(find.widgetWithText(ElevatedButton, 'لاگ اِن'));
      await tester.pump();

      expect(find.text('ای میل درکار ہے'), findsOneWidget);
      expect(find.text('پاس ورڈ درکار ہے'), findsOneWidget);
    });

    testWidgets('the theme screen is translated', (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(testApp(const ThemeScreen(), locale: _urdu));

      expect(find.text('لائٹ'), findsOneWidget);
      expect(find.text('ڈارک'), findsOneWidget);
      expect(find.text('سسٹم ڈیفالٹ'), findsOneWidget);
    });

    testWidgets('bundled legal documents are translated', (tester) async {
      usePhoneSurface(tester);

      await tester.pumpWidget(
        testApp(const PrivacyPolicyScreen(), locale: _urdu),
      );
      expect(find.text('رازداری کی پالیسی'), findsOneWidget);
      expect(find.text('آخری اپ ڈیٹ: 18 ستمبر 2026'), findsOneWidget);

      await tester.pumpWidget(
        testApp(const TermsConditionsScreen(), locale: _urdu),
      );
      expect(find.text('شرائط و ضوابط'), findsOneWidget);
    });
  });

  group('Urdu layout', () {
    final screens = <String, Widget Function()>{
      'LoginScreen': () => const LoginScreen(),
      'SignupScreen': () => const SignupScreen(),
      'ForgotPasswordScreen': () => const ForgotPasswordScreen(),
      'ResetPasswordScreen': () => const ResetPasswordScreen(),
      'ProvinceScreen': () => const ProvinceScreen(),
      'AddItemScreen': () => const AddItemScreen(),
      'EditProfileScreen': () => const EditProfileScreen(),
      'HelpCenterScreen': () => const HelpCenterScreen(),
      'LanguageScreen': () => const LanguageScreen(),
      'ThemeScreen': () => const ThemeScreen(),
      'PrivacyPolicyScreen': () => const PrivacyPolicyScreen(),
      'TermsConditionsScreen': () => const TermsConditionsScreen(),
    };

    for (final entry in screens.entries) {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        testWidgets('${entry.key} renders in Urdu (${mode.name}) without '
            'layout errors', (tester) async {
          usePhoneSurface(tester);
          await tester.pumpWidget(
            testApp(entry.value(), locale: _urdu, themeMode: mode),
          );
          await tester.pump();

          expect(tester.takeException(), isNull);
          expect(
            Directionality.of(tester.element(find.byType(Scaffold).first)),
            TextDirection.rtl,
          );
        });
      }
    }
  });

  group('English', () {
    testWidgets('is still the default and reads left-to-right', (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(testApp(const LoginScreen()));

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(Scaffold).first)),
        TextDirection.ltr,
      );
    });
  });
}
