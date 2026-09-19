import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pao/core/l10n/l10n.dart';
import 'package:pao/core/utils/auth_error_message.dart';
import 'package:pao/features/home/domain/category.dart';
import 'package:pao/features/home/domain/localized_labels.dart';
import 'package:pao/features/location/domain/pakistan_location.dart';
import 'package:pao/features/location/domain/place_names.dart';
import 'package:pao/features/settings/data/language_store.dart';
import 'package:pao/features/settings/domain/app_language.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, dynamic> _arb(String locale) =>
    jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
        as Map<String, dynamic>;

Set<String> _messageKeys(Map<String, dynamic> arb) =>
    arb.keys.where((k) => !k.startsWith('@')).toSet();

void main() {
  group('ARB files', () {
    test('Urdu has exactly the same messages as English', () {
      final en = _messageKeys(_arb('en'));
      final ur = _messageKeys(_arb('ur'));

      expect(en.difference(ur), isEmpty, reason: 'missing from Urdu');
      expect(ur.difference(en), isEmpty, reason: 'missing from English');
    });

    test('no Urdu message is left empty or copied verbatim from English', () {
      final en = _arb('en');
      final ur = _arb('ur');
      // Brand / symbol-only strings that are legitimately identical.
      const sameInBoth = {'appTitle'};

      for (final key in _messageKeys(en)) {
        final urdu = ur[key] as String;
        final english = en[key] as String;
        if (english.isEmpty) continue; // e.g. termsAgreeSuffix in English
        expect(urdu.trim(), isNotEmpty, reason: key);
        if (!sameInBoth.contains(key)) {
          expect(urdu, isNot(english), reason: '$key was not translated');
        }
      }
    });

    test('Urdu messages keep every placeholder English uses', () {
      final en = _arb('en');
      final ur = _arb('ur');
      final placeholder = RegExp(r'\{(\w+)[,}]');

      for (final key in _messageKeys(en)) {
        final wanted = placeholder
            .allMatches(en[key] as String)
            .map((m) => m.group(1))
            .toSet();
        final actual = placeholder
            .allMatches(ur[key] as String)
            .map((m) => m.group(1))
            .toSet();
        expect(actual, wanted, reason: key);
      }
    });
  });

  group('AppLocalizations', () {
    test('every supported language has a translation bundle', () {
      for (final language in kSupportedLanguages) {
        expect(
          () => lookupAppLocalizations(language.locale),
          returnsNormally,
          reason: language.code,
        );
      }
    });

    test('unsupported languages are rejected', () {
      expect(
        () => lookupAppLocalizations(const Locale('fr')),
        throwsFlutterError,
      );
    });

    test('Urdu strings differ from English ones', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final ur = lookupAppLocalizations(const Locale('ur'));

      expect(en.login, 'Login');
      expect(ur.login, 'لاگ اِن');
    });

    test('placeholders are filled in', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final ur = lookupAppLocalizations(const Locale('ur'));

      expect(en.requestTo('Ali'), 'to Ali');
      expect(ur.requestTo('Ali'), 'Ali کو');
    });

    test('review count pluralises', () {
      final en = lookupAppLocalizations(const Locale('en'));

      expect(en.reviewCount(1), '1 review');
      expect(en.reviewCount(3), '3 reviews');
    });

    test('l10nNow follows the selected language', () {
      addTearDown(() => LanguageStore.selected.value = kSupportedLanguages.first);

      LanguageStore.selected.value = kSupportedLanguages.first;
      expect(l10nNow.login, 'Login');

      LanguageStore.selected.value = kSupportedLanguages.last;
      expect(l10nNow.login, 'لاگ اِن');
    });
  });

  group('labels for stored English values', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final ur = lookupAppLocalizations(const Locale('ur'));

    test('every home category has a label in both languages', () {
      for (final category in kHomeCategories) {
        expect(categoryLabel(en, category), category);
        expect(categoryLabel(ur, category), isNot(category));
      }
    });

    test('conditions and sort options are translated', () {
      expect(conditionLabel(ur, 'New'), 'نیا');
      expect(conditionLabel(ur, 'Used'), 'استعمال شدہ');
      expect(conditionLabel(ur, 'Old'), 'پرانا');
      expect(conditionLabel(ur, 'All'), ur.categoryAll);
      expect(sortLabel(ur, 'Newest'), 'نیا ترین');
    });

    test('unknown values fall back to what was stored', () {
      expect(categoryLabel(ur, 'Gadgets'), 'Gadgets');
      expect(conditionLabel(ur, 'Refurbished'), 'Refurbished');
      expect(sortLabel(ur, 'Oldest'), 'Oldest');
    });
  });

  group('authErrorMessage', () {
    setUp(() => LanguageStore.selected.value = kSupportedLanguages.first);
    tearDown(() => LanguageStore.selected.value = kSupportedLanguages.first);

    test('maps well-known server codes', () {
      expect(
        authErrorMessage(const AuthException('x', code: 'invalid_credentials')),
        'Incorrect email or password.',
      );
      expect(
        authErrorMessage(const AuthException('x', code: 'user_already_exists')),
        'An account with this email already exists.',
      );
    });

    test('translates to Urdu when Urdu is selected', () {
      LanguageStore.selected.value = kSupportedLanguages.last;

      expect(
        authErrorMessage(const AuthException('x', code: 'invalid_credentials')),
        'ای میل یا پاس ورڈ غلط ہے۔',
      );
    });

    test('offline errors get the friendly no-internet message', () {
      expect(
        authErrorMessage(AuthRetryableFetchException(message: 'SocketException')),
        contains('No internet connection'),
      );
    });

    test('unknown codes fall back to the server message', () {
      expect(
        authErrorMessage(const AuthException('Server said no', code: 'weird')),
        'Server said no',
      );
    });
  });

  group('place names', () {
    Future<void> pumpWithLocale(
      WidgetTester tester,
      Locale locale,
      void Function(BuildContext) check,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('ur')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) {
              check(context);
              return const SizedBox();
            },
          ),
        ),
      );
    }

    testWidgets('English keeps the stored name', (tester) async {
      await pumpWithLocale(tester, const Locale('en'), (context) {
        expect(placeName(context, 'Lahore'), 'Lahore');
      });
    });

    testWidgets('Urdu translates every province and city', (tester) async {
      await pumpWithLocale(tester, const Locale('ur'), (context) {
        for (final province in kPakistanProvinces) {
          expect(placeName(context, province.name), isNot(province.name));
          for (final city in province.cities) {
            expect(placeName(context, city), isNot(city), reason: city);
          }
        }
        expect(placeName(context, 'Lahore'), 'لاہور');
      });
    });

    testWidgets('unknown places fall back to the stored name', (tester) async {
      await pumpWithLocale(tester, const Locale('ur'), (context) {
        expect(placeName(context, 'Atlantis'), 'Atlantis');
      });
    });
  });
}
