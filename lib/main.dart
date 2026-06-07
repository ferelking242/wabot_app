import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'core/config/app_config.dart';
import 'core/routing/app_router.dart';
import 'core/services/bot_service.dart';
import 'core/services/log_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Logs professionnels (fichier + mémoire) ──────────────────────────
  await LogService.I.init();
  LogService.info('Main', 'Wabot démarrage — v1.1.0');

  // Capturer les erreurs Flutter non gérées
  FlutterError.onError = (details) {
    LogService.error('FlutterError',
        details.exceptionAsString(),
        err: details.exception,
        stack: details.stack);
    FlutterError.presentError(details);
  };

  // Capturer les erreurs async non gérées
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    LogService.error('AsyncError', error.toString(), err: error, stack: stack);
    return false;
  };

  await StorageService.init();

  // Démarrage bot embedded Android (non-bloquant)
  unawaited(BotService.startIfNeeded());

  runApp(const ProviderScope(child: WabotApp()));
}

class WabotApp extends ConsumerWidget {
  const WabotApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme  = ref.watch(themeControllerProvider);
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme:      AppTheme.light(accent: theme.accent),
      darkTheme:  AppTheme.dark(accent: theme.accent),
      themeMode:  theme.mode,
      routerConfig: router,
      builder: (ctx, child) => ResponsiveBreakpoints.builder(
        breakpoints: const [
          Breakpoint(start: 0,    end: 480,             name: MOBILE),
          Breakpoint(start: 481,  end: 900,             name: TABLET),
          Breakpoint(start: 901,  end: 1920,            name: DESKTOP),
          Breakpoint(start: 1921, end: double.infinity, name: '4K'),
        ],
        child: child!,
      ),
    );
  }
}
