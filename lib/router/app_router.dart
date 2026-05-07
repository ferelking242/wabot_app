import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_constants.dart';
import '../services/storage_service.dart';
import '../shared/widgets/app_shell.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/chats/presentation/chats_screen.dart';
import '../features/devices/presentation/devices_screen.dart';
import '../features/devices/presentation/pairing_screen.dart';
import '../features/analytics/presentation/analytics_screen.dart';
import '../features/logs/presentation/logs_screen.dart';
import '../features/automation/presentation/automation_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppConstants.routeDashboard,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final onboardingDone = StorageService.getBool(AppConstants.keyOnboardingDone) ?? false;
      if (!onboardingDone && state.uri.path != AppConstants.routeOnboarding) {
        return AppConstants.routeOnboarding;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppConstants.routeOnboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppConstants.routeAuth,
        builder: (_, __) => const AuthScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppConstants.routeDashboard,
            pageBuilder: (_, state) => _fadeTransition(state, const DashboardScreen()),
          ),
          GoRoute(
            path: AppConstants.routeChats,
            pageBuilder: (_, state) => _fadeTransition(state, const ChatsScreen()),
          ),
          GoRoute(
            path: AppConstants.routeDevices,
            pageBuilder: (_, state) => _fadeTransition(state, const DevicesScreen()),
            routes: [
              GoRoute(
                path: 'pairing',
                pageBuilder: (_, state) => _fadeTransition(state, const PairingScreen()),
              ),
            ],
          ),
          GoRoute(
            path: AppConstants.routeAnalytics,
            pageBuilder: (_, state) => _fadeTransition(state, const AnalyticsScreen()),
          ),
          GoRoute(
            path: AppConstants.routeLogs,
            pageBuilder: (_, state) => _fadeTransition(state, const LogsScreen()),
          ),
          GoRoute(
            path: AppConstants.routeAutomation,
            pageBuilder: (_, state) => _fadeTransition(state, const AutomationScreen()),
          ),
          GoRoute(
            path: AppConstants.routeSettings,
            pageBuilder: (_, state) => _fadeTransition(state, const SettingsScreen()),
          ),
        ],
      ),
    ],
  );
});

CustomTransitionPage<void> _fadeTransition(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (_, animation, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
  );
}
