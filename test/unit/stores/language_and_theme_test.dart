import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pao/core/theme/theme_controller.dart';
import 'package:pao/features/settings/data/language_store.dart';
import 'package:pao/features/settings/domain/app_language.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LanguageStore', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LanguageStore.select(kSupportedLanguages.first);
    });

    test('only English and Urdu are supported', () {
      expect(kSupportedLanguages.map((l) => l.code), ['en', 'ur']);
    });

    test('Urdu is right-to-left, English is not', () {
      final byCode = {for (final l in kSupportedLanguages) l.code: l};
      expect(byCode['ur']!.isRtl, isTrue);
      expect(byCode['en']!.isRtl, isFalse);
    });

    test('defaults to English', () {
      expect(LanguageStore.selected.value.code, 'en');
    });

    test('select updates the value and notifies listeners', () {
      final seen = <String>[];
      void listener() => seen.add(LanguageStore.selected.value.code);
      LanguageStore.selected.addListener(listener);
      addTearDown(() => LanguageStore.selected.removeListener(listener));

      final urdu = kSupportedLanguages.firstWhere((l) => l.code == 'ur');
      LanguageStore.select(urdu);

      expect(LanguageStore.selected.value, urdu);
      expect(seen, ['ur']);
    });

    test('select persists the choice', () async {
      final urdu = kSupportedLanguages.firstWhere((l) => l.code == 'ur');

      await LanguageStore.select(urdu);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('language_code'), 'ur');
    });

    test('load restores the saved language', () async {
      SharedPreferences.setMockInitialValues({'language_code': 'ur'});
      LanguageStore.selected.value = kSupportedLanguages.first;

      await LanguageStore.load();

      expect(LanguageStore.selected.value.code, 'ur');
    });

    test('load defaults to English when nothing is saved', () async {
      SharedPreferences.setMockInitialValues({});
      LanguageStore.selected.value = kSupportedLanguages.last;

      await LanguageStore.load();

      expect(LanguageStore.selected.value.code, 'en');
    });

    test('load ignores a language that is no longer supported', () async {
      SharedPreferences.setMockInitialValues({'language_code': 'fr'});
      LanguageStore.selected.value = kSupportedLanguages.last;

      await LanguageStore.load();

      expect(LanguageStore.selected.value.code, 'en');
    });
  });

  group('ThemeController', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ThemeController.themeMode.value = ThemeMode.light;
    });

    test('load defaults to light when nothing is saved', () async {
      ThemeController.themeMode.value = ThemeMode.dark;

      await ThemeController.load();

      expect(ThemeController.themeMode.value, ThemeMode.light);
    });

    test('load restores each saved mode', () async {
      for (final mode in ThemeMode.values) {
        SharedPreferences.setMockInitialValues({'theme_mode': mode.name});
        ThemeController.themeMode.value = ThemeMode.light;

        await ThemeController.load();

        expect(ThemeController.themeMode.value, mode, reason: mode.name);
      }
    });

    test('load ignores a corrupt saved value', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'purple'});
      ThemeController.themeMode.value = ThemeMode.dark;

      await ThemeController.load();

      expect(ThemeController.themeMode.value, ThemeMode.light);
    });

    test('setThemeMode updates the notifier and persists the choice', () async {
      await ThemeController.setThemeMode(ThemeMode.dark);

      expect(ThemeController.themeMode.value, ThemeMode.dark);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'dark');
    });

    test('a saved choice survives a "restart" (load after set)', () async {
      await ThemeController.setThemeMode(ThemeMode.system);
      ThemeController.themeMode.value = ThemeMode.light; // simulate new launch

      await ThemeController.load();

      expect(ThemeController.themeMode.value, ThemeMode.system);
    });
  });
}
