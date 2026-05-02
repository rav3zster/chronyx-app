import 'package:chronyx/core/routing/app_routes.dart';
import 'package:chronyx/features/auth/presentation/pages/dashboard_page.dart';
import 'package:chronyx/features/auth/presentation/pages/login_page.dart';
import 'package:chronyx/features/auth/presentation/providers/auth_provider.dart';
import 'package:chronyx/features/time_tracking/presentation/pages/time_tracking_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshListenable = ref.watch(authRouterRefreshListenableProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final authState = ref.read(authProvider);

      if (authState.isLoading) {
        debugPrint('[Router] redirect skipped — auth still loading');
        return null;
      }

      final user = authState.valueOrNull;
      final isLoggedIn = user != null;
      final isLoginRoute = state.matchedLocation == AppRoutes.login;

      debugPrint(
        '[Router] redirect check: matched=${state.matchedLocation} '
        'uri=${state.uri} isLoggedIn=$isLoggedIn',
      );

      if (!isLoggedIn && !isLoginRoute) {
        return AppRoutes.login;
      }

      if (isLoggedIn && isLoginRoute) {
        return AppRoutes.dashboard;
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.login,
        name: AppRoutes.loginName,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        name: AppRoutes.dashboardName,
        builder: (context, state) => const DashboardPage(),
      ),
      GoRoute(
        path: AppRoutes.timeTracking,
        name: AppRoutes.timeTrackingName,
        builder: (context, state) => const TimeTrackingPage(),
      ),
    ],
  );
});
