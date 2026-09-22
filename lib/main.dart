import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:toastification/toastification.dart';
import 'core/config/supabase_config.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/presence/presence_heartbeat.dart';
import 'core/routes/app_navigator.dart';
import 'core/routes/app_router.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/settings/data/language_store.dart';
import 'features/settings/data/notification_settings_store.dart';
import 'features/settings/domain/app_language.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationSettingsStore.load();
  await PushNotificationService.initialize();
  PresenceHeartbeat.initialize();
  AppNavigator.listenForPasswordRecovery();
  await ThemeController.load();
  await LanguageStore.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ThemeController.themeMode,
        LanguageStore.selected,
      ]),
      builder: (context, _) {
        final language = LanguageStore.selected.value;
        return MaterialApp(
          navigatorKey: AppNavigator.navigatorKey,
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeController.themeMode.value,
          locale: language.locale,
          supportedLocales: [
            for (final supported in kSupportedLanguages) supported.locale,
          ],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          initialRoute: AppRoutes.splash,
          onGenerateRoute: AppRouter.onGenerateRoute,
          builder: (context, child) =>
              ToastificationWrapper(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}
