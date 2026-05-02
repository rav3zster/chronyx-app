import 'dart:ui';
import 'package:chronyx/core/routing/app_routes.dart';
import 'package:chronyx/features/auth/presentation/pages/dashboard_page.dart';
import 'package:chronyx/features/goals/presentation/pages/goals_page.dart';
import 'package:chronyx/features/goals/presentation/pages/goal_detail_page.dart';
import 'package:chronyx/features/goals/presentation/pages/create_goal_page.dart';
import 'package:chronyx/features/auth/presentation/pages/login_page.dart';
import 'package:chronyx/features/auth/presentation/providers/auth_provider.dart';
import 'package:chronyx/features/time_tracking/presentation/pages/time_tracking_page.dart';
import 'package:chronyx/features/analytics/presentation/pages/analytics_page.dart';
import 'package:chronyx/features/analytics/presentation/pages/wrapped_page.dart';
import 'package:chronyx/features/ai_coach/presentation/pages/ai_coach_page.dart';
import 'package:chronyx/features/settings/presentation/pages/settings_page.dart';
import 'package:flutter/material.dart';
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
        path: AppRoutes.settings,
        name: AppRoutes.settingsName,
        builder: (context, state) => const SettingsPage(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          final location = state.matchedLocation;
          return _AppShell(location: location, child: child);
        },
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.dashboard,
            name: AppRoutes.dashboardName,
            builder: (context, state) => const DashboardPage(),
          ),
          GoRoute(
            path: AppRoutes.goals,
            name: 'goals',
            builder: (context, state) => const GoalsPage(),
          ),
          GoRoute(
            path: AppRoutes.analytics,
            name: 'analytics',
            builder: (context, state) => const AnalyticsPage(),
          ),
          GoRoute(
            path: AppRoutes.aiCoach,
            name: 'aiCoach',
            builder: (context, state) => const AICoachPage(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.timeTracking,
        name: AppRoutes.timeTrackingName,
        builder: (context, state) => const TimeTrackingPage(),
      ),
      GoRoute(
        path: AppRoutes.goalsCreate,
        name: 'goalsCreate',
        builder: (context, state) => const CreateGoalPage(),
      ),
      GoRoute(
        path: AppRoutes.goalDetail,
        name: 'goalDetail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return GoalDetailPage(goalId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.wrapped,
        name: 'wrapped',
        builder: (context, state) => const WrappedPage(),
      ),
    ],
  );
});

int _navIndexFromLocation(String location) {
  if (location.startsWith(AppRoutes.goals)) return 1;
  if (location.startsWith(AppRoutes.analytics)) return 2;
  if (location.startsWith(AppRoutes.aiCoach)) return 3;
  return 0;
}

/// Shell that overlays the NavigationBar on top of each child page.
/// Each child page keeps its own Scaffold + AppBar; we just add the nav bar
/// as an overlay so there is no double-Scaffold issue.
class _AppShell extends StatelessWidget {
  const _AppShell({required this.location, required this.child});

  final String location;
  final Widget child;

  void _navigate(BuildContext context, int index) {
    switch (index) {
      case 0:
        GoRouter.of(context).go(AppRoutes.dashboard);
      case 1:
        GoRouter.of(context).go(AppRoutes.goals);
      case 2:
        GoRouter.of(context).go(AppRoutes.analytics);
      case 3:
        GoRouter.of(context).go(AppRoutes.aiCoach);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _navIndexFromLocation(location);
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    return Stack(
      children: [
        // The child page fills the entire space (incl. behind nav bar)
        child,
        // Nav bar pinned at the bottom as a translucent overlay
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? scheme.surface.withValues(alpha: 0.82)
                      : scheme.surface.withValues(alpha: 0.90),
                  border: Border(
                    top: BorderSide(
                      color: scheme.outlineVariant,
                      width: 0.5,
                    ),
                  ),
                ),
                child: NavigationBar(
                  selectedIndex: currentIndex,
                  onDestinationSelected: (i) => _navigate(context, i),
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home_rounded),
                      label: 'Dashboard',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.flag_outlined),
                      selectedIcon: Icon(Icons.flag_rounded),
                      label: 'Goals',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.insights_outlined),
                      selectedIcon: Icon(Icons.insights_rounded),
                      label: 'Analytics',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.smart_toy_outlined),
                      selectedIcon: Icon(Icons.smart_toy_rounded),
                      label: 'AI Coach',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
