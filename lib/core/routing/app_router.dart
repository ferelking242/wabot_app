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
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: _AuthListenable(ref),
    redirect: (ctx, state) {
      final key = ref.read(authProvider);
      final loc = state.matchedLocation;
      if (key == null) {
        if (loc == AppRoutes.login || loc == AppRoutes.splash) return null;
        return AppRoutes.login;
      }
      if (loc == AppRoutes.login || loc == AppRoutes.splash) return AppRoutes.home;
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: AppRoutes.login,  builder: (_, __) => const LoginScreen()),
      GoRoute(path: AppRoutes.home,   builder: (_, __) => const WabotShell()),
    ],
  );
});

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}
