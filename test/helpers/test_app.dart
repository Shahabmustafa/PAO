import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pao/core/theme/app_theme.dart';
import 'package:pao/features/settings/domain/app_language.dart';
import 'package:pao/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:toastification/toastification.dart';

bool _supabaseReady = false;

/// Initializes Supabase with throwaway credentials so screens that build
/// their own repositories (e.g. `LoginProvider()`) can be pumped offline.
/// The client is signed out and nothing here touches the network.
Future<void> initFakeSupabase() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  if (_supabaseReady) return;
  await Supabase.initialize(
    url: 'https://example.supabase.co',
    anonKey: 'fake-anon-key',
  );
  _supabaseReady = true;
}

/// Wraps [child] in a themed, localized [MaterialApp] (with the toast overlay
/// the app uses) so widgets can be pumped in isolation. Defaults to English;
/// pass `locale: const Locale('ur')` to render Urdu (right-to-left).
Widget testApp(
  Widget child, {
  ThemeMode themeMode = ThemeMode.light,
  Locale locale = const Locale('en'),
  Route<dynamic>? Function(RouteSettings)? onGenerateRoute,
  Map<String, WidgetBuilder>? routes,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    themeMode: themeMode,
    locale: locale,
    supportedLocales: [
      for (final language in kSupportedLanguages) language.locale,
    ],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
    routes: routes ?? const {},
    onGenerateRoute: onGenerateRoute,
    builder: (context, child) =>
        ToastificationWrapper(child: child ?? const SizedBox.shrink()),
  );
}

/// Gives the test a portrait surface to lay out on.
///
/// `flutter_test` renders text with the "Ahem" font, where every glyph is a
/// full em-square. Text is therefore roughly twice as wide as with the real
/// Roboto font, so a true 360 px phone width reports overflows that never
/// happen on a device (e.g. "Don't have an account? Sign Up" on one row).
/// A 600 px wide surface keeps Ahem text within the same proportions.
void usePhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(600, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Lets a toast (see `AppSnackbar`) finish its slide-in, so its text can be
/// found. Toasts appear roughly 600 ms after `show` and close after 2 s.
Future<void> pumpUntilToastVisible(WidgetTester tester) async {
  // Several small steps: the toast needs intermediate frames to build.
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// Runs out the toast's auto-close timer so no timer is left pending when
/// the test ends.
Future<void> settleToasts(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
}
