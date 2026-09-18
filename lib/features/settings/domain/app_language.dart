class AppLanguage {
  final String code;
  final String name;
  final String nativeName;

  const AppLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
  });
}

const List<AppLanguage> kSupportedLanguages = [
  AppLanguage(code: 'en', name: 'English', nativeName: 'English'),
  AppLanguage(code: 'ur', name: 'Urdu', nativeName: 'اردو'),
  AppLanguage(code: 'ar', name: 'Arabic', nativeName: 'العربية'),
  AppLanguage(code: 'es', name: 'Spanish', nativeName: 'Español'),
  AppLanguage(code: 'fr', name: 'French', nativeName: 'Français'),
  AppLanguage(code: 'hi', name: 'Hindi', nativeName: 'हिन्दी'),
  AppLanguage(code: 'zh', name: 'Chinese', nativeName: '中文'),
  AppLanguage(code: 'de', name: 'German', nativeName: 'Deutsch'),
];
