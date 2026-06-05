import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../presentation/providers/auth_providers.dart';
import '../../shared/widgets/wabot_shell.dart';

class AppRoutes {
  static const splash = '/';
  static const login  = '/login';
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

      // Not logged in → always go to login
      if (key == null) {
        return loc == AppRoutes.login ? null : AppRoutes.login;
      }

      // Logged in → skip splash/login
      if (loc == AppRoutes.login || loc == AppRoutes.splash) {
        return AppRoutes.home;
      }
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: AppRoutes.login,  builder: (_, __) => const LoginScreen()),
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
