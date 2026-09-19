import 'package:flutter/widgets.dart';
import '../../features/settings/data/language_store.dart';
import '../../l10n/app_localizations.dart';

export '../../l10n/app_localizations.dart';

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// The strings for the language currently selected in [LanguageStore], for
/// code that has no [BuildContext] (providers, error mappers).
AppLocalizations get l10nNow =>
    lookupAppLocalizations(LanguageStore.selected.value.locale);
