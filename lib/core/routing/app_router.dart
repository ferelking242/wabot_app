import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/splash_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/pairing/presentation/pairing_screen.dart';
import '../../presentation/providers/auth_providers.dart';
import '../../shared/widgets/wabot_shell.dart';

class AppRoutes {
  static const splash     = '/';
  static const onboarding = '/onboarding';
  static const pair       = '/pair';
  static const home       = '/home';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.read(authProvider.notifier);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: _AuthListenable(ref, notifier),
    redirect: (ctx, state) {
      final loc       = state.matchedLocation;
      final setupDone = ref.read(authProvider);

      // Toujours attendre que SharedPreferences soit chargé
      if (!notifier.loaded) {
        return loc == AppRoutes.splash ? null : AppRoutes.splash;
      }

      // Splash → redirect selon l'état
      if (loc == AppRoutes.splash) {
        if (setupDone == true)           return AppRoutes.home;
        if (!notifier.onboardingDone)    return AppRoutes.onboarding;
        return AppRoutes.pair;
      }

      // Onboarding terminé → aller au pairing
      if (loc == AppRoutes.onboarding && notifier.onboardingDone) {
        return setupDone == true ? AppRoutes.home : AppRoutes.pair;
      }

      // Pairing → si déjà configuré, aller au dashboard
      if (loc == AppRoutes.pair && setupDone == true) {
        return AppRoutes.home;
      }

      // Home → si déconnecté, retour au pairing
      if (loc == AppRoutes.home && setupDone != true) {
        return AppRoutes.pair;
      }

      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash,     builder: (_, __) => const SplashScreen()),
      GoRoute(path: AppRoutes.onboarding, builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: AppRoutes.pair,       builder: (_, __) => const PairingScreen()),
      GoRoute(path: AppRoutes.home,       builder: (_, __) => const WabotShell()),
    ],
  );
});

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref, AuthNotifier authNotifier) {
    ref.listen(authProvider, (_, __) => notifyListeners());
    authNotifier.loadedNotifier.addListener(notifyListeners);
  }
}
