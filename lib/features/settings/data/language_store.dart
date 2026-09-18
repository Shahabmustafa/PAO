import 'package:flutter/foundation.dart';
import '../domain/app_language.dart';

/// Currently selected app language, shared between the Settings and
/// Language screens. UI-only for now — does not localize app strings.
class LanguageStore {
  LanguageStore._();

  static final ValueNotifier<AppLanguage> selected = ValueNotifier<AppLanguage>(
    kSupportedLanguages.first,
  );

  static void select(AppLanguage language) {
    selected.value = language;
  }
}
