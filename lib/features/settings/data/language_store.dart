import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/app_language.dart';

/// Currently selected app language, shared between MyApp and the Settings >
/// Language screen. Persisted locally so the choice survives an app restart.
class LanguageStore {
  LanguageStore._();

  static const _prefsKey = 'language_code';

  static final ValueNotifier<AppLanguage> selected = ValueNotifier<AppLanguage>(
    kSupportedLanguages.first,
  );

  /// Loads the previously saved language from local storage, if any. Call
  /// once, before [runApp], so the right language applies from the first
  /// frame.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    selected.value = kSupportedLanguages.firstWhere(
      (language) => language.code == saved,
      orElse: () => kSupportedLanguages.first,
    );
  }

  static Future<void> select(AppLanguage language) async {
    selected.value = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, language.code);
  }
}
