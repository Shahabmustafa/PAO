import 'package:flutter/widgets.dart';

class AppLanguage {
  final String code;
  final String name;
  final String nativeName;

  const AppLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
  });

  Locale get locale => Locale(code);

  /// Urdu is written right-to-left; everything else the app supports is LTR.
  bool get isRtl => code == 'ur';
}

const List<AppLanguage> kSupportedLanguages = [
  AppLanguage(code: 'en', name: 'English', nativeName: 'English'),
  AppLanguage(code: 'ur', name: 'Urdu', nativeName: 'اردو'),
];
