import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:toastification/toastification.dart';
import 'core/auth/ban_watcher.dart';
import 'core/cache/local_cache.dart';
import 'core/config/supabase_config.dart';
import 'core/notifications/message_notifications.dart';
import 'core/notifications/push_notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/presence/presence_heartbeat.dart';
import 'core/routes/app_navigator.dart';
import 'core/routes/app_router.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/chat/data/chat_unread_store.dart';
import 'features/home/data/product_store.dart';
import 'features/requests/data/request_store.dart';
import 'features/settings/data/language_store.dart';
import 'features/settings/data/notification_settings_store.dart';
import 'features/settings/domain/app_language.dart';
import 'features/wishlist/data/wishlist_store.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  // Independent start-up work runs side by side instead of one after the
  // other; nothing here waits on a network round trip for content.
  await Future.wait([
    LocalCache.init(),
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
    NotificationSettingsStore.load(),
    ThemeController.load(),
    LanguageStore.load(),
  ]);
  FirebaseMessaging.onBackgroundMessage(pushBackgroundMessageHandler);
  _startLocalFirst();
  await PushNotificationService.initialize();
  PresenceHeartbeat.initialize();
  BanWatcher.initialize();
  AppNavigator.listenForPasswordRecovery();
  runApp(const MyApp());
}

/// Paints the last known content straight from Hive, then refreshes it from
/// Supabase in the background. Nothing here blocks the first frame.
void _startLocalFirst() {
  ProductStore.hydrateFromCache();
  RequestStore.hydrateFromCache();
  WishlistStore.hydrateFromCache();

  // Logout or account switch: drop everything held in memory too (the Hive
  // boxes were already wiped), so nothing leaks between accounts.
  LocalCache.accountChanged.listen((_) {
    ProductStore.reset();
    RequestStore.reset();
    WishlistStore.reset();
    ChatUnreadStore.reset();
  });

  if (Supabase.instance.client.auth.currentUser != null) {
    // Sends any wishlist change made offline and refreshes the rest.
    WishlistStore.syncFromSupabase().catchError((_) {});
  }
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
