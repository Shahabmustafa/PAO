import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pao/core/routes/app_router.dart';
import 'package:pao/core/theme/theme_controller.dart';
import 'package:pao/core/utils/legal_links.dart';
import 'package:pao/features/settings/data/language_store.dart';
import 'package:pao/features/settings/domain/app_language.dart';
import 'package:pao/features/settings/presentation/screens/help_center_screen.dart';
import 'package:pao/features/settings/presentation/screens/language_screen.dart';
import 'package:pao/features/settings/presentation/screens/legal_document_screen.dart';
import 'package:pao/features/settings/presentation/screens/privacy_policy_screen.dart';
import 'package:pao/features/settings/presentation/screens/settings_screen.dart';
import 'package:pao/features/settings/presentation/screens/terms_conditions_screen.dart';
import 'package:pao/features/settings/presentation/screens/theme_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_app.dart';

const _launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');

/// Makes `launchUrl` succeed (or fail) and records every URL it is asked to
/// open, so tests can tell "opened the hosted page" from "used the fallback".
List<String> mockUrlLauncher({bool succeeds = true, bool missingPlugin = false}) {
  final launched = <String>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_launcherChannel, (call) async {
        if (missingPlugin) throw MissingPluginException();
        if (call.method == 'launch' || call.method == 'launchUrl') {
          final args = call.arguments as Map<Object?, Object?>;
          launched.add(args['url'] as String);
          return succeeds;
        }
        if (call.method == 'canLaunch') return succeeds;
        return null;
      });
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_launcherChannel, null),
  );
  return launched;
}

