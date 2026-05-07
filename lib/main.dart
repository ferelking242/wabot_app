import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:window_manager/window_manager.dart';
import 'router/app_router.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';
import 'core/constants/app_constants.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) {
  final saved = StorageService.getString(AppConstants.keyThemeMode);
  return switch (saved) {
    'light' => ThemeMode.light,
    'system' => ThemeMode.system,
    _ => ThemeMode.dark,
  };
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop window setup
  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    await windowManager.ensureInitialized();
    const opts = WindowOptions(
      size: Size(1280, 800),
      minimumSize: Size(900, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      title: AppConstants.appName,
    );
    windowManager.waitUntilReadyToShow(opts, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  await StorageService.init();

  runApp(const ProviderScope(child: WabotApp()));
}

class WabotApp extends ConsumerWidget {
  const WabotApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) => ResponsiveBreakpoints.builder(
        child: child!,
        breakpoints: const [
          Breakpoint(start: 0, end: 599, name: MOBILE),
          Breakpoint(start: 600, end: 899, name: TABLET),
          Breakpoint(start: 900, end: 1199, name: DESKTOP),
          Breakpoint(start: 1200, end: double.infinity, name: '4K'),
        ],
      ),
    );
  }
}
