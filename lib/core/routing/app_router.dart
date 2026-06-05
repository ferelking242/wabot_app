import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/pairing/presentation/pairing_screen.dart';
import '../../presentation/providers/auth_providers.dart';
import '../../shared/widgets/wabot_shell.dart';

class AppRoutes {
  static const splash = '/';
  static const login  = '/login';
  static const pair   = '/pair';
  static const home   = '/home';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.read(authProvider.notifier);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: _AuthListenable(ref, notifier),
    redirect: (ctx, state) {
      final key = ref.read(authProvider);
      final loc = state.matchedLocation;

      // Still loading from SharedPreferences — stay on splash
      if (!notifier.loaded) {
        return loc == AppRoutes.splash ? null : AppRoutes.splash;
      }

      // Not logged in → go to login (enter API key + URL)
      if (key == null) {
        return loc == AppRoutes.login ? null : AppRoutes.login;
      }

      // Logged in → skip splash/login, land on pairing screen first
      // The pairing screen auto-redirects to /home when WhatsApp is connected
      if (loc == AppRoutes.login || loc == AppRoutes.splash) {
        return AppRoutes.pair;
      }

      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: AppRoutes.login,  builder: (_, __) => const LoginScreen()),
      GoRoute(path: AppRoutes.pair,   builder: (_, __) => const PairingScreen()),
      GoRoute(path: AppRoutes.home,   builder: (_, __) => const WabotShell()),
    ],
  );
});

/// Listens to both auth state changes AND the one-shot loaded signal,
/// so GoRouter always re-evaluates the redirect after init completes.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref, AuthNotifier authNotifier) {
    ref.listen(authProvider, (_, __) => notifyListeners());
    authNotifier.loadedNotifier.addListener(notifyListeners);
  }
}
