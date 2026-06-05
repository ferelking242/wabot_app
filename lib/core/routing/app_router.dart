import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/splash_screen.dart';
import '../../features/pairing/presentation/pairing_screen.dart';
import '../../presentation/providers/auth_providers.dart';
import '../../shared/widgets/wabot_shell.dart';

/// App route constants.
class AppRoutes {
  static const splash = '/';
  static const pair   = '/pair';
  static const home   = '/home';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.read(authProvider.notifier);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: _AuthListenable(ref, notifier),
    redirect: (ctx, state) {
      final loc       = state.matchedLocation;
      final setupDone = ref.read(authProvider); // bool? — null/false/true

      // Still loading from SharedPreferences → stay on splash
      if (!notifier.loaded) {
        return loc == AppRoutes.splash ? null : AppRoutes.splash;
      }

      // Splash is just a loading screen — always move on
      if (loc == AppRoutes.splash) {
        // setupDone == true → go straight to dashboard
        // setupDone != true → go to pairing (first launch or signed out)
        return setupDone == true ? AppRoutes.home : AppRoutes.pair;
      }

      // If on pairing and already set up → go to dashboard
      if (loc == AppRoutes.pair && setupDone == true) {
        return AppRoutes.home;
      }

      // If on home and not set up (sign-out) → back to pairing
      if (loc == AppRoutes.home && setupDone != true) {
        return AppRoutes.pair;
      }

      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: AppRoutes.pair,   builder: (_, __) => const PairingScreen()),
      GoRoute(path: AppRoutes.home,   builder: (_, __) => const WabotShell()),
    ],
  );
});

/// Listens to auth state changes + one-shot loaded signal
/// so GoRouter re-evaluates after async init completes.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref, AuthNotifier authNotifier) {
    ref.listen(authProvider, (_, __) => notifyListeners());
    authNotifier.loadedNotifier.addListener(notifyListeners);
  }
}
