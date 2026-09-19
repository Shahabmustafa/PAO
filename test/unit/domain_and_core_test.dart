import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pao/core/routes/app_router.dart';
import 'package:pao/core/routes/app_routes.dart';
import 'package:pao/core/theme/app_colors.dart';
import 'package:pao/core/theme/app_theme.dart';
import 'package:pao/core/utils/auth_error_message.dart';
import 'package:pao/core/utils/legal_links.dart';
import 'package:pao/features/home/domain/category.dart';
import 'package:pao/features/location/domain/pakistan_location.dart';
import 'package:pao/features/settings/domain/app_language.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('authErrorMessage', () {
    test('replaces a network failure with a friendly message', () {
      final message = authErrorMessage(
        AuthRetryableFetchException(
          message: 'ClientException with SocketException: Failed host lookup',
        ),
      );

      expect(message, contains('No internet connection'));
      expect(message, isNot(contains('SocketException')));
    });

    test('passes other auth errors through unchanged', () {
      expect(
        authErrorMessage(const AuthException('Invalid login credentials')),
        'Invalid login credentials',
      );
    });
  });

  group('Categories', () {
    test('start with All and have no duplicates', () {
      expect(kHomeCategories.first, 'All');
      expect(kHomeCategories.toSet().length, kHomeCategories.length);
    });
  });

  group('Pakistan locations', () {
    test('cover the 7 provinces / territories', () {
      expect(kPakistanProvinces, hasLength(7));
      expect(
        kPakistanProvinces.map((p) => p.name),
        containsAll([
          'Punjab',
          'Sindh',
          'Khyber Pakhtunkhwa',
          'Balochistan',
          'Gilgit-Baltistan',
          'Azad Jammu & Kashmir',
          'Islamabad Capital Territory',
        ]),
      );
    });

    test('every province has unique, non-empty cities', () {
      for (final province in kPakistanProvinces) {
        expect(province.cities, isNotEmpty, reason: province.name);
        expect(
          province.cities.toSet().length,
          province.cities.length,
          reason: '${province.name} has duplicate cities',
        );
      }
    });

    test('major cities sit under the right province', () {
      Province of(String name) =>
          kPakistanProvinces.firstWhere((p) => p.name == name);

      expect(of('Punjab').cities, contains('Lahore'));
      expect(of('Sindh').cities, contains('Karachi'));
      expect(of('Khyber Pakhtunkhwa').cities, contains('Peshawar'));
      expect(of('Balochistan').cities, contains('Quetta'));
      expect(of('Islamabad Capital Territory').cities, ['Islamabad']);
    });
  });

  group('Languages', () {
    test('English is the first / default language', () {
      expect(kSupportedLanguages.first.code, 'en');
    });

    test('codes are unique and every entry is fully populated', () {
      expect(
        kSupportedLanguages.map((l) => l.code).toSet().length,
        kSupportedLanguages.length,
      );
      for (final language in kSupportedLanguages) {
        expect(language.code, isNotEmpty);
        expect(language.name, isNotEmpty);
        expect(language.nativeName, isNotEmpty);
      }
    });

    test('includes Urdu', () {
      final urdu = kSupportedLanguages.firstWhere((l) => l.code == 'ur');
      expect(urdu.name, 'Urdu');
      expect(urdu.nativeName, 'اردو');
    });
  });

  group('Route table', () {
    test('every named route resolves to a page route', () {
      for (final name in [
        AppRoutes.splash,
        AppRoutes.login,
        AppRoutes.signup,
        AppRoutes.forgotPassword,
        AppRoutes.selectProvince,
        AppRoutes.dashboard,
      ]) {
        final route = AppRouter.onGenerateRoute(RouteSettings(name: name));
        expect(route, isA<MaterialPageRoute<dynamic>>(), reason: name);
        expect(route.settings.name, name);
      }
    });

    test('route names are unique', () {
      final names = [
        AppRoutes.splash,
        AppRoutes.login,
        AppRoutes.signup,
        AppRoutes.forgotPassword,
        AppRoutes.selectProvince,
        AppRoutes.dashboard,
      ];
      expect(names.toSet().length, names.length);
    });

    testWidgets('an unknown route shows a fallback page', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          // Route everything to an unknown name; going through initialRoute
          // '/nope' would also build '/' (the splash screen and its timer).
          onGenerateRoute: (_) => AppRouter.onGenerateRoute(
            const RouteSettings(name: '/nope'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No route defined for /nope'), findsOneWidget);
    });
  });

  group('Theme', () {
    test('light and dark themes use Material 3 brightness', () {
      expect(AppTheme.lightTheme.brightness, Brightness.light);
      expect(AppTheme.darkTheme.brightness, Brightness.dark);
    });

    test('brand color is consistent across the palette', () {
      expect(AppColors.primary, const Color(0xFFAEF503));
      expect(AppColors.onPrimary, Colors.black);
    });

    Future<BuildContext> pumpWithTheme(WidgetTester tester, ThemeData theme) async {
      late BuildContext captured;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      return captured;
    }

    testWidgets('color extension resolves the light variants', (tester) async {
      final context = await pumpWithTheme(tester, ThemeData.light());

      expect(context.isDarkMode, isFalse);
      expect(context.appBackground, AppColors.background);
      expect(context.appSurface, AppColors.surface);
      expect(context.appTextPrimary, AppColors.textPrimary);
      expect(context.appTextSecondary, AppColors.textSecondary);
      expect(context.appBorder, AppColors.border);
    });

    testWidgets('color extension resolves the dark variants', (tester) async {
      final context = await pumpWithTheme(tester, ThemeData.dark());

      expect(context.isDarkMode, isTrue);
      expect(context.appBackground, AppColorsDark.background);
      expect(context.appSurface, AppColorsDark.surface);
      expect(context.appTextPrimary, AppColorsDark.textPrimary);
      expect(context.appTextSecondary, AppColorsDark.textSecondary);
      expect(context.appBorder, AppColorsDark.border);
    });

    test('dark text is lighter than the dark background (readable)', () {
      expect(
        AppColorsDark.textPrimary.computeLuminance(),
        greaterThan(AppColorsDark.background.computeLuminance() + 0.5),
      );
      expect(
        AppColors.textPrimary.computeLuminance(),
        lessThan(AppColors.background.computeLuminance() - 0.5),
      );
    });
  });

  group('Assets', () {
    test('every AppIcons constant points at an SVG that exists', () {
      final source = File('lib/core/theme/app_icons.dart').readAsStringSync();
      final files = Directory('assets/icons')
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .toSet();

      final referenced = RegExp(
        r"'\$_base/([a-z0-9_]+\.svg)'",
      ).allMatches(source).map((m) => m.group(1)!).toList();

      expect(referenced, isNotEmpty);
      for (final name in referenced) {
        expect(files, contains(name), reason: 'missing assets/icons/$name');
      }
    });

    test('the logo and default avatar assets exist', () {
      expect(File('assets/images/logo.png').existsSync(), isTrue);
      expect(File('assets/images/splash_logo.png').existsSync(), isTrue);
      expect(File('assets/images/profile.jpg').existsSync(), isTrue);
    });
  });

  group('LegalLinks', () {
    test('URLs are https and point at published docs pages', () {
      for (final entry in {
        LegalLinks.privacyPolicyUrl: 'docs/privacy_policy.html',
        LegalLinks.termsUrl: 'docs/terms.html',
        LegalLinks.deleteAccountUrl: 'docs/delete-account.html',
      }.entries) {
        final uri = Uri.parse(entry.key);
        expect(uri.scheme, 'https', reason: entry.key);
        expect(uri.host, endsWith('github.io'), reason: entry.key);
        expect(
          File(entry.value).existsSync(),
          isTrue,
          reason: '${entry.value} must exist so ${entry.key} is not a 404',
        );
        expect(entry.key, endsWith(entry.value.split('/').last));
      }
    });

    test('hosted pages link to each other and to a contact email', () {
      final privacy = File('docs/privacy_policy.html').readAsStringSync();
      final terms = File('docs/terms.html').readAsStringSync();
      final delete = File('docs/delete-account.html').readAsStringSync();

      for (final page in [privacy, terms, delete]) {
        expect(page, contains('href="privacy_policy.html"'));
        expect(page, contains('href="terms.html"'));
        expect(page, contains('href="delete-account.html"'));
        expect(page, contains('href="style.css"'));
      }
      expect(privacy, contains('mailto:'));
      expect(delete, contains('Delete Account'));
      expect(File('docs/style.css').existsSync(), isTrue);
      expect(File('docs/logo.png').existsSync(), isTrue);
    });

    test('privacy policy discloses the data the app really stores', () {
      final privacy = File('docs/privacy_policy.html').readAsStringSync();
      for (final term in ['phone', 'Supabase', 'camera', 'Delete Account']) {
        expect(privacy.toLowerCase(), contains(term.toLowerCase()));
      }
    });
  });
}