void main() {
  setUpAll(initFakeSupabase);

  group('LegalDocumentScreen', () {
    testWidgets('renders the title, date and every section', (tester) async {
      await tester.pumpWidget(
        testApp(
          const LegalDocumentScreen(
            title: 'My Policy',
            lastUpdated: 'January 1, 2026',
            sections: [
              LegalSection('1. First', 'First body'),
              LegalSection('2. Second', 'Second body'),
            ],
          ),
        ),
      );

      expect(find.text('My Policy'), findsOneWidget);
      expect(find.text('Last updated: January 1, 2026'), findsOneWidget);
      expect(find.text('1. First'), findsOneWidget);
      expect(find.text('First body'), findsOneWidget);
      expect(find.text('2. Second'), findsOneWidget);
      expect(find.text('Second body'), findsOneWidget);
    });
  });

  group('bundled legal screens', () {
    testWidgets('Terms & Conditions lists all 11 numbered sections', (
      tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(testApp(const TermsConditionsScreen()));

      expect(find.text('Terms & Conditions'), findsOneWidget);
      expect(find.text('1. Acceptance of Terms'), findsOneWidget);
      // The list is lazy: scroll to the last section.
      await tester.dragUntilVisible(
        find.text('11. Contact Us'),
        find.byType(ListView),
        const Offset(0, -300),
      );
      expect(find.text('11. Contact Us'), findsOneWidget);
    });

    testWidgets('Privacy Policy covers the key disclosures', (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(testApp(const PrivacyPolicyScreen()));

      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('1. Information We Collect'), findsOneWidget);
      await tester.dragUntilVisible(
        find.text('10. Contact Us'),
        find.byType(ListView),
        const Offset(0, -300),
      );
      expect(find.text('10. Contact Us'), findsOneWidget);
    });
  });

  group('LegalLinks (opens the hosted pages)', () {
    Future<BuildContext> pumpHost(WidgetTester tester) async {
      late BuildContext captured;
      await tester.pumpWidget(
        testApp(
          Builder(
            builder: (context) {
              captured = context;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      );
      return captured;
    }

    testWidgets('privacy policy opens the hosted URL, no fallback screen', (
      tester,
    ) async {
      final launched = mockUrlLauncher();
      final context = await pumpHost(tester);

      await LegalLinks.openPrivacyPolicy(context);
      await tester.pumpAndSettle();

      expect(launched, [LegalLinks.privacyPolicyUrl]);
      expect(find.byType(PrivacyPolicyScreen), findsNothing);
    });

    testWidgets('terms opens the hosted URL, no fallback screen', (
      tester,
    ) async {
      final launched = mockUrlLauncher();
      final context = await pumpHost(tester);

      await LegalLinks.openTerms(context);
      await tester.pumpAndSettle();

      expect(launched, [LegalLinks.termsUrl]);
      expect(find.byType(TermsConditionsScreen), findsNothing);
    });

    testWidgets('falls back to the bundled privacy policy if it cannot open', (
      tester,
    ) async {
      mockUrlLauncher(succeeds: false);
      final context = await pumpHost(tester);

      // Not awaited: the returned future completes only when the pushed
      // fallback page is popped.
      unawaited(LegalLinks.openPrivacyPolicy(context));
      await tester.pumpAndSettle();

      expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
    });

    testWidgets('falls back to the bundled terms if it cannot open', (
      tester,
    ) async {
      mockUrlLauncher(succeeds: false);
      final context = await pumpHost(tester);

      // Not awaited: the returned future completes only when the pushed
      // fallback page is popped.
      unawaited(LegalLinks.openTerms(context));
      await tester.pumpAndSettle();

      expect(find.byType(TermsConditionsScreen), findsOneWidget);
    });

    testWidgets('falls back when the platform has no launcher at all', (
      tester,
    ) async {
      mockUrlLauncher(missingPlugin: true);
      final context = await pumpHost(tester);

      // Not awaited: the returned future completes only when the pushed
      // fallback page is popped.
      unawaited(LegalLinks.openTerms(context));
      await tester.pumpAndSettle();

      expect(find.byType(TermsConditionsScreen), findsOneWidget);
    });
  });

  group('ThemeScreen', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ThemeController.themeMode.value = ThemeMode.light;
    });

    testWidgets('lists the three modes', (tester) async {
      await tester.pumpWidget(testApp(const ThemeScreen()));

      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('System Default'), findsOneWidget);
    });

    testWidgets('choosing Dark switches and persists the theme', (
      tester,
    ) async {
      await tester.pumpWidget(testApp(const ThemeScreen()));

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      expect(ThemeController.themeMode.value, ThemeMode.dark);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'dark');
    });

    testWidgets('choosing System Default follows the device', (tester) async {
      await tester.pumpWidget(testApp(const ThemeScreen()));

      await tester.tap(find.text('System Default'));
      await tester.pumpAndSettle();

      expect(ThemeController.themeMode.value, ThemeMode.system);
    });
  });

  group('LanguageScreen', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LanguageStore.select(kSupportedLanguages.first);
    });

    testWidgets('lists every supported language', (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(testApp(const LanguageScreen()));

      for (final language in kSupportedLanguages) {
        expect(find.text(language.name), findsWidgets, reason: language.name);
      }
    });

    testWidgets('search filters by English or native name', (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(testApp(const LanguageScreen()));

      await tester.enterText(find.byType(TextField), 'urd');
      await tester.pump();
      expect(find.text('Urdu'), findsOneWidget);
      expect(find.text('English'), findsNothing);

      await tester.enterText(find.byType(TextField), 'اردو');
      await tester.pump();
      expect(find.text('Urdu'), findsOneWidget);
      expect(find.text('English'), findsNothing);

      await tester.enterText(find.byType(TextField), 'Eng');
      await tester.pump();
      expect(find.text('English'), findsWidgets);
      expect(find.text('Urdu'), findsNothing);
    });

    testWidgets('a search with no match says so', (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(testApp(const LanguageScreen()));

      await tester.enterText(find.byType(TextField), 'klingon');
      await tester.pump();

      expect(find.text('No languages found'), findsOneWidget);
    });

    testWidgets('tapping a language selects it and confirms with a toast', (
      tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(testApp(const LanguageScreen()));

      await tester.tap(find.text('Urdu'));
      await pumpUntilToastVisible(tester);

      expect(LanguageStore.selected.value.code, 'ur');
      // The toast confirms in the language that was just picked.
      expect(find.text('زبان اردو پر سیٹ ہو گئی'), findsOneWidget);
      await settleToasts(tester);
    });
  });

  group('HelpCenterScreen', () {
    testWidgets('shows the FAQ heading and questions', (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(testApp(const HelpCenterScreen()));

      expect(find.text('Help Center'), findsOneWidget);
      expect(find.text('Frequently asked questions'), findsOneWidget);
      expect(find.text('How do I give away an item?'), findsOneWidget);
      expect(find.text('How do I delete my account?'), findsOneWidget);
    });
  });

  group('SettingsScreen', () {
    Future<void> pumpSettings(WidgetTester tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        testApp(
          const SettingsScreen(),
          onGenerateRoute: AppRouter.onGenerateRoute,
        ),
      );
      await tester.pump();
    }

    testWidgets('signed out: placeholder identity and every section', (
      tester,
    ) async {
      await pumpSettings(tester);

      expect(find.text('Your Name'), findsOneWidget);
      expect(find.text('your.email@example.com'), findsOneWidget);
      for (final label in [
        'Edit Profile',
        'Wishlist',
        'Language',
        'Theme',
        'Terms & Conditions',
        'Privacy Policy',
        'Help Center',
        'Logout',
        'Delete Account',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('the removed "Privacy & Security" tile stays removed', (
      tester,
    ) async {
      await pumpSettings(tester);

      expect(find.text('Privacy & Security'), findsNothing);
    });

    testWidgets('shows the current language and theme', (tester) async {
      SharedPreferences.setMockInitialValues({});
      LanguageStore.selected.value = kSupportedLanguages.firstWhere(
        (l) => l.code == 'ur',
      );
      ThemeController.themeMode.value = ThemeMode.dark;
      addTearDown(() {
        LanguageStore.selected.value = kSupportedLanguages.first;
        ThemeController.themeMode.value = ThemeMode.light;
      });

      await pumpSettings(tester);

      // The language tile names the selected language in its own script.
      expect(find.text('اردو'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
    });

    testWidgets('Theme tile opens the theme screen', (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.text('Theme'));
      await tester.pumpAndSettle();

      expect(find.byType(ThemeScreen), findsOneWidget);
    });

    testWidgets('Language tile opens the language screen', (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.text('Language'));
      await tester.pumpAndSettle();

      expect(find.byType(LanguageScreen), findsOneWidget);
    });

    testWidgets('Help Center tile opens help', (tester) async {
      await pumpSettings(tester);
      await tester.ensureVisible(find.text('Help Center'));

      await tester.tap(find.text('Help Center'));
      await tester.pumpAndSettle();

      expect(find.byType(HelpCenterScreen), findsOneWidget);
    });

    testWidgets('Privacy Policy tile opens the hosted page', (tester) async {
      final launched = mockUrlLauncher();
      await pumpSettings(tester);
      await tester.ensureVisible(find.text('Privacy Policy'));

      await tester.tap(find.text('Privacy Policy'));
      await tester.pumpAndSettle();

      expect(launched, [LegalLinks.privacyPolicyUrl]);
    });

    testWidgets('Terms tile opens the hosted page', (tester) async {
      final launched = mockUrlLauncher();
      await pumpSettings(tester);
      await tester.ensureVisible(find.text('Terms & Conditions'));

      await tester.tap(find.text('Terms & Conditions'));
      await tester.pumpAndSettle();

      expect(launched, [LegalLinks.termsUrl]);
    });

    testWidgets('Delete Account asks for confirmation and Cancel keeps it', (
      tester,
    ) async {
      await pumpSettings(tester);
      await tester.ensureVisible(find.text('Delete Account'));

      await tester.tap(find.text('Delete Account'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'This will permanently delete your account and all your data. This action cannot be undone.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('Logout returns to the login screen', (tester) async {
      await pumpSettings(tester);
      await tester.ensureVisible(find.text('Logout'));

      await tester.tap(find.text('Logout'));
      // Supabase's signOut does real (non-fake-async) work.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.byType(SettingsScreen), findsNothing);
    });
  });
}
